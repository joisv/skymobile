import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/models/print_result_model.dart';
import 'package:skyrental_admin/models/printer_device_model.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/screens/payment/payment_deposit_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/services/printer_storage_service.dart';
import 'package:skyrental_admin/services/thermal_print_service.dart';

void main() {
  const testUnit = IphoneModel(
    id: 991,
    name: 'iPhone 15 Pro',
    storage: '128GB',
    color: 'Black Titanium',
    serialNumber: 'SN-PRINT-TEST-991',
    assetCode: 'AST-PRINT-991',
    status: 'tersedia',
    batteryHealth: 100,
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    await PrinterStorageService().init();
    ThermalPrintService().resetSimulation();
  });

  tearDown(() {
    ThermalPrintService().resetSimulation();
  });

  Future<BookingModel> createTestBooking(BookingRepository repo, {double price = 250000}) async {
    return repo.createBooking(
      customerName: 'Budi Santoso',
      customerPhone: '081234567890',
      customerEmail: 'budi@example.com',
      address: 'Jl. Sudirman No 45, Jakarta',
      iphone: testUnit,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 1)),
      durationDays: 1,
      price: price,
      deposit: 0,
      jaminanType: 'KTP',
      paymentStatus: PaymentStatus.unpaid,
      amountPaid: 0,
      paymentMethod: 'Tunai',
    );
  }

  Widget createTestWidget(BookingRepository repo, BookingModel booking) {
    return MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.printerSettings) {
          return MaterialPageRoute(
            builder: (ctx) => Scaffold(
              appBar: AppBar(title: const Text('Printer Settings Screen')),
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    // Simulate selecting and connecting a printer
                    await PrinterStorageService().savePrimaryPrinter(
                      const PrinterDeviceModel(
                        name: 'Connected VSC MP-58C',
                        address: '66:55:44:33:22:11',
                        isConnected: true,
                      ),
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Simulate Connect Printer'),
                ),
              ),
            ),
          );
        }
        return null;
      },
      home: PaymentDepositScreen(
        repository: repo,
        booking: booking,
      ),
    );
  }

  group('Printer Connection Warning and Workflow Tests', () {
    // 1. Booking payment succeeds and the printer is connected.
    testWidgets('1. Booking payment succeeds and the printer is connected', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo);
      await PrinterStorageService().savePrimaryPrinter(PrinterDeviceModel.defaultVsc());

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan');
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Expect success dialog
      expect(find.text('Pembayaran Berhasil'), findsOneWidget);
      expect(find.textContaining('Struk resi berhasil dicetak'), findsOneWidget);

      final updatedBooking = await repo.getBookingByCode(booking.bookingCode);
      expect(updatedBooking?.paymentStatus, equals(PaymentStatus.paid));
    });

    // 2. Booking payment succeeds but no printer is configured.
    testWidgets('2. Booking payment succeeds but no printer is configured', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo);
      await PrinterStorageService().clearPrimaryPrinter();

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Expect Scenario A dialog: "Printer Not Connected"
      expect(find.text('Printer Not Connected'), findsOneWidget);
      expect(
        find.text('No receipt printer has been connected. Connect a printer to print the booking receipt.'),
        findsOneWidget,
      );
      expect(find.text('Connect Printer'), findsOneWidget);
      expect(find.text('Print Later'), findsOneWidget);

      // Verify booking & payment integrity: already marked as paid in backend!
      final updatedBooking = await repo.getBookingByCode(booking.bookingCode);
      expect(updatedBooking?.paymentStatus, equals(PaymentStatus.paid));
    });

    // 3. A printer is configured but disconnected.
    testWidgets('3. A printer is configured but disconnected', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo);
      await PrinterStorageService().savePrimaryPrinter(
        const PrinterDeviceModel(
          name: 'Disconnected Thermal POS',
          address: 'AA:BB:CC:DD:EE:01',
          isConnected: false,
        ),
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Expect Scenario B dialog: "Unable to Connect to Printer"
      expect(find.text('Unable to Connect to Printer'), findsOneWidget);
      expect(
        find.text('The printer could not be connected. Check that the printer is powered on, nearby, and available, then try again.'),
        findsOneWidget,
      );
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Choose Another Printer'), findsOneWidget);
      expect(find.text('Print Later'), findsOneWidget);

      // Payment remains intact
      final updatedBooking = await repo.getBookingByCode(booking.bookingCode);
      expect(updatedBooking?.paymentStatus, equals(PaymentStatus.paid));
    });

    // 4. The connection attempt fails.
    testWidgets('4. The connection attempt fails', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo);
      await PrinterStorageService().savePrimaryPrinter(PrinterDeviceModel.defaultVsc());
      ThermalPrintService().configureSimulation(
        simulateConnectionFailure: true,
        connectionErrorMessage: 'Printer tidak merespons koneksi Bluetooth.',
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.text('Unable to Connect to Printer'), findsOneWidget);
      expect(find.text('Printer tidak merespons koneksi Bluetooth.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    // 5. The connection attempt times out.
    testWidgets('5. The connection attempt times out', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo);
      await PrinterStorageService().savePrimaryPrinter(PrinterDeviceModel.defaultVsc());
      ThermalPrintService().configureSimulation(simulateConnectionTimeout: true);

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.text('Unable to Connect to Printer'), findsOneWidget);
      expect(find.textContaining('timeout'), findsWidgets);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Choose Another Printer'), findsOneWidget);
      expect(find.text('Print Later'), findsOneWidget);
    });

    // 6. The user successfully connects a printer after the warning appears.
    testWidgets('6. The user successfully connects a printer after the warning appears', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo);
      await PrinterStorageService().clearPrimaryPrinter();

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      // Submit payment
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Warning appears
      expect(find.text('Printer Not Connected'), findsOneWidget);

      // User taps "Connect Printer"
      final connectBtn = find.widgetWithText(ElevatedButton, 'Connect Printer');
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();

      // Navigated to printer settings screen
      expect(find.text('Printer Settings Screen'), findsOneWidget);

      // User connects a printer in settings and returns
      final simConnectBtn = find.text('Simulate Connect Printer');
      await tester.tap(simConnectBtn);
      await tester.pumpAndSettle();

      // Returned to payment workflow, prints receipt, and shows success!
      expect(find.text('Pembayaran Berhasil'), findsOneWidget);
      expect(find.textContaining('Struk resi berhasil dicetak'), findsOneWidget);
    });

    // 7. The user chooses Print Later.
    testWidgets('7. The user chooses Print Later', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo);
      await PrinterStorageService().clearPrimaryPrinter();

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.text('Printer Not Connected'), findsOneWidget);

      // User chooses "Print Later"
      final printLaterBtn = find.widgetWithText(TextButton, 'Print Later');
      await tester.tap(printLaterBtn);
      await tester.pumpAndSettle();

      // Success dialog appears showing completed payment and "Struk belum dicetak"
      expect(find.text('Pembayaran Berhasil'), findsOneWidget);
      expect(find.textContaining('Struk belum dicetak'), findsOneWidget);
      expect(find.text('Lihat Struk Resi'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);

      // Payment remains intact
      final updated = await repo.getBookingByCode(booking.bookingCode);
      expect(updated?.paymentStatus, equals(PaymentStatus.paid));
    });

    // 8. Printing fails despite an established connection.
    testWidgets('8. Printing fails despite an established connection', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo);
      await PrinterStorageService().savePrimaryPrinter(PrinterDeviceModel.defaultVsc());
      ThermalPrintService().configureSimulation(
        simulateFailure: true,
        failureStatus: PrintResultStatus.outOfPaper,
        failureMessage: 'Kertas pada printer VSC MP-58C habis.',
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Expect Scenario D: "Printing Failed"
      expect(find.text('Printing Failed'), findsOneWidget);
      expect(find.text('Kertas pada printer VSC MP-58C habis.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.text('Print Later'), findsOneWidget);
    });

    // 9. The user retries printing multiple times.
    testWidgets('9. The user retries printing multiple times', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo);
      await PrinterStorageService().savePrimaryPrinter(PrinterDeviceModel.defaultVsc());
      ThermalPrintService().configureSimulation(
        simulateFailure: true,
        failureStatus: PrintResultStatus.transmissionError,
        failureMessage: 'Gagal transmisi data ke printer.',
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      // First submit
      await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Printing Failed'), findsOneWidget);

      // Retry 1
      await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Printing Failed'), findsOneWidget);

      // Retry 2
      await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Printing Failed'), findsOneWidget);

      // Now resolve the issue
      ThermalPrintService().resetSimulation();

      // Retry 3 (successful)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Pembayaran Berhasil'), findsOneWidget);
      expect(find.textContaining('Struk resi berhasil dicetak'), findsOneWidget);

      // Verify exactly ONE payment transaction was recorded!
      final allTxs = await repo.getPaymentTransactions();
      final txs = allTxs.where((t) => t.bookingCode == booking.bookingCode).toList();
      expect(txs.length, equals(1));
    });

    // 10. Reopening or navigating back to the booking does not create duplicate bookings or payments.
    testWidgets('10. Reopening or navigating back to the booking does not create duplicate bookings or payments', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo);
      await PrinterStorageService().savePrimaryPrinter(PrinterDeviceModel.defaultVsc());

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan'));
      await tester.pumpAndSettle();

      // Dismiss dialog
      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();

      // Verify bookings count & payments count in repository
      final allBookings = await repo.getBookings();
      final matchingBookings = allBookings.where((b) => b.bookingCode == booking.bookingCode).toList();
      expect(matchingBookings.length, equals(1));

      final allTxs = await repo.getPaymentTransactions();
      final txs = allTxs.where((t) => t.bookingCode == booking.bookingCode).toList();
      expect(txs.length, equals(1));
    });

    // 11. The receipt is printed for the correct booking and contains the correct payment details.
    testWidgets('11. The receipt is printed for the correct booking and contains the correct payment details', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo, price: 350000);
      await PrinterStorageService().savePrimaryPrinter(PrinterDeviceModel.defaultVsc());

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan'));
      await tester.pumpAndSettle();

      // Check last printed result in service
      final lastResult = ThermalPrintService().lastResult;
      expect(lastResult, isNotNull);
      expect(lastResult!.isSuccess, isTrue);
      expect(lastResult.metadata['bookingCode'], equals(booking.bookingCode));
      expect(lastResult.metadata['customerName'], equals('Budi Santoso'));
      expect(lastResult.metadata['totalAmount'], equals(350000.0));

      // Also check saved receipts history
      final receipts = await repo.getReceiptHistory();
      final savedReceipt = receipts.firstWhere((r) => r.bookingCode == booking.bookingCode);
      expect(savedReceipt.customerName, equals('Budi Santoso'));
      expect(savedReceipt.totalAmount, equals(350000.0));
      expect(savedReceipt.paidAmount, equals(350000.0));
    });

    // 12. The booking and payment remain intact after any printer-related failure.
    testWidgets('12. The booking and payment remain intact after any printer-related failure', (tester) async {
      final repo = BookingRepository();
      final booking = await createTestBooking(repo, price: 500000);
      await PrinterStorageService().savePrimaryPrinter(
        const PrinterDeviceModel(
          name: 'Offline POS',
          address: 'FF:EE:DD:CC:BB:AA',
          isConnected: false,
        ),
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(repo, booking));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi Pelunasan & Simpan'));
      await tester.pumpAndSettle();

      // Warning appears
      expect(find.text('Unable to Connect to Printer'), findsOneWidget);

      // Verify that booking and payment are preserved and intact in repository!
      final b = await repo.getBookingByCode(booking.bookingCode);
      expect(b?.paymentStatus, equals(PaymentStatus.paid));
      expect(b?.price, equals(500000.0));
      expect(b?.downPayment, equals(500000.0));

      final allTxs = await repo.getPaymentTransactions();
      final txs = allTxs.where((t) => t.bookingCode == booking.bookingCode).toList();
      expect(txs.length, equals(1));
      expect(txs.first.paidAmount, equals(500000.0));
      expect(txs.first.paymentStatus, equals('paid'));
    });
  });
}
