import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/cash_drawer_shift_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/screens/booking/booking_detail_screen.dart';
import 'package:skyrental_admin/screens/dashboard/dashboard_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(
      const AdminUserModel(
        id: 1,
        name: 'Kasir Cabang',
        email: 'kasir@skyrent.id',
        phone: '081234567890',
        outletName: 'Genteng Pusat',
        shiftName: 'Shift Pagi',
        role: 'Staff Kasir',
        affiliateId: 4,
        roles: ['staff'],
      ),
    );
  });

  tearDown(() {
    MockBookingData.activeShift = null;
  });

  group('Bug 1: Dynamic Add-on Pricing in Booking Detail & Model Deserialization', () {
    test('IphoneModel properly reads price, subtotal, and pivot fields with fallback', () {
      final addonWithPrice = IphoneModel.fromJson({
        'id': 10,
        'name': 'DJI Mic Wireless',
        'is_addon': 1,
        'price': 45000,
      });
      expect(addonWithPrice.price, 45000.0);
      expect(addonWithPrice.dailyRate, 45000.0);

      final addonWithSubtotal = IphoneModel.fromJson({
        'id': 11,
        'name': 'Tripod Takara',
        'is_addon': true,
        'subtotal': 25000,
      });
      expect(addonWithSubtotal.subtotal, 25000.0);
      expect(addonWithSubtotal.dailyRate, 25000.0);

      final addonWithPivot = IphoneModel.fromJson({
        'id': 12,
        'name': 'Anker MagSafe Battery',
        'is_addon': true,
        'pivot': {'price': 30000},
      });
      expect(addonWithPivot.dailyRate, 30000.0);

      // Addon without price should fallback to 0.0, NOT 100000.0
      final addonZeroFallback = IphoneModel.fromJson({
        'id': 13,
        'name': 'Kabel Lightning',
        'is_addon': true,
      });
      expect(addonZeroFallback.dailyRate, 0.0);
    });

    test('BookingModel.fromJson deserializes addon_items and merges prices into asset', () {
      final bookingJson = {
        'id': 101,
        'booking_code': 'BKG-261105-001',
        'customer_name': 'Ahmad Fauzi',
        'customer_phone': '08123456789',
        'price': 180000,
        'start_booking_date': '2026-11-05',
        'end_booking_date': '2026-11-06',
        'iphone': {
          'id': 1,
          'name': 'iPhone 13',
          'storage': '128GB',
          'price': 120000,
        },
        'addon_items': [
          {
            'price': 35000,
            'asset': {
              'id': 50,
              'name': 'Tripod Beike',
              'asset_code': 'ADDON-TRP-01',
              'is_addon': 1,
            },
          },
          {
            'price': 25000,
            'asset': {
              'id': 51,
              'name': 'Lighting Godox LED',
              'asset_code': 'ADDON-LGT-01',
              'is_addon': 1,
            },
          },
        ],
      };

      final booking = BookingModel.fromJson(bookingJson);
      expect(booking.hasAddons, isTrue);
      expect(booking.addonDevices.length, 2);
      expect(booking.addonDevices[0].name, 'Tripod Beike');
      expect(booking.addonDevices[0].price, 35000.0);
      expect(booking.addonDevices[0].dailyRate, 35000.0);
      expect(booking.addonDevices[1].name, 'Lighting Godox LED');
      expect(booking.addonDevices[1].price, 25000.0);
      expect(booking.addonDevices[1].dailyRate, 25000.0);

      // Addon subtotal dynamic aggregation
      expect(booking.addonSubtotal, 60000.0);
      expect(booking.primarySubtotal, 120000.0);
    });

    testWidgets('BookingDetailScreen displays dynamic add-on prices instead of hardcoded Rp 100.000', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final booking = BookingModel(
        id: 999,
        bookingCode: 'BKG-TEST-ADDON',
        customerName: 'Siti Rahma',
        customerPhone: '08198765432',
        customerEmail: 'siti@test.com',
        pickupType: 'Outlet',
        jaminanType: 'KTP Asli',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(hours: 24)),
        durationDays: 24,
        price: 215000.0,
        deposit: 0.0,
        primarySubtotal: 150000.0,
        addonSubtotal: 65000.0,
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.paid,
        iphone: const IphoneModel(
          id: 1,
          name: 'iPhone 15 Pro',
          storage: '128GB',
          color: 'Titanium Blue',
          serialNumber: 'SN15P001',
          assetCode: 'AST-IPH-15P',
          status: 'rented',
          durations: [
            IphoneDurationOption(id: 1, name: '24 Jam', hours: 24, price: 150000.0),
          ],
        ),
        addonDevices: const [
          IphoneModel(
            id: 201,
            name: 'Gimbal DJI OM6',
            storage: '',
            color: 'Gray',
            serialNumber: 'SN-GMB-01',
            assetCode: 'ADDON-GMB-01',
            status: 'rented',
            isAddon: true,
            price: 40000.0,
          ),
          IphoneModel(
            id: 202,
            name: 'Tripod Aluminium',
            storage: '',
            color: 'Black',
            serialNumber: 'SN-TRP-01',
            assetCode: 'ADDON-TRP-01',
            status: 'rented',
            isAddon: true,
            price: 25000.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingDetailScreen(booking: booking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify dynamic prices are shown for Gimbal and Tripod
      expect(find.textContaining('Gimbal DJI OM6'), findsWidgets);
      expect(find.textContaining('Tripod Aluminium'), findsWidgets);

      // Must display Rp 40.000 and Rp 25.000
      expect(find.textContaining('40.000'), findsWidgets);
      expect(find.textContaining('25.000'), findsWidgets);

      // Must NOT display Rp 100.000 for the add-ons
      expect(find.text('Rp 100.000'), findsNothing);
      expect(find.text('+ Rp 100.000'), findsNothing);

      // Verify subtotal add-on reflects dynamic 65.000
      expect(find.textContaining('65.000'), findsWidgets);
    });
  });

  group('Bug 2: Stale Shift State & Mobile Dashboard Shift Guard', () {
    testWidgets('Dashboard blocks + Buat Booking Baru when no shift is active and shows shift warning dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repository = BookingRepository();
      repository.setDashboardCache(
        data: {
          'isOnline': true,
          'metrics': {
            'availableUnits': 12,
            'unreturnedUnits': 0,
            'bookingToday': 0,
            'revenueToday': 0.0,
            'activeRentals': 0,
            'todayPickups': 0,
            'todayReturns': 0,
          },
          'recentBookings': <BookingModel>[],
        },
        readyUnits: [],
        pendingTransferCount: 0,
      );
      // Ensure no active shift
      repository.setTestShift(null);
      MockBookingData.activeShift = null;

      bool navigatedToCreateBooking = false;
      bool navigatedToCashierShift = false;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.createBooking: (ctx) {
              navigatedToCreateBooking = true;
              return const Scaffold(body: Text('Create Booking Page'));
            },
            AppRoutes.cashierShift: (ctx) {
              navigatedToCashierShift = true;
              return const Scaffold(body: Text('Cashier Shift Page'));
            },
          },
          home: DashboardScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Verify shift pill shows 'Shift Belum Dibuka'
      expect(find.text('Shift Belum Dibuka'), findsOneWidget);
      expect(find.text('Shift Aktif'), findsNothing);

      // 1. Test FAB triggers warning dialog
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Shift warning dialog must appear
      expect(find.text('Shift Kasir Belum Dibuka'), findsOneWidget);
      expect(find.byKey(const Key('btn_buka_shift_kasir')), findsOneWidget);
      expect(navigatedToCreateBooking, isFalse);

      // Tap 'Buka Shift Kasir' on the warning dialog
      await tester.tap(find.byKey(const Key('btn_buka_shift_kasir')));
      await tester.pumpAndSettle();

      expect(navigatedToCashierShift, isTrue);
    });

    testWidgets('Dashboard button in Aksi Cepat Kasir also triggers shift warning dialog when no active shift', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repository = BookingRepository();
      repository.setDashboardCache(
        data: {
          'isOnline': true,
          'metrics': {
            'availableUnits': 12,
            'unreturnedUnits': 0,
            'bookingToday': 0,
            'revenueToday': 0.0,
            'activeRentals': 0,
            'todayPickups': 0,
            'todayReturns': 0,
          },
          'recentBookings': <BookingModel>[],
        },
        readyUnits: [],
        pendingTransferCount: 0,
      );
      repository.setTestShift(null);
      MockBookingData.activeShift = null;

      bool navigatedToCreateBooking = false;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.createBooking: (ctx) {
              navigatedToCreateBooking = true;
              return const Scaffold(body: Text('Create Booking Page'));
            },
            AppRoutes.cashierShift: (ctx) => const Scaffold(body: Text('Cashier Shift Page')),
          },
          home: DashboardScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final createBookingBtn = find.text('Buat Booking Baru');
      expect(createBookingBtn, findsOneWidget);

      await tester.tap(createBookingBtn);
      await tester.pumpAndSettle();

      expect(find.text('Shift Kasir Belum Dibuka'), findsOneWidget);
      expect(navigatedToCreateBooking, isFalse);
    });

    testWidgets('Dashboard allows "+ Buat Booking Baru" when shift is active and pill shows "Shift Aktif"', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repository = BookingRepository();
      repository.setDashboardCache(
        data: {
          'isOnline': true,
          'metrics': {
            'availableUnits': 12,
            'unreturnedUnits': 0,
            'bookingToday': 0,
            'revenueToday': 0.0,
            'activeRentals': 0,
            'todayPickups': 0,
            'todayReturns': 0,
          },
          'recentBookings': <BookingModel>[],
        },
        readyUnits: [],
        pendingTransferCount: 0,
      );
      final activeShift = CashDrawerShiftModel(
        id: 1,
        shiftNumber: 'SHF-TEST-001',
        branchId: 4,
        openedByName: 'Kasir Cabang',
        openedAt: DateTime.now(),
        openingCashFloat: 100000.0,
        status: ShiftStatus.open,
      );
      repository.setTestShift(activeShift);
      MockBookingData.activeShift = activeShift;

      bool navigatedToCreateBooking = false;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.createBooking: (ctx) {
              navigatedToCreateBooking = true;
              return const Scaffold(body: Text('Create Booking Page'));
            },
            AppRoutes.cashierShift: (ctx) => const Scaffold(body: Text('Cashier Shift Page')),
          },
          home: DashboardScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Shift indicator pill shows 'Shift Aktif'
      expect(find.text('Shift Aktif'), findsOneWidget);
      expect(find.text('Shift Belum Dibuka'), findsNothing);

      // Tapping FAB (Buat Booking) must now navigate directly to Create Booking Page
      final fab = find.byType(FloatingActionButton);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(navigatedToCreateBooking, isTrue);
      expect(find.text('Create Booking Page'), findsOneWidget);
      expect(find.text('Shift Kasir Belum Dibuka'), findsNothing);
    });

    testWidgets('Dashboard dynamically updates shift pill from Shift Aktif to Shift Belum Dibuka upon shift closure and blocks booking', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repository = BookingRepository();
      repository.setDashboardCache(
        data: {
          'isOnline': true,
          'metrics': {
            'availableUnits': 12,
            'unreturnedUnits': 0,
            'bookingToday': 0,
            'revenueToday': 0.0,
            'activeRentals': 0,
            'todayPickups': 0,
            'todayReturns': 0,
          },
          'recentBookings': <BookingModel>[],
        },
        readyUnits: [],
        pendingTransferCount: 0,
      );

      // Start with active shift
      final activeShift = CashDrawerShiftModel(
        id: 1,
        shiftNumber: 'SHF-TEST-002',
        branchId: 4,
        openedByName: 'Kasir Cabang',
        openedAt: DateTime.now(),
        openingCashFloat: 100000.0,
        status: ShiftStatus.open,
      );
      repository.setTestShift(activeShift);
      MockBookingData.activeShift = activeShift;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.createBooking: (ctx) => const Scaffold(body: Text('Create Booking Page')),
            AppRoutes.cashierShift: (ctx) => const Scaffold(body: Text('Cashier Shift Page')),
          },
          home: DashboardScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shift Aktif'), findsOneWidget);
      expect(find.text('Shift Belum Dibuka'), findsNothing);

      // Simulate closing the shift
      repository.setTestShift(null);
      MockBookingData.activeShift = null;

      // Simulate route observer / didPopNext callback
      final dashboardState = tester.state<DashboardScreenState>(find.byType(DashboardScreen));
      dashboardState.didPopNext();
      await tester.pump();
      await tester.pumpAndSettle();

      // Shift pill must immediately reflect 'Shift Belum Dibuka'
      expect(find.text('Shift Belum Dibuka'), findsOneWidget);
      expect(find.text('Shift Aktif'), findsNothing);

      // Tap FAB (Buat Booking) -> must now be guarded!
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Shift Kasir Belum Dibuka'), findsOneWidget);
      expect(find.text('Create Booking Page'), findsNothing);
    });
  });
}
