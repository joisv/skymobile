import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/payment_model.dart';
import 'package:skyrental_admin/screens/dashboard/sales_report_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/widgets/shift_warning_dialog.dart';

class MockSalesReportRepository extends BookingRepository {
  final List<PaymentTransactionModel> customTransactions;

  MockSalesReportRepository({required this.customTransactions});

  @override
  Future<Map<String, dynamic>> getSalesReportData({
    String period = 'Hari Ini',
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int perPage = 20,
    int? affiliateId,
  }) async {
    return {
      'transactions': customTransactions,
      'stats': {
        'totalRevenue': 240000.0,
        'transactionCount': customTransactions.length,
        'averagePerRental': 120000.0,
      },
      'todayCashSummary': {
        'cash_opening': 200000.0,
        'cash_inflow': 90000.0,
        'cash_outflow': 0.0,
        'cash_expected': 290000.0,
        'cash_difference': 0.0,
      },
      'paymentMethodBreakdown': {
        'QRIS': 90000.0,
        'Tunai': 150000.0,
      },
      'typeBreakdown': {
        'Pelunasan': 90000.0,
        'Sewa Baru': 150000.0,
      },
      'modelRevenue': {
        'iPhone 11': 90000.0,
        'iPhone 14 Pro': 150000.0,
      },
      'modelRentalCount': {
        'iPhone 11': 1,
        'iPhone 14 Pro': 1,
      },
      'affiliateBreakdown': <Map<String, dynamic>>[],
      'pagination': {
        'current_page': 1,
        'per_page': 20,
        'total': customTransactions.length,
        'last_page': 1,
      },
    };
  }
}

void main() {
  setUp(() {
    AuthService().setCurrentUserForTest(
      const AdminUserModel(
        id: 1,
        name: 'Super Admin SKYRental',
        email: 'admin@skyrental.id',
        phone: '+62 812-3456-7890',
        role: 'super-admin',
        roles: ['super-admin'],
        outletName: 'Pusat',
        shiftName: 'All Shift',
        affiliateId: 4,
      ),
    );
  });

  group('1. Shift Kasir Belum Dibuka Dialog Fix', () {
    testWidgets('Renders properly without clipping on narrow mobile screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool openShiftCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showShiftWarningDialog(
                      context,
                      onOpenShift: () {
                        openShiftCalled = true;
                      },
                    );
                  },
                  child: const Text('Trigger Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Trigger the dialog
      await tester.tap(find.text('Trigger Dialog'));
      await tester.pumpAndSettle();

      // Verify Title and Subtitle are visible
      expect(find.text('Shift Kasir Belum Dibuka'), findsOneWidget);
      expect(find.byIcon(Icons.point_of_sale_rounded), findsOneWidget);

      // Verify Batal button
      final batalFinder = find.byKey(const Key('btn_batal_shift_dialog'));
      expect(batalFinder, findsOneWidget);

      // Verify Buka Shift button
      final bukaShiftFinder = find.byKey(const Key('btn_buka_shift_kasir'));
      expect(bukaShiftFinder, findsOneWidget);
      expect(find.text('Buka Shift'), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_rounded), findsOneWidget);

      // Verify equal height 48px
      final batalSize = tester.getSize(batalFinder);
      final bukaShiftSize = tester.getSize(bukaShiftFinder);
      expect(batalSize.height, equals(48.0));
      expect(bukaShiftSize.height, equals(48.0));

      // Tap Buka Shift triggers onOpenShift
      await tester.tap(bukaShiftFinder);
      await tester.pumpAndSettle();
      expect(openShiftCalled, isTrue);
    });

    testWidgets('Tapping Batal closes the dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showShiftWarningDialog(context),
                  child: const Text('Trigger Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Shift Kasir Belum Dibuka'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_batal_shift_dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Shift Kasir Belum Dibuka'), findsNothing);
    });
  });

  group('2. Riwayat Transaksi Penjualan Mobile Card List Refactor', () {
    final now = DateTime.now();
    final sampleTransactions = [
      PaymentTransactionModel(
        id: 101,
        bookingId: 55,
        bookingCode: 'SKY261105ZZKS',
        customerName: 'Budi Santoso',
        customerPhone: '+62-8314-5555',
        iphoneName: 'iPhone 11',
        rentTotal: 90000,
        paidAmount: 90000,
        remainingAmount: 0,
        depositAmount: 0,
        depositStatus: DepositStatus.held,
        paymentStatus: 'paid',
        paymentMethod: 'QRIS',
        transactionDate: now,
        notes: 'Pelunasan|KTP Terverifikasi',
        primaryRentFee: 70000,
        addonFee: 20000,
        addonName: 'tripod',
      ),
      PaymentTransactionModel(
        id: 102,
        bookingId: 56,
        bookingCode: 'SKY261105ZZKT',
        customerName: 'Siti Aminah',
        customerPhone: '+62-8123-9999',
        iphoneName: 'iPhone 14 Pro',
        rentTotal: 150000,
        paidAmount: 150000,
        remainingAmount: 0,
        depositAmount: 0,
        depositStatus: DepositStatus.held,
        paymentStatus: 'paid',
        paymentMethod: 'Tunai',
        transactionDate: now,
        notes: 'Sewa Baru|SIM A',
      ),
    ];

    testWidgets('On mobile viewport (< 600px), renders Transaction Card List with full details and print button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(380, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockSalesReportRepository(customTransactions: sampleTransactions);

      await tester.pumpWidget(
        MaterialApp(
          home: SalesReportScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Card Header: Invoice ID and time
      expect(find.textContaining('SKY261105ZZKS'), findsOneWidget);
      expect(find.text('QRIS'), findsWidgets);

      // Verify Card Body: Customer name & phone
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.textContaining('+62-8314-5555'), findsOneWidget);

      // Verify Unit & Add-on tag
      expect(find.textContaining('iPhone 11'), findsWidgets);
      expect(find.textContaining('+ Add-on (tripod)'), findsOneWidget);

      // Verify Payment Type tag
      expect(find.text('Pelunasan'), findsWidgets);

      // Verify Card Footer: Itemized breakdown (iPhone & Add-on) and Total
      expect(find.textContaining('iPhone: Rp 70.000'), findsOneWidget);
      expect(find.textContaining('Add-on: Rp 20.000'), findsOneWidget);
      expect(find.text('Rp 90.000'), findsWidgets);

      // Verify Print receipt button is present
      final printBtn = find.byKey(const Key('btn_print_tx_101'));
      expect(printBtn, findsOneWidget);

      // Scroll until print button is visible before tapping
      await tester.dragUntilVisible(
        printBtn,
        find.byType(SingleChildScrollView).first,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();

      // Tapping print receipt button opens Struk dialog
      await tester.tap(printBtn);
      await tester.pumpAndSettle();

      expect(find.text('Struk #SKY261105ZZKS'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsWidgets);
    });

    testWidgets('On tablet viewport (>= 600px), retains horizontally scrollable table view', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockSalesReportRepository(customTransactions: sampleTransactions);

      await tester.pumpWidget(
        MaterialApp(
          home: SalesReportScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // On tablet, the table header columns must exist
      expect(find.text('NO. RESI / JAM'), findsOneWidget);
      expect(find.text('CUSTOMER'), findsOneWidget);
      expect(find.text('UNIT & TIPE'), findsOneWidget);
      expect(find.text('METODE'), findsOneWidget);
      expect(find.text('NOMINAL'), findsOneWidget);
      expect(find.text('STRUK'), findsOneWidget);
    });
  });
}
