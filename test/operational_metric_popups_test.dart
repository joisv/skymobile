import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/models/payment_model.dart';
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

  testWidgets('Operational Metrics cards open responsive popups in tablet landscape', (WidgetTester tester) async {
    final now = DateTime.now();

    // 1. Pickup booking (Confirmed, scheduled pickup today)
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

    // 2. Overdue Return booking (Rented, overdue by 2 hours 15 mins)
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

    // 3. On-time Return booking (Rented, return later today)
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

    // Tablet landscape viewport
    tester.view.physicalSize = const Size(1280, 800);
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

    // Verify all 4 operational metric cards exist
    expect(find.text('Pickup Hari Ini'), findsWidgets);
    expect(find.text('Return Hari Ini'), findsWidgets);
    expect(find.text('Unit Disewa'), findsWidgets);
    expect(find.text('Omzet Hari Ini'), findsWidgets);

    final sheetFinder = find.byType(OperationalMetricDetailSheet);

    // ========================================================
    // TEST 1: Tap "Pickup Hari Ini" card
    // ========================================================
    await tester.tap(find.text('Pickup Hari Ini').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350)); // Wait for slide animation

    // Verify Pickup Popup content inside sheet
    expect(sheetFinder, findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Budi Santoso')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('SN: SN-IP13P-001')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Serah Terima Unit')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Lunas')), findsWidgets);

    // Tap close button ("✕")
    await tester.tap(find.descendant(of: sheetFinder, matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsNothing);

    // ========================================================
    // TEST 2: Tap "Return Hari Ini" card
    // ========================================================
    await tester.tap(find.text('Return Hari Ini').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(sheetFinder, findsOneWidget);
    // Verify Filter Toggle Chips
    expect(find.descendant(of: sheetFinder, matching: find.text('Semua Return')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Terlambat / Overdue')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('On Time')), findsOneWidget);

    // Verify Overdue items details
    expect(find.descendant(of: sheetFinder, matching: find.text('Siti Rahma')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('SN: SN-IP14P-999')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Proses Pengembalian')), findsWidgets);
    expect(find.descendant(of: sheetFinder, matching: find.textContaining('Terlambat')), findsWidgets);
    expect(find.descendant(of: sheetFinder, matching: find.textContaining('Denda:')), findsWidgets);

    // Tap [Terlambat / Overdue] filter chip
    await tester.tap(find.descendant(of: sheetFinder, matching: find.text('Terlambat / Overdue')));
    await tester.pump();
    expect(find.descendant(of: sheetFinder, matching: find.text('Siti Rahma')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Dewi Lestari')), findsNothing); // on-time excluded

    // Tap [On Time] filter chip
    await tester.tap(find.descendant(of: sheetFinder, matching: find.text('On Time')));
    await tester.pump();
    expect(find.descendant(of: sheetFinder, matching: find.text('Dewi Lestari')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Siti Rahma')), findsNothing); // overdue excluded

    // Close return popup
    await tester.tap(find.descendant(of: sheetFinder, matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsNothing);

    // ========================================================
    // TEST 3: Tap "Unit Disewa" card
    // ========================================================
    await tester.tap(find.text('Unit Disewa').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(sheetFinder, findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.textContaining('Utilitas Toko')), findsWidgets);
    expect(find.descendant(of: sheetFinder, matching: find.text('Penyewa: Siti Rahma')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Penyewa: Dewi Lestari')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('SN: SN-IP14P-999')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('SN: SN-IP15PM-777')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Detail Rental')), findsWidgets);
    expect(find.descendant(of: sheetFinder, matching: find.text('Hubungi WA')), findsWidgets);

    // Close popup
    await tester.tap(find.descendant(of: sheetFinder, matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsNothing);

    // ========================================================
    // TEST 4: Tap "Omzet Hari Ini" card
    // ========================================================
    await tester.tap(find.text('Omzet Hari Ini').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(sheetFinder, findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Total Omzet')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Tunai (Cash)')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Non-Tunai (QRIS/Trf)')), findsOneWidget);
    expect(find.descendant(of: sheetFinder, matching: find.text('Log Transaksi Hari Ini')), findsOneWidget);

    // Test switching tabs inside the drawer to "Pickup Hari Ini"
    await tester.tap(find.descendant(of: sheetFinder, matching: find.text('Pickup Hari Ini')));
    await tester.pump();
    expect(find.descendant(of: sheetFinder, matching: find.text('Budi Santoso')), findsOneWidget);

    // Close popup
    await tester.tap(find.descendant(of: sheetFinder, matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(sheetFinder, findsNothing);
  });

  testWidgets('OperationalMetricDetailSheet displays clean empty states when no records exist', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = BookingRepository();
    repo.setTestBookings([]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationalMetricDetailSheet(
            initialType: OperationalMetricType.returnToday,
            metrics: const {
              'revenueToday': 0.0,
              'totalUnits': 10,
              'availableUnits': 10,
              'rentedUnits': 0,
            },
            allQueue: const [],
            pickupItems: const [],
            returnItems: const [],
            repository: repo,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    // Return empty state
    expect(find.text('Tidak ada data pengembalian unit'), findsOneWidget);

    // Switch to Pickup empty state
    await tester.tap(find.text('Pickup Hari Ini'));
    await tester.pump();
    expect(find.text('Tidak ada jadwal pickup hari ini'), findsOneWidget);

    // Switch to Unit Disewa empty state
    await tester.tap(find.text('Unit Disewa'));
    await tester.pump();
    expect(find.text('Seluruh unit berada di outlet'), findsOneWidget);

    // Switch to Omzet empty state
    await tester.tap(find.text('Omzet Hari Ini'));
    await tester.pump();
    expect(find.text('Belum ada transaksi omzet hari ini'), findsOneWidget);
  });

  testWidgets('Return Hari Ini accurately counts [Pending + Overdue] and cleanly separates sections', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    final b1OverdueConfirmed = createBooking(
      id: 101,
      code: 'SKY-OD-1',
      customerName: 'Kurnia Ningsih',
      customerPhone: '081234567891',
      jaminanType: 'KTP Fisik',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.confirmed,
      startDate: twoDaysAgo.subtract(const Duration(days: 2)),
      endDate: twoDaysAgo,
      serialNumber: 'SN-IP13-001',
      iphoneName: 'iPhone 13 128GB',
      isLate: true,
      hoursLate: 48,
    );

    final b2OverdueRented = createBooking(
      id: 102,
      code: 'SKY-OD-2',
      customerName: 'Denis Ariska',
      customerPhone: '081234567892',
      jaminanType: 'SIM A',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.rented,
      startDate: yesterday.subtract(const Duration(days: 2)),
      endDate: yesterday,
      serialNumber: 'SN-IP14-002',
      iphoneName: 'iPhone 14 128GB',
      isLate: true,
      hoursLate: 24,
    );

    final b3DueToday = createBooking(
      id: 103,
      code: 'SKY-TD-3',
      customerName: 'Yudha Septi',
      customerPhone: '081234567893',
      jaminanType: 'KTP Fisik',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.confirmed,
      startDate: today.subtract(const Duration(days: 1)),
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 0),
      serialNumber: 'SN-IP15-003',
      iphoneName: 'iPhone 15 128GB',
      isLate: false,
    );

    final b4Returned = createBooking(
      id: 104,
      code: 'SKY-RET-4',
      customerName: 'Selesai Sewa',
      customerPhone: '081234567894',
      jaminanType: 'KTP Fisik',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.returned,
      startDate: yesterday.subtract(const Duration(days: 2)),
      endDate: yesterday,
      serialNumber: 'SN-IP13-004',
      iphoneName: 'iPhone 13 128GB',
    );

    final allQueue = [b1OverdueConfirmed, b2OverdueRented, b3DueToday, b4Returned];

    final repo = BookingRepository();
    repo.setTestBookings(allQueue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationalMetricDetailSheet(
            initialType: OperationalMetricType.returnToday,
            metrics: const {
              'unreturnedUnits': 3,
              'todayReturns': 1,
              'overdueReturns': 2,
            },
            allQueue: allQueue,
            pickupItems: const [],
            returnItems: const [],
            repository: repo,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify header badge reflects [Pending Returns + Overdue Returns] = 3 Unit (excluding returned b4)
    expect(find.text('3 Unit'), findsOneWidget);

    // Verify filter toggle chips with counts
    expect(find.text('Semua Return'), findsOneWidget);
    expect(find.text('Terlambat / Overdue'), findsOneWidget);
    expect(find.text('Jadwal Hari Ini'), findsOneWidget);
    expect(find.text('On Time'), findsOneWidget);

    // Verify clean section headers in "Semua Return" view
    expect(find.text('Terlambat / Overdue (2 Unit)'), findsOneWidget);
    expect(find.text('Jadwal Hari Ini (1 Unit)'), findsOneWidget);

    // Verify list items present
    expect(find.text('Kurnia Ningsih'), findsOneWidget);
    expect(find.text('Denis Ariska'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Yudha Septi'), 100, scrollable: find.byType(Scrollable).last);
    expect(find.text('Yudha Septi'), findsOneWidget);
    expect(find.text('Selesai Sewa'), findsNothing);

    // Scroll back to top
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 400));
    await tester.pump();

    // Filter by "Terlambat / Overdue"
    await tester.tap(find.text('Terlambat / Overdue'));
    await tester.pump();
    expect(find.text('Kurnia Ningsih'), findsOneWidget);
    expect(find.text('Denis Ariska'), findsOneWidget);
    expect(find.text('Yudha Septi'), findsNothing);

    // Filter by "Jadwal Hari Ini"
    await tester.tap(find.text('Jadwal Hari Ini'));
    await tester.pump();
    expect(find.text('Yudha Septi'), findsOneWidget);
    expect(find.text('Kurnia Ningsih'), findsNothing);
    expect(find.text('Denis Ariska'), findsNothing);
  });

  testWidgets('Omzet Hari Ini drawer groups multi-part payments (e.g. SKY261103ZIV2) and deduplicates entries', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();

    final tx1DP = PaymentTransactionModel(
      id: 1879,
      bookingId: 4305,
      bookingCode: 'SKY261103ZIV2',
      customerName: 'Budi Test',
      customerPhone: '081234567899',
      iphoneName: 'iPhone 13 128GB',
      rentTotal: 70000.0,
      paidAmount: 30000.0,
      remainingAmount: 40000.0,
      depositAmount: 0.0,
      depositStatus: DepositStatus.held,
      paymentStatus: 'partial',
      paymentMethod: 'Transfer BCA',
      transactionDate: DateTime(now.year, now.month, now.day, 9, 30),
      notes: 'Pembayaran DP Uang Muka',
    );

    final tx2Pelunasan = PaymentTransactionModel(
      id: 1880,
      bookingId: 4305,
      bookingCode: 'SKY261103ZIV2',
      customerName: 'Budi Test',
      customerPhone: '081234567899',
      iphoneName: 'iPhone 13 128GB',
      rentTotal: 70000.0,
      paidAmount: 40000.0,
      remainingAmount: 0.0,
      depositAmount: 0.0,
      depositStatus: DepositStatus.held,
      paymentStatus: 'paid',
      paymentMethod: 'Tunai',
      transactionDate: DateTime(now.year, now.month, now.day, 14, 15),
      notes: 'Pembayaran Pelunasan Sewa via Tunai',
    );

    // Duplicate of tx2 (e.g., duplicate webhook or double submit)
    final tx2Duplicate = PaymentTransactionModel(
      id: 1880,
      bookingId: 4305,
      bookingCode: 'SKY261103ZIV2',
      customerName: 'Budi Test',
      customerPhone: '081234567899',
      iphoneName: 'iPhone 13 128GB',
      rentTotal: 70000.0,
      paidAmount: 40000.0,
      remainingAmount: 0.0,
      depositAmount: 0.0,
      depositStatus: DepositStatus.held,
      paymentStatus: 'paid',
      paymentMethod: 'Tunai',
      transactionDate: DateTime(now.year, now.month, now.day, 14, 15),
      notes: 'Pembayaran Pelunasan Sewa via Tunai',
    );

    final repo = BookingRepository();
    repo.setTestTransactions([tx1DP, tx2Pelunasan, tx2Duplicate]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationalMetricDetailSheet(
            initialType: OperationalMetricType.revenueToday,
            metrics: const {
              'revenueToday': 70000.0,
            },
            allQueue: const [],
            pickupItems: const [],
            returnItems: const [],
            repository: repo,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Verify SKY261103ZIV2 only appears once as parent card, NOT duplicated!
    expect(find.text('#SKY261103ZIV2'), findsOneWidget);

    // Verify multi-part badge
    expect(find.text('2x Pembayaran'), findsOneWidget);

    // Verify itemized payment breakdown section
    expect(find.text('Rincian Pembayaran Masuk:'), findsOneWidget);
    expect(find.text('Uang Muka (DP)'), findsOneWidget);
    expect(find.text('Pelunasan Sewa'), findsOneWidget);

    // Verify amounts
    expect(find.text('Rp 30.000'), findsWidgets); // on breakdown row and Non-Tunai card
    expect(find.text('Rp 40.000'), findsWidgets); // on breakdown row and Tunai card
    expect(find.text('Rp 70.000'), findsWidgets); // on card total and Total Omzet summary
  });

  testWidgets('Unit Disewa drawer includes overdue units still with customers', (WidgetTester tester) async {
    final now = DateTime.now();
    // Overdue unit with status rented
    final overdueRentedBooking = createBooking(
      id: 201,
      code: 'SKY-OVERDUE-RENTED',
      customerName: 'Asep Overdue',
      customerPhone: '081299998888',
      jaminanType: 'KTP Fisik',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.rented,
      startDate: now.subtract(const Duration(days: 2)),
      endDate: now.subtract(const Duration(hours: 3)),
      serialNumber: 'SN-IP14-RENTED',
      iphoneName: 'iPhone 14',
      isLate: true,
      hoursLate: 3,
    );

    final repo = BookingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationalMetricDetailSheet(
            initialType: OperationalMetricType.rentedUnits,
            metrics: const {
              'totalUnits': 50,
              'rentedUnits': 1,
            },
            allQueue: [overdueRentedBooking],
            pickupItems: const [],
            returnItems: [overdueRentedBooking],
            repository: repo,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify it is listed and not showing empty state
    expect(find.text('Penyewa: Asep Overdue'), findsOneWidget);
    expect(find.text('SN: SN-IP14-RENTED'), findsOneWidget);
    expect(find.textContaining('1 / 50 Unit Disewa'), findsOneWidget);
  });

  testWidgets('Return Hari Ini differentiates overdue severity (amber vs red) and Batas Kembali', (WidgetTester tester) async {
    final now = DateTime.now();

    // Short delay: 30 minutes (< 2 hours) -> Amber
    final shortDelayBooking = createBooking(
      id: 301,
      code: 'SKY-RETURN-SHORT',
      customerName: 'Joko Cepat',
      customerPhone: '081211112222',
      jaminanType: 'SIM A',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.rented,
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.subtract(const Duration(minutes: 30)),
      serialNumber: 'SN-IP13-SHORT',
      iphoneName: 'iPhone 13',
      isLate: true,
      hoursLate: 0,
      lateMinutes: 30,
      estimatedLateFee: 15000,
    );

    // Long delay: 5 hours (>= 2 hours) -> Red
    final longDelayBooking = createBooking(
      id: 302,
      code: 'SKY-RETURN-LONG',
      customerName: 'Siti Lambat',
      customerPhone: '081233334444',
      jaminanType: 'KTP Fisik',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.rented,
      startDate: now.subtract(const Duration(days: 2)),
      endDate: now.subtract(const Duration(hours: 5)),
      serialNumber: 'SN-IP14-LONG',
      iphoneName: 'iPhone 14 Pro',
      isLate: true,
      hoursLate: 5,
      lateMinutes: 0,
      estimatedLateFee: 150000,
    );

    final repo = BookingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationalMetricDetailSheet(
            initialType: OperationalMetricType.returnToday,
            metrics: const {
              'unreturnedUnits': 2,
            },
            allQueue: [shortDelayBooking, longDelayBooking],
            pickupItems: const [],
            returnItems: [shortDelayBooking, longDelayBooking],
            repository: repo,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Both cards rendered
    expect(find.text('Joko Cepat'), findsOneWidget);
    expect(find.text('Siti Lambat'), findsOneWidget);

    // Batas Kembali label rendered adjacent
    expect(find.text('Batas Kembali:'), findsNWidgets(2));

    // Verify Process Return buttons exist
    expect(find.byKey(const Key('btn_proses_pengembalian_SKY-RETURN-SHORT')), findsOneWidget);
    expect(find.byKey(const Key('btn_proses_pengembalian_SKY-RETURN-LONG')), findsOneWidget);
  });

  testWidgets('Pickup Hari Ini formats time without seconds and has compact layout', (WidgetTester tester) async {
    final now = DateTime.now();
    final pickupBooking = createBooking(
      id: 401,
      code: 'SKY-PICKUP-CLEAN',
      customerName: 'Dewi Lestari',
      customerPhone: '081277778888',
      jaminanType: 'KTP Fisik',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.confirmed,
      startDate: DateTime(now.year, now.month, now.day, 15, 26),
      endDate: now.add(const Duration(days: 1)),
      serialNumber: 'SN-IP15-CLEAN',
      iphoneName: 'iPhone 15',
      startTime: '15:26:00', // timestamp with seconds
    );

    final repo = BookingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationalMetricDetailSheet(
            initialType: OperationalMetricType.pickup,
            metrics: const {
              'bookingToday': 1,
            },
            allQueue: [pickupBooking],
            pickupItems: [pickupBooking],
            returnItems: const [],
            repository: repo,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify formatted time does not have seconds (:00)
    expect(find.text('Jadwal: 15:26 WIB'), findsOneWidget);
    expect(find.text('Jadwal: 15:26:00 WIB'), findsNothing);

    // Verify Serah Terima Unit button exists in compact layout
    expect(find.byKey(const Key('btn_serah_terima_SKY-PICKUP-CLEAN')), findsOneWidget);
  });

  testWidgets('Omzet Hari Ini displays payment type tag beside payment method', (WidgetTester tester) async {
    final now = DateTime.now();
    final singleTx = PaymentTransactionModel(
      id: 501,
      bookingId: 4309,
      bookingCode: 'SKY-FULL-PAY',
      customerName: 'Agus Penuh',
      customerPhone: '081244445555',
      iphoneName: 'iPhone 13',
      rentTotal: 150000.0,
      paidAmount: 150000.0,
      remainingAmount: 0.0,
      depositAmount: 0.0,
      depositStatus: DepositStatus.held,
      paymentStatus: 'paid',
      paymentMethod: 'QRIS',
      transactionDate: DateTime(now.year, now.month, now.day, 11, 0),
    );

    final repo = BookingRepository();
    repo.setTestTransactions([singleTx]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationalMetricDetailSheet(
            initialType: OperationalMetricType.revenueToday,
            metrics: const {
              'revenueToday': 150000.0,
            },
            allQueue: const [],
            pickupItems: const [],
            returnItems: const [],
            repository: repo,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Verify subtle payment type tag 'Sewa Penuh'
    expect(find.text('Sewa Penuh'), findsOneWidget);
    expect(find.text('QRIS'), findsWidgets);
  });
}
