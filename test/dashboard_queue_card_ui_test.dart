import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/screens/dashboard/dashboard_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
  });

  BookingModel createBooking({
    required int id,
    required String code,
    required PaymentStatus paymentStatus,
    required BookingStatus bookingStatus,
  }) {
    return BookingModel(
      id: id,
      bookingCode: code,
      customerName: 'Jois Vanka',
      customerPhone: '081234567890',
      customerEmail: 'jois@example.com',
      address: 'Jl. Test No. 1',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: DateTime(2026, 10, 14, 9, 43),
      endDate: DateTime(2026, 10, 15, 9, 43),
      durationDays: 1,
      startTime: '09:43',
      price: 70000,
      deposit: 0,
      status: bookingStatus,
      paymentStatus: paymentStatus,
      iphone: const IphoneModel(
        id: 11,
        name: 'iPhone 11',
        storage: '64GB',
        color: 'Hijau',
        serialNumber: 'FFYH90JKSOLL',
        assetCode: 'AST-IP11-001',
        status: 'ready',
        batteryHealth: 90,
      ),
    );
  }

  testWidgets('Dashboard transaction queue displays card matching reference design and PHP status mappings', (WidgetTester tester) async {
    final sampleBooking = createBooking(
      id: 999,
      code: 'SKY2610130GLG',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.confirmed,
    );

    final repo = BookingRepository();
    repo.setTestBookings([sampleBooking]);
    repo.setDashboardCache(
      data: {
        'isOnline': true,
        'metrics': {
          'availableUnits': 20,
          'unreturnedUnits': 0,
          'bookingToday': 1,
          'revenueToday': 70000.0,
          'activeRentals': 0,
          'todayPickups': 1,
          'todayReturns': 0,
          'overdueReturns': 0,
          'rentedUnits': 0,
          'maintenanceUnits': 0,
          'totalUnits': 30,
          'utilizationRate': 10,
        },
        'financials': {
          'totalRevenue': 70000.0,
          'totalHeldDeposit': 0.0,
          'totalRefundedDeposit': 0.0,
        },
        'actionItems': [sampleBooking],
        'recentBookings': [sampleBooking],
        'allQueue': [sampleBooking],
      },
      readyUnits: [],
      pendingTransferCount: 0,
    );

    tester.view.physicalSize = const Size(800, 2400);
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

    // 1. Verify booking code and date in header
    expect(find.text('#SKY2610130GLG'), findsOneWidget);
    expect(find.text('14 Okt 26 09:43'), findsOneWidget);

    // 2. Verify header background is white and booking code text represents paid status (green-600)
    final bookingCodeWidget = tester.widget<Text>(find.text('#SKY2610130GLG'));
    expect(bookingCodeWidget.style?.color, const Color(0xFF16A34A));

    // 3. Verify Customer Name, Model + Color, Serial Number
    expect(find.text('Jois Vanka'), findsOneWidget);
    expect(find.text('iPhone 11 Hijau'), findsOneWidget);
    expect(find.text('FFYH90JKSOLL'), findsOneWidget);

    // 4. Verify booking status badge 'Dikonfirmasi'
    expect(find.text('Dikonfirmasi'), findsOneWidget);

    // 5. Verify price 'Rp' and '70.000' with reduced font size (17 pt)
    final cardPriceFinder = find.descendant(
      of: find.byType(ClipRRect),
      matching: find.textContaining('70.000'),
    );
    expect(cardPriceFinder, findsOneWidget);
    final priceRichText = tester.widget<Text>(cardPriceFinder);
    final spans = (priceRichText.textSpan as TextSpan).children!;
    final priceSpan = spans.last as TextSpan;
    expect(priceSpan.style?.fontSize, 17.0);

    // 6. Verify iPhone name size (15.5 pt)
    final iphoneNameWidget = tester.widget<Text>(find.text('iPhone 11 Hijau'));
    expect(iphoneNameWidget.style?.fontSize, 15.5);

    // 7. Verify 'hapus' button exists and shows confirmation dialog when tapped
    expect(find.text('hapus'), findsOneWidget);
    await tester.tap(find.text('hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Booking?'), findsOneWidget);
  });

  testWidgets('Removes trailing "default" word from iPhone name', (WidgetTester tester) async {
    final defaultBooking = createBooking(
      id: 998,
      code: 'SKY-DEF',
      paymentStatus: PaymentStatus.paid,
      bookingStatus: BookingStatus.confirmed,
    ).copyWith(
      iphone: const IphoneModel(
        id: 12,
        name: 'iPhone 11',
        storage: '128GB',
        color: 'Default',
        serialNumber: 'SN-DEFAULT-01',
        assetCode: 'AST-01',
        status: 'ready',
        batteryHealth: 90,
      ),
    );

    final repo = BookingRepository();
    repo.setTestBookings([defaultBooking]);
    repo.setDashboardCache(
      data: {
        'isOnline': true,
        'metrics': {'availableUnits': 10, 'totalUnits': 20},
        'financials': {'totalRevenue': 70000.0, 'totalHeldDeposit': 0.0, 'totalRefundedDeposit': 0.0},
        'actionItems': [defaultBooking],
        'recentBookings': [defaultBooking],
        'allQueue': [defaultBooking],
      },
      readyUnits: [],
      pendingTransferCount: 0,
    );

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardScreen(repository: repo))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 'iPhone 11 Default' should be cleaned to 'iPhone 11'
    expect(find.text('iPhone 11'), findsOneWidget);
    expect(find.text('iPhone 11 Default'), findsNothing);
  });

  testWidgets('Verifies PaymentStatus and BookingStatus color mappings matching PHP switch statements', (WidgetTester tester) async {
    final bookings = [
      createBooking(id: 1, code: 'SKY01', paymentStatus: PaymentStatus.partial, bookingStatus: BookingStatus.pending),
      createBooking(id: 2, code: 'SKY02', paymentStatus: PaymentStatus.unpaid, bookingStatus: BookingStatus.returned),
      createBooking(id: 3, code: 'SKY03', paymentStatus: PaymentStatus.paid, bookingStatus: BookingStatus.cancelled),
    ];

    final repo = BookingRepository();
    repo.setTestBookings(bookings);
    repo.setDashboardCache(
      data: {
        'isOnline': true,
        'metrics': {
          'availableUnits': 20,
          'unreturnedUnits': 0,
          'bookingToday': 3,
          'revenueToday': 210000.0,
          'activeRentals': 0,
          'todayPickups': 1,
          'todayReturns': 1,
          'overdueReturns': 0,
          'rentedUnits': 0,
          'maintenanceUnits': 0,
          'totalUnits': 30,
          'utilizationRate': 10,
        },
        'financials': {
          'totalRevenue': 210000.0,
          'totalHeldDeposit': 0.0,
          'totalRefundedDeposit': 0.0,
        },
        'actionItems': bookings,
        'recentBookings': bookings,
        'allQueue': bookings,
      },
      readyUnits: [],
      pendingTransferCount: 0,
    );

    tester.view.physicalSize = const Size(800, 2400);
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

    // Verify status badges from PHP switch
    expect(find.text('Menunggu Pembayaran'), findsOneWidget); // pending -> yellow-500
    expect(find.text('Dikembalikan'), findsOneWidget);        // returned -> blue-500
    expect(find.text('Dibatalkan'), findsOneWidget);          // cancelled -> red-500

    // Verify booking code colors from PHP payment_status switch
    // partial -> amber-600 (0xFFD97706)
    final partialCode = tester.widget<Text>(find.text('#SKY01'));
    expect(partialCode.style?.color, const Color(0xFFD97706));

    // unpaid -> red-600 (0xFFDC2626)
    final unpaidCode = tester.widget<Text>(find.text('#SKY02'));
    expect(unpaidCode.style?.color, const Color(0xFFDC2626));

    // paid -> green-600 (0xFF16A34A)
    final paidCode = tester.widget<Text>(find.text('#SKY03'));
    expect(paidCode.style?.color, const Color(0xFF16A34A));
  });
}
