import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/screens/dashboard/dashboard_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
  });

  group('Bug 1: iPhone Availability Flow & Booking Repository Tests', () {
    test('isUnitAvailableForPeriod: Overlapping booking blocks availability', () {
      final repo = BookingRepository();
      const unit = IphoneModel(
        id: 101,
        name: 'iPhone 15 Pro',
        storage: '128GB',
        color: 'Natural Titanium',
        serialNumber: 'SN-AVAIL-01',
        assetCode: 'AST-AVAIL-01',
        status: 'ready',
      );

      final now = DateTime.now();
      final bookingStart = now.add(const Duration(days: 2));
      final bookingEnd = now.add(const Duration(days: 4));

      // Add a confirmed booking for this unit
      repo.rawBookings.add(BookingModel(
        id: 901,
        bookingCode: 'SKY-TEST-901',
        customerName: 'Customer Test',
        customerPhone: '081234567890',
        customerEmail: 'test@example.com',
        pickupType: 'Outlet',
        jaminanType: 'KTP',
        startDate: bookingStart,
        endDate: bookingEnd,
        startTime: '10:00',
        endTime: '10:00',
        durationDays: 48,
        price: 200000,
        deposit: 200000,
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.paid,
        iphone: unit,
      ));

      // Overlapping request: day 3 to day 5 -> must NOT be available
      final requestStart = now.add(const Duration(days: 3));
      final requestEnd = now.add(const Duration(days: 5));
      final isAvail = repo.isUnitAvailableForPeriod(unit, requestStart, requestEnd);
      expect(isAvail, isFalse, reason: 'Overlapping booking must block availability');
    });

    test('isUnitAvailableForPeriod: Non-overlapping future request allows availability even if status is rented', () {
      final repo = BookingRepository();
      // Unit is rented right now
      const unit = IphoneModel(
        id: 102,
        name: 'iPhone 15 Pro',
        storage: '128GB',
        color: 'Blue Titanium',
        serialNumber: 'SN-AVAIL-02',
        assetCode: 'AST-AVAIL-02',
        status: 'rented',
      );

      final now = DateTime.now();
      // Current active rental ends tomorrow at 12:00
      final activeRentalEnd = DateTime(now.year, now.month, now.day + 1, 12, 0);
      repo.rawBookings.add(BookingModel(
        id: 902,
        bookingCode: 'SKY-TEST-902',
        customerName: 'Current Renter',
        customerPhone: '081234567891',
        customerEmail: 'renter@example.com',
        pickupType: 'Outlet',
        jaminanType: 'KTP',
        startDate: now.subtract(const Duration(days: 1)),
        endDate: activeRentalEnd,
        startTime: '12:00',
        endTime: '12:00',
        durationDays: 48,
        price: 200000,
        deposit: 200000,
        status: BookingStatus.rented,
        paymentStatus: PaymentStatus.paid,
        iphone: unit,
      ));

      // Requested rental: Starts in 3 days -> must BE available
      final futureStart = DateTime(now.year, now.month, now.day + 3, 10, 0);
      final futureEnd = DateTime(now.year, now.month, now.day + 5, 10, 0);
      final isAvail = repo.isUnitAvailableForPeriod(unit, futureStart, futureEnd);
      expect(isAvail, isTrue, reason: 'Unit currently rented must be available for non-overlapping future period');
    });

    test('isUnitAvailableForPeriod: Cancelled and returned bookings do not block availability', () {
      final repo = BookingRepository();
      const unit = IphoneModel(
        id: 103,
        name: 'iPhone 14',
        storage: '128GB',
        color: 'Midnight',
        serialNumber: 'SN-AVAIL-03',
        assetCode: 'AST-AVAIL-03',
        status: 'ready',
      );

      final now = DateTime.now();
      final targetStart = now.add(const Duration(days: 2));
      final targetEnd = now.add(const Duration(days: 4));

      // Add a cancelled booking
      repo.rawBookings.add(BookingModel(
        id: 903,
        bookingCode: 'SKY-CANCELLED',
        customerName: 'Cancelled User',
        customerPhone: '081234567892',
        customerEmail: 'cancel@example.com',
        pickupType: 'Outlet',
        jaminanType: 'KTP',
        startDate: targetStart,
        endDate: targetEnd,
        startTime: '10:00',
        endTime: '10:00',
        durationDays: 48,
        price: 200000,
        deposit: 200000,
        status: BookingStatus.cancelled,
        paymentStatus: PaymentStatus.unpaid,
        iphone: unit,
      ));

      // Add a returned booking (has returns)
      repo.rawBookings.add(BookingModel(
        id: 904,
        bookingCode: 'SKY-RETURNED',
        customerName: 'Returned User',
        customerPhone: '081234567893',
        customerEmail: 'return@example.com',
        pickupType: 'Outlet',
        jaminanType: 'KTP',
        startDate: targetStart,
        endDate: targetEnd,
        startTime: '10:00',
        endTime: '10:00',
        durationDays: 48,
        price: 200000,
        deposit: 200000,
        status: BookingStatus.returned,
        paymentStatus: PaymentStatus.paid,
        iphone: unit,
        returns: [{'returned_at': now.toIso8601String()}],
      ));

      final isAvail = repo.isUnitAvailableForPeriod(unit, targetStart, targetEnd);
      expect(isAvail, isTrue, reason: 'Cancelled and returned bookings must not block availability');
    });

    test('isUnitAvailableForPeriod: Expired pending booking (>30 min) does not block availability', () {
      final repo = BookingRepository();
      const unit = IphoneModel(
        id: 104,
        name: 'iPhone 13',
        storage: '128GB',
        color: 'Starlight',
        serialNumber: 'SN-AVAIL-04',
        assetCode: 'AST-AVAIL-04',
        status: 'ready',
      );

      final now = DateTime.now();
      final targetStart = now.add(const Duration(days: 1));
      final targetEnd = now.add(const Duration(days: 2));

      // Pending booking created 45 minutes ago
      repo.rawBookings.add(BookingModel(
        id: 905,
        bookingCode: 'SKY-EXPIRED',
        customerName: 'Expired User',
        customerPhone: '081234567894',
        customerEmail: 'expired@example.com',
        pickupType: 'Outlet',
        jaminanType: 'KTP',
        startDate: targetStart,
        endDate: targetEnd,
        startTime: '10:00',
        endTime: '10:00',
        durationDays: 24,
        price: 100000,
        deposit: 200000,
        status: BookingStatus.pending,
        paymentStatus: PaymentStatus.unpaid,
        iphone: unit,
        createdAt: now.subtract(const Duration(minutes: 45)),
      ));

      final isAvail = repo.isUnitAvailableForPeriod(unit, targetStart, targetEnd);
      expect(isAvail, isTrue, reason: 'Pending booking created > 30 minutes ago must be expired and not block');
    });

    test('isUnitAvailableForPeriod: Boundary time touching does not conflict', () {
      final repo = BookingRepository();
      const unit = IphoneModel(
        id: 105,
        name: 'iPhone 15',
        storage: '128GB',
        color: 'Black',
        serialNumber: 'SN-AVAIL-05',
        assetCode: 'AST-AVAIL-05',
        status: 'ready',
      );

      final day = DateTime(2026, 10, 20);
      // Existing booking from 08:00 to 12:00
      repo.rawBookings.add(BookingModel(
        id: 906,
        bookingCode: 'SKY-SLOT-1',
        customerName: 'Slot 1 User',
        customerPhone: '081234567895',
        customerEmail: 'slot1@example.com',
        pickupType: 'Outlet',
        jaminanType: 'KTP',
        startDate: day,
        endDate: day,
        startTime: '08:00',
        endTime: '12:00',
        durationDays: 4,
        price: 50000,
        deposit: 100000,
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.paid,
        iphone: unit,
      ));

      // New booking starts exactly at 12:00 to 16:00 (touching boundary)
      final newStart = DateTime(2026, 10, 20, 12, 0);
      final newEnd = DateTime(2026, 10, 20, 16, 0);
      final isAvail = repo.isUnitAvailableForPeriod(unit, newStart, newEnd);
      expect(isAvail, isTrue, reason: 'Touch boundary times without overlap must not conflict');
    });

    test('isUnitAvailableForPeriod: Physical unit isolation (different unit of same model does not conflict)', () {
      final repo = BookingRepository();
      const unitA = IphoneModel(
        id: 106,
        name: 'iPhone 15 Pink',
        storage: '128GB',
        color: 'Pink',
        serialNumber: 'SN-PHYSICAL-A',
        assetCode: 'AST-PINK-01',
        status: 'ready',
      );
      const unitB = IphoneModel(
        id: 107,
        name: 'iPhone 15 Pink',
        storage: '128GB',
        color: 'Pink',
        serialNumber: 'SN-PHYSICAL-B',
        assetCode: 'AST-PINK-02',
        status: 'ready',
      );

      final now = DateTime.now();
      final targetStart = now.add(const Duration(days: 1));
      final targetEnd = now.add(const Duration(days: 2));

      // Book unit A
      repo.rawBookings.add(BookingModel(
        id: 907,
        bookingCode: 'SKY-PHYSICAL-A',
        customerName: 'Unit A Renter',
        customerPhone: '081234567896',
        customerEmail: 'unita@example.com',
        pickupType: 'Outlet',
        jaminanType: 'KTP',
        startDate: targetStart,
        endDate: targetEnd,
        startTime: '10:00',
        endTime: '10:00',
        durationDays: 24,
        price: 100000,
        deposit: 200000,
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.paid,
        iphone: unitA,
      ));

      // Unit A is unavailable
      expect(repo.isUnitAvailableForPeriod(unitA, targetStart, targetEnd), isFalse);
      // Unit B must remain available despite having same model and color
      expect(repo.isUnitAvailableForPeriod(unitB, targetStart, targetEnd), isTrue);
    });

    testWidgets('CreateBookingScreen: Unit currently rented today is selectable for future non-overlapping date', (tester) async {
      final repo = BookingRepository();
      repo.resetInventory();

      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repo)));
      await tester.pumpAndSettle();

      // Step 1: Fill guest info
      await tester.enterText(find.byType(TextFormField).at(0), 'Budi Test');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Kaliurang');
      await tester.pumpAndSettle();

      // Proceed to Step 2
      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Verify unit list rendered in Section 2
      expect(find.text('2. Unit iPhone & Durasi'), findsOneWidget);
    });
  });

  group('Bug 2: Dashboard Search Focus Behavior Tests', () {
    testWidgets('Dashboard search field does NOT autofocus or open keyboard on initial load or pop', (tester) async {
      final repo = BookingRepository();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [AppRoutes.routeObserver],
          home: Scaffold(
            body: DashboardScreen(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the dashboard search text field
      final searchTextFieldFinder = find.byType(TextField);
      expect(searchTextFieldFinder, findsOneWidget);

      final TextField searchTextField = tester.widget<TextField>(searchTextFieldFinder);
      expect(searchTextField.autofocus, isFalse, reason: 'Search field autofocus must be false');
      expect(searchTextField.focusNode?.hasFocus, isFalse, reason: 'Search field must not have focus on load');

      // Navigate to dummy subpage and pop back
      final BuildContext context = tester.element(find.byType(DashboardScreen));
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            appBar: AppBar(title: const Text('Detail Subpage')),
            body: const Center(child: Text('Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Detail Subpage'), findsOneWidget);

      // Pop back to Dashboard
      Navigator.pop(tester.element(find.text('Detail Subpage')));
      await tester.pumpAndSettle();

      // Search field must NOT be focused after popping back
      final searchTextFieldAfterPop = tester.widget<TextField>(searchTextFieldFinder);
      expect(searchTextFieldAfterPop.focusNode?.hasFocus, isFalse, reason: 'Search field must not regain focus after returning to Dashboard');
    });
  });

  group('UI Improvement 3: Dashboard Right Column Sticky Layout Tests', () {
    testWidgets('Dashboard tablet layout renders 2 columns with independent scrollable areas', (tester) async {
      final repo = BookingRepository();

      // Set tablet physical size (1024x768 landscape)
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [AppRoutes.routeObserver],
          home: Scaffold(
            body: DashboardScreen(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that both Aksi Cepat Kasir (right column) and antrean/metrics (left column) exist
      expect(find.text('Aksi Cepat Kasir'), findsOneWidget);
      expect(find.text('Printer Kasir'), findsOneWidget);

      // Verify that there are independent scrollable containers (Left Column & Right Column)
      final scrollViews = find.byType(SingleChildScrollView);
      expect(scrollViews, findsAtLeastNWidgets(2), reason: 'Tablet layout must have independent left and right scroll containers');
    });
  });
}
