import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/screens/dashboard/dashboard_screen.dart';
import 'package:skyrental_admin/screens/dashboard/widgets/operational_metric_detail_sheet.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
  });

  BookingModel createBooking({
    required int id,
    required String code,
    required String customerName,
    required String customerPhone,
    required String jaminanType,
    required PaymentStatus paymentStatus,
    required BookingStatus bookingStatus,
    required DateTime startDate,
    required DateTime endDate,
    required String serialNumber,
    required String iphoneName,
    double price = 150000,
    double deposit = 50000,
    String? startTime = '10:00',
    String? endTime = '18:00',
    bool isLate = false,
    double diffHours = 0,
    int hoursLate = 0,
    int lateMinutes = 0,
    double? estimatedLateFee,
  }) {
    return BookingModel(
      id: id,
      bookingCode: code,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: '$customerName@example.com'.toLowerCase().replaceAll(' ', ''),
      address: 'Jl. Merdeka No. 10',
      pickupType: 'Outlet',
      jaminanType: jaminanType,
      startDate: startDate,
      endDate: endDate,
      durationDays: 1,
      startTime: startTime,
      endTime: endTime,
      price: price,
      deposit: deposit,
      status: bookingStatus,
      paymentStatus: paymentStatus,
      isLate: isLate,
      diffHours: diffHours,
      hoursLate: hoursLate,
      lateMinutes: lateMinutes,
      estimatedLateFee: estimatedLateFee,
      iphone: IphoneModel(
        id: id,
        name: iphoneName,
        storage: '128GB',
        color: 'Graphite',
        serialNumber: serialNumber,
        assetCode: 'AST-$serialNumber',
        status: bookingStatus == BookingStatus.rented ? 'disewa' : 'ready',
        batteryHealth: 95,
        branchName: 'Outlet Dipatiukur',
      ),
    );
  }

  testWidgets('Operational Metrics cards render on mobile (390 x 844) and open interactive modal sheets', (WidgetTester tester) async {
    final now = DateTime.now();

    final pickupBooking = createBooking(
      id: 101,
      code: 'SKY-PICKUP-01',
      customerName: 'Budi Santoso',
      customerPhone: '081298765432',
      jaminanType: 'KTP Fisik',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.confirmed,
      startDate: now,
      endDate: now.add(const Duration(days: 1)),
      serialNumber: 'SN-IP13P-001',
      iphoneName: 'iPhone 13 Pro',
      startTime: '13:00',
    );

    final overdueReturnBooking = createBooking(
      id: 102,
      code: 'SKY-RETURN-LATE',
      customerName: 'Siti Rahma',
      customerPhone: '085712345678',
      jaminanType: 'SIM A',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.rented,
      startDate: now.subtract(const Duration(days: 1, hours: 2, minutes: 15)),
      endDate: now.subtract(const Duration(hours: 2, minutes: 15)),
      serialNumber: 'SN-IP14P-999',
      iphoneName: 'iPhone 14 Pro',
      isLate: true,
      diffHours: 2.25,
      hoursLate: 2,
      lateMinutes: 15,
      estimatedLateFee: 50000,
    );

    final onTimeReturnBooking = createBooking(
      id: 103,
      code: 'SKY-RETURN-ONTIME',
      customerName: 'Dewi Lestari',
      customerPhone: '081345678901',
      jaminanType: 'KTP Fisik',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.rented,
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(hours: 4)),
      serialNumber: 'SN-IP15PM-777',
      iphoneName: 'iPhone 15 Pro Max',
    );

    final repo = BookingRepository();
    repo.setTestBookings([pickupBooking, overdueReturnBooking, onTimeReturnBooking]);
    repo.setDashboardCache(
      data: {
        'isOnline': true,
        'metrics': {
          'availableUnits': 12,
          'unreturnedUnits': 2,
          'bookingToday': 1,
          'revenueToday': 450000.0,
          'activeRentals': 2,
          'todayPickups': 1,
          'todayReturns': 2,
          'overdueReturns': 1,
          'rentedUnits': 2,
          'totalUnits': 15,
          'utilizationRate': 13,
        },
        'financials': {
          'totalRevenue': 450000.0,
          'totalHeldDeposit': 150000.0,
          'totalRefundedDeposit': 0.0,
        },
        'actionItems': [pickupBooking, overdueReturnBooking],
        'recentBookings': [pickupBooking, overdueReturnBooking, onTimeReturnBooking],
        'allQueue': [pickupBooking, overdueReturnBooking, onTimeReturnBooking],
      },
      readyUnits: [],
      pendingTransferCount: 0,
    );

    // Mobile viewport (iPhone 14 / modern phone resolution)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(repository: repo),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify original visual design & typography is preserved
    expect(find.text('iPhone Tersedia'), findsWidgets);
    expect(find.text('iPhone Belum Kembali'), findsWidgets);
    expect(find.text('Booking Hari Ini'), findsWidgets);
    expect(find.text('Pendapatan Hari Ini'), findsWidgets);

    final sheetFinder = find.byType(OperationalMetricDetailSheet);

    // ========================================================
    // TEST 1: Tap "Pickup Hari Ini" card on mobile
    // ========================================================
    await tester.tap(find.text('Pickup Hari Ini').first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // Verify Pickup Popup content inside bottom sheet
    expect(sheetFinder, findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Budi Santoso')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('SN: SN-IP13P-001')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Serah Terima Unit')), findsOneWidget);

    // Tap close button ("✕")
    await tester.tap(find.descendant(of: sheetFinder, matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsNothing);

    // ========================================================
    // TEST 2: Tap "Return Hari Ini" card on mobile
    // ========================================================
    await tester.tap(find.text('Return Hari Ini').first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Semua Return')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Terlambat / Overdue')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('On Time')), findsOneWidget);

    // Verify Overdue details, penalty calculation, WA button, and return button
    expect(find.descendant(of: sheetFinder, matching: find.text('Siti Rahma')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('SN: SN-IP14P-999')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Proses Pengembalian')), findsWidgets);
    expect(find.descendant(of: sheetFinder, matching: find.text('WA')), findsWidgets);
    expect(find.descendant(of: sheetFinder, matching: find.textContaining('Terlambat')), findsWidgets);
    expect(find.descendant(of: sheetFinder, matching: find.textContaining('Denda:')), findsWidgets);

    // Close return popup
    await tester.tap(find.descendant(of: sheetFinder, matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsNothing);

    // ========================================================
    // TEST 3: Tap "Unit Disewa" card on mobile
    // ========================================================
    await tester.tap(find.text('Unit Disewa').first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.textContaining('Unit Disewa')), findsWidgets);

    // Close rented popup
    await tester.tap(find.descendant(of: sheetFinder, matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsNothing);

    // ========================================================
    // TEST 4: Tap "Omzet Hari Ini" card on mobile
    // ========================================================
    await tester.tap(find.text('Omzet Hari Ini').first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(sheetFinder, findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.textContaining('Omzet Hari Ini')), findsWidgets);

    // Test switching tabs inside the sheet to "Pickup Hari Ini"
    await tester.tap(find.descendant(of: sheetFinder, matching: find.text('Pickup Hari Ini')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.descendant(of: sheetFinder, matching: find.text('Budi Santoso')), findsOneWidget);

    // Close popup
    await tester.tap(find.descendant(of: sheetFinder, matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsNothing);
  });

  testWidgets('Tapping mobile cards by original labels also opens interactive sheets and shift warning works', (WidgetTester tester) async {
    final now = DateTime.now();

    final overdueReturnBooking = createBooking(
      id: 102,
      code: 'SKY-RETURN-LATE',
      customerName: 'Siti Rahma',
      customerPhone: '085712345678',
      jaminanType: 'SIM A',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.rented,
      startDate: now.subtract(const Duration(days: 1, hours: 2, minutes: 15)),
      endDate: now.subtract(const Duration(hours: 2, minutes: 15)),
      serialNumber: 'SN-IP14P-999',
      iphoneName: 'iPhone 14 Pro',
      isLate: true,
      diffHours: 2.25,
      hoursLate: 2,
      lateMinutes: 15,
      estimatedLateFee: 50000,
    );

    final repo = BookingRepository();
    repo.setTestBookings([overdueReturnBooking]);
    repo.setDashboardCache(
      data: {
        'isOnline': true,
        'metrics': {
          'availableUnits': 12,
          'unreturnedUnits': 1,
          'bookingToday': 0,
          'revenueToday': 450000.0,
          'activeRentals': 1,
          'todayPickups': 0,
          'todayReturns': 1,
          'overdueReturns': 1,
          'rentedUnits': 1,
          'totalUnits': 15,
          'utilizationRate': 7,
        },
        'financials': {
          'totalRevenue': 450000.0,
          'totalHeldDeposit': 150000.0,
          'totalRefundedDeposit': 0.0,
        },
        'actionItems': [overdueReturnBooking],
        'recentBookings': [overdueReturnBooking],
        'allQueue': [overdueReturnBooking],
      },
      readyUnits: [],
      pendingTransferCount: 0,
    );

    // Mobile resolution
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(repository: repo),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final sheetFinder = find.byType(OperationalMetricDetailSheet);

    // Tap "iPhone Belum Kembali"
    await tester.tap(find.text('iPhone Belum Kembali').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(sheetFinder, findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Siti Rahma')), findsOneWidget);

    // Tap "Proses Pengembalian" without active shift -> should display Shift Warning
    await tester.tap(find.byKey(const Key('btn_proses_pengembalian_SKY-RETURN-LATE')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Shift Kasir Belum Dibuka'), findsWidgets);

    // Dismiss dialog via 'Batal' button
    await tester.tap(find.text('Batal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Close sheet
    await tester.tap(find.descendant(of: sheetFinder, matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsNothing);
  });
}
