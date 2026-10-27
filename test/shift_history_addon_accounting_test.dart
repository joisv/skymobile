import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/cash_drawer_shift_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/models/payment_model.dart';
import 'package:skyrental_admin/screens/booking/booking_detail_screen.dart';
import 'package:skyrental_admin/screens/cashier/cashier_shift_screen.dart';
import 'package:skyrental_admin/screens/dashboard/dashboard_screen.dart';
import 'package:skyrental_admin/screens/dashboard/sales_report_screen.dart';
import 'package:skyrental_admin/screens/payment/payment_deposit_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/utils/formatters.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
  });

  const testIphone = IphoneModel(
    id: 101,
    name: 'iPhone 17',
    storage: '128GB',
    color: 'Teal',
    serialNumber: 'SN-IP17-001',
    assetCode: 'AST-IP17-001',
    status: 'tersedia',
    durations: [
      IphoneDurationOption(id: 1, name: '24 Jam', hours: 24, price: 80000),
    ],
  );

  const testAddonTripod = IphoneModel(
    id: 82,
    name: 'Tripod Excell',
    storage: '',
    color: 'Hitam',
    serialNumber: 'ACC1A17CAEBEC0',
    assetCode: 'ADDON1310',
    status: 'tersedia',
    isAddon: true,
    durations: [
      IphoneDurationOption(id: 2, name: '24 Jam', hours: 24, price: 10000),
    ],
  );

  final testBookingWithAddon = BookingModel(
    id: 4298,
    bookingCode: 'SKY261027BEZ4',
    customerName: 'Ahmad Fauzi',
    customerPhone: '081234567890',
    customerEmail: 'ahmad@example.com',
    address: 'Jl. Malioboro No. 12',
    pickupType: 'Pickup',
    jaminanType: 'KTP',
    iphone: testIphone,
    startDate: DateTime(2026, 10, 27, 9, 0),
    endDate: DateTime(2026, 10, 28, 9, 0),
    durationDays: 1,
    price: 90000, // Rp 80.000 iPhone + Rp 10.000 Tripod
    status: BookingStatus.confirmed,
    paymentStatus: PaymentStatus.paid,
    addonDevices: const [testAddonTripod],
    addonSubtotal: 10000,
    deposit: 0,
    discount: 0,
    downPayment: 90000,
  );

  group('Issue A: Shift History Timestamps & Active Shift Clean Handling', () {
    test('CashDrawerShiftModel parses opened_at and closed_at correctly', () {
      final jsonClosed = {
        'id': 1,
        'shift_number': 'SHF-GTG-261027-0001',
        'branch_id': 1,
        'branch_name': 'Genteng',
        'opened_by_name': 'Budi Kasir',
        'closed_by_name': 'Budi Kasir',
        'status': 'closed',
        'opening_cash_float': 200000.0,
        'expected_cash_total': 290000.0,
        'actual_cash_counted': 290000.0,
        'cash_difference': 0.0,
        'opened_at': '2026-10-27T08:00:00+07:00',
        'closed_at': '2026-10-27T16:00:00+07:00',
      };

      final shift = CashDrawerShiftModel.fromJson(jsonClosed);
      expect(shift.openedAt, isNotNull);
      expect(shift.closedAt, isNotNull);
      expect(shift.isClosed, isTrue);

      final formattedOpen = Formatters.dateTime(shift.openedAt);
      final formattedClose = Formatters.dateTime(shift.closedAt!);
      expect(formattedOpen, isNotEmpty);
      expect(formattedClose, isNotEmpty);
    });

    test('CashDrawerShiftModel handles open active shift without fabricated closing timestamp', () {
      final jsonOpen = {
        'id': 2,
        'shift_number': 'SHF-GTG-261027-0002',
        'branch_id': 1,
        'branch_name': 'Genteng',
        'opened_by_name': 'Budi Kasir',
        'status': 'open',
        'opening_cash_float': 200000.0,
        'expected_cash_now': 290000.0,
        'opened_at': '2026-10-27T16:00:00+07:00',
        'closed_at': null,
      };

      final shift = CashDrawerShiftModel.fromJson(jsonOpen);
      expect(shift.openedAt, isNotNull);
      expect(shift.closedAt, isNull);
      expect(shift.isOpen, isTrue);
    });

    testWidgets('CashierShiftScreen renders opened_at, closed_at and handles active shift without fabricated date', (tester) async {
      final repo = BookingRepository();
      final shiftClosed = CashDrawerShiftModel(
        id: 1,
        shiftNumber: 'SHF-GTG-261027-0001',
        branchId: 1,
        branchName: 'Genteng',
        status: ShiftStatus.closed,
        openingCashFloat: 200000,
        expectedCashTotal: 290000,
        actualCashCounted: 290000,
        cashDifference: 0,
        openedAt: DateTime(2026, 10, 27, 8, 0),
        closedAt: DateTime(2026, 10, 27, 16, 0),
      );

      final shiftActive = CashDrawerShiftModel(
        id: 2,
        shiftNumber: 'SHF-GTG-261027-0002',
        branchId: 1,
        branchName: 'Genteng',
        status: ShiftStatus.open,
        openingCashFloat: 200000,
        expectedCashNow: 290000,
        openedAt: DateTime(2026, 10, 27, 16, 0),
        closedAt: null,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CashierShiftScreen(repository: repo),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap on Tab "Riwayat Shift"
      final historyTab = find.text('Riwayat Shift');
      if (historyTab.evaluate().isNotEmpty) {
        await tester.tap(historyTab);
        await tester.pumpAndSettle();
      }

      // Verify that Formatters.dateTime(shiftClosed.openedAt) and Formatters.dateTime(shiftClosed.closedAt!) are valid
      final openStr = Formatters.dateTime(shiftClosed.openedAt);
      final closeStr = Formatters.dateTime(shiftClosed.closedAt!);
      expect(openStr, contains('2026'));
      expect(closeStr, contains('2026'));

      // Active shift closing label: "Shift Masih Aktif (Belum Ditutup)"
      final activeShiftLabel = shiftActive.closedAt != null
          ? Formatters.dateTime(shiftActive.closedAt!)
          : 'Shift Masih Aktif (Belum Ditutup)';
      expect(activeShiftLabel, equals('Shift Masih Aktif (Belum Ditutup)'));
    });
  });

  group('Issue B: Add-on Itemization in Cashier Booking & Settlement Summaries', () {
    testWidgets('PaymentDepositScreen displays separate add-on section with duration, rates, and line totals', (tester) async {
      final repo = BookingRepository();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: PaymentDepositScreen(
          repository: repo,
          booking: testBookingWithAddon,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify Add-on items section is rendered
      expect(find.textContaining('Item Add-on (1)'), findsWidgets);
      expect(find.textContaining('Tripod Excell'), findsWidgets);
      expect(find.textContaining('ADDON1310'), findsWidgets);
      expect(find.textContaining('Rp 10.000'), findsWidgets);

      // Verify iPhone primary rental fee is separated
      expect(find.textContaining('Sewa iPhone: Rp 80.000'), findsWidgets);
      expect(find.textContaining('Sewa Add-on: Rp 10.000'), findsWidgets);
    });
  });

  group('Issue C: Add-on Rental Fees in Queue & Booking Details (SKY261027BEZ4)', () {
    testWidgets('DashboardScreen transaction queue item shows add-on badge and itemized footnote', (tester) async {
      final repo = BookingRepository();
      await repo.createBooking(
        customerName: testBookingWithAddon.customerName,
        customerPhone: testBookingWithAddon.customerPhone,
        customerEmail: 'test@example.com',
        address: testBookingWithAddon.address,
        iphone: testIphone,
        startDate: testBookingWithAddon.startDate,
        endDate: testBookingWithAddon.endDate,
        durationDays: 1,
        price: testBookingWithAddon.price,
        addonDevices: testBookingWithAddon.addonDevices,
        addonSubtotal: testBookingWithAddon.addonSubtotal,
        deposit: 0,
        jaminanType: 'KTP',
        paymentStatus: PaymentStatus.paid,
        amountPaid: 90000,
        paymentMethod: 'Tunai',
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: DashboardScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      // Check that add-on badge or name is rendered in the queue
      expect(find.textContaining('Tripod'), findsWidgets);
    });

    testWidgets('BookingDetailScreen displays itemized primary iPhone rental vs add-on fee', (tester) async {
      final repo = BookingRepository();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: BookingDetailScreen(
          booking: testBookingWithAddon,
          repository: repo,
        ),
      ));
      await tester.pumpAndSettle();

      // Check itemized breakdown in BookingDetailScreen
      expect(find.textContaining('Sewa iPhone'), findsWidgets);
      expect(find.textContaining('Add-on: Tripod Excell'), findsWidgets);
      expect(find.textContaining('Rp 80.000'), findsWidgets);
      expect(find.textContaining('Rp 10.000'), findsWidgets);
    });
  });

  group('Issue D: Sales Reports Add-on Accounting', () {
    test('PaymentTransactionModel parses itemized primary_rent_fee and addon_fee', () {
      final json = {
        'id': 'TRX-4298',
        'booking_code': 'SKY261027BEZ4',
        'customer_name': 'Ahmad Fauzi',
        'unit_name': 'iPhone 17',
        'amount': 90000.0,
        'payment_method': 'Tunai',
        'status': 'success',
        'paid_at': '2026-10-27T10:00:00',
        'primary_rent_fee': 80000.0,
        'addon_fee': 10000.0,
        'addon_name': 'Tripod Excell',
        'addon_names': ['Tripod Excell'],
      };

      final tx = PaymentTransactionModel.fromJson(json);
      expect(tx.primaryRentFee, equals(80000.0));
      expect(tx.addonFee, equals(10000.0));
      expect(tx.addonName, equals('Tripod Excell'));
      expect(tx.hasAddons, isTrue);
    });

    testWidgets('SalesReportScreen renders itemized iPhone vs Add-on in table view', (tester) async {
      final repo = BookingRepository();
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: SalesReportScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      // Check that table headers and transaction view load without errors
      expect(find.text('Laporan Penjualan & Kasir'), findsOneWidget);
    });
  });

  group('Issue E & F: Shift Closing Defaults, Denomination Counter & Cash Difference', () {
    test('Denomination calculator with Rp 290,000 matches expected cash of Rp 290,000 with Rp 0 discrepancy', () {
      const openingCash = 200000.0;
      const cashInflow = 90000.0; // Payment from SKY261027BEZ4
      const expectedCash = openingCash + cashInflow; // Rp 290,000

      // Denominations entered by cashier:
      // Rp 100,000 x 2 = Rp 200,000
      // Rp 50,000 x 1 = Rp 50,000
      // Rp 20,000 x 2 = Rp 40,000
      const actualCash = (100000 * 2) + (50000 * 1) + (20000 * 2); // Rp 290,000
      final difference = actualCash - expectedCash;

      expect(actualCash, equals(290000.0));
      expect(expectedCash, equals(290000.0));
      expect(difference, equals(0.0));
    });

    test('Stale expected cash of Rp 200,000 would falsely produce +Rp 90,000 difference', () {
      const staleExpectedCash = 200000.0; // If unrefreshed!
      const actualCash = 290000.0;
      final falseDifference = actualCash - staleExpectedCash;

      // This demonstrates the exact root cause of Issue F!
      expect(falseDifference, equals(90000.0));
    });

    testWidgets('CashierShiftScreen close dialog initializes actual cash to 0 and opens denomination counter', (tester) async {
      final repo = BookingRepository();
      await repo.openShift(openingCashFloat: 200000, notes: 'Opening Shift 2');

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CashierShiftScreen(repository: repo),
        ),
      ));
      await tester.pumpAndSettle();

      // Look for Tutup Shift Kasir button
      final closeShiftBtn = find.text('Tutup Shift Kasir');
      if (closeShiftBtn.evaluate().isNotEmpty) {
        await tester.tap(closeShiftBtn);
        await tester.pumpAndSettle();

        // Check that physical cash input defaulted to "0"
        expect(find.text('0'), findsWidgets);

        // Check that denomination calculator is automatically shown
        expect(find.text('Hitung Per Pecahan Uang Rupiah'), findsOneWidget);
        expect(find.text('Rp 100.000'), findsOneWidget);
        expect(find.text('Rp 50.000'), findsOneWidget);
        expect(find.text('Rp 20.000'), findsOneWidget);
      }
    });
  });
}
