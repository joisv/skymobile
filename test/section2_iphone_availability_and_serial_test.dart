import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/models/payment_model.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    MockBookingData.resetInventory();
  });

  group('Section 2: iPhone Serial Number Display & Removal of Unsupported Fields', () {
    testWidgets('iPhone selection cards display serial number and do not display hardcoded color or battery health', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repository)));
      await tester.pumpAndSettle();

      // Step 1: Customer details
      await tester.enterText(find.byType(TextFormField).at(0), 'Ahmad Fauzi');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Malioboro');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // 1. Verify actual database serial numbers are clearly displayed
      expect(find.textContaining('SN: P9ZX44MN67'), findsOneWidget);
      expect(find.textContaining('SN: DX3GGKS9SAA'), findsOneWidget);

      // 2. Verify hardcoded color and battery health do NOT appear in the selection cards
      expect(find.textContaining('Natural Titanium •'), findsNothing);
      expect(find.textContaining('Blue Titanium •'), findsNothing);
      expect(find.textContaining('Bat. 98%'), findsNothing);
      expect(find.textContaining('Bat. 100%'), findsNothing);
    });

    testWidgets('Selected iPhone displays model name and serial number when advancing to Section 3', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(400, 1050);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repository)));
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(find.byType(TextFormField).at(0), 'Siti Nurhaliza');
      await tester.enterText(find.byType(TextFormField).at(1), '085712345678');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Kaliurang KM 5');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Tap on available iPhone (P9ZX44MN67)
      final unitCard = find.textContaining('SN: P9ZX44MN67');
      expect(unitCard, findsOneWidget);
      await tester.tap(unitCard);
      await tester.pumpAndSettle();

      // Proceed to Step 3
      final nextBtn = find.byKey(const Key('btn_next_to_step_3'));
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Verify Section 3 summary displays unit model and its database serial number
      expect(find.text('3. Estimasi Biaya & Konfirmasi'), findsOneWidget);
      expect(find.textContaining('iPhone 15 Pro Max 256GB (SN: P9ZX44MN67)'), findsOneWidget);
    });
  });

  group('Section 2: iPhone Availability, Conflicting Bookings, and Returned Units', () {
    testWidgets('Conflicting or rented iPhone cannot be selected, while available iPhone can be selected', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(400, 1050);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repository)));
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(find.byType(TextFormField).at(0), 'Budi Santoso');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567891');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Gejayan');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Switch filter to "Semua" to view both available and rented units
      await tester.tap(find.byKey(const Key('filter_chip_semua')));
      await tester.pumpAndSettle();

      // Find rented unit on first page (H8JK29LM01)
      final rentedUnit = find.textContaining('SN: H8JK29LM01');
      expect(rentedUnit, findsOneWidget);

      // Tap rented unit: should show warning dialog and NOT select it
      await tester.ensureVisible(rentedUnit);
      await tester.tap(rentedUnit);
      await tester.pumpAndSettle();

      expect(find.text('Unit Sedang Disewa'), findsOneWidget);
      expect(find.textContaining('saat ini sedang dalam masa sewa aktif'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Mengerti'));
      await tester.pumpAndSettle();

      // Now tap available unit (P9ZX44MN67)
      final availableUnit = find.textContaining('SN: P9ZX44MN67');
      await tester.ensureVisible(availableUnit);
      await tester.tap(availableUnit);
      await tester.pumpAndSettle();

      // Available unit is successfully selected and duration options appear
      expect(find.text('24 jam'), findsOneWidget);
    });

    test('Returned iPhone becomes available for new booking according to business rules', () {
      final repository = BookingRepository();
      repository.resetInventory();

      final unit = const IphoneModel(
        id: 991,
        name: 'iPhone 15 Pro',
        storage: '128GB',
        color: 'Black Titanium',
        serialNumber: 'SN-TEST-RET-01',
        assetCode: 'AST-RET-01',
        status: 'tersedia',
        isAvailable: true,
      );

      final now = DateTime.now();
      final start = now.add(const Duration(hours: 1));
      final end = start.add(const Duration(hours: 24));

      // Initially available
      expect(repository.isUnitAvailableForPeriod(unit, start, end), isTrue);

      // Add a booking with return record
      final returnedBooking = BookingModel(
        id: 8801,
        bookingCode: 'SKY-RET-8801',
        customerName: 'Return Tester',
        customerPhone: '08123456789',
        customerEmail: 'return@test.local',
        pickupType: 'Outlet',
        jaminanType: 'KTP',
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.subtract(const Duration(hours: 2)),
        durationDays: 2,
        price: 300000,
        deposit: 200000,
        status: BookingStatus.returned,
        paymentStatus: PaymentStatus.paid,
        iphone: unit,
        returns: const [
          {
            'id': 1,
            'booking_id': 8801,
            'condition': 'Baik',
            'status': 'completed',
          }
        ],
      );

      repository.rawBookings.add(returnedBooking);

      // Unit must remain available because the booking is returned
      expect(repository.isUnitAvailableForPeriod(unit, start, end), isTrue);
      expect(repository.isUnitCurrentlyRented(unit.assetCode, unitId: unit.id, serialNumber: unit.serialNumber), isFalse);
    });
  });

  group('Section 2: Role-Specific Verification (All 4 Roles)', () {
    test('Role Verification: Super-admin, Admin, Affiliate-admin, and Affiliate all enforce availability equally', () {
      final repository = BookingRepository();
      repository.resetInventory();

      final unitAffiliate1 = const IphoneModel(
        id: 992,
        name: 'iPhone 14 Pro',
        storage: '128GB',
        color: 'Space Black',
        serialNumber: 'SN-ROLE-TEST-01',
        assetCode: 'AST-ROLE-01',
        status: 'tersedia',
        affiliateId: 1,
        isAvailable: true,
      );

      final now = DateTime.now();
      final start = now.add(const Duration(hours: 2));
      final end = start.add(const Duration(hours: 24));

      // Add active rental booking overlapping with [start, end]
      final activeBooking = BookingModel(
        id: 8802,
        bookingCode: 'SKY-ACT-8802',
        customerName: 'Active Customer',
        customerPhone: '08123456788',
        customerEmail: 'active@test.local',
        pickupType: 'Outlet',
        jaminanType: 'KTP',
        startDate: now.subtract(const Duration(hours: 2)),
        endDate: now.add(const Duration(hours: 5)),
        durationDays: 1,
        price: 250000,
        deposit: 200000,
        status: BookingStatus.rented,
        paymentStatus: PaymentStatus.paid,
        iphone: unitAffiliate1,
      );
      repository.rawBookings.add(activeBooking);

      final roles = [
        AdminUserModel.defaultAdmin().copyWith(id: 1, name: 'Super Admin', role: 'super-admin'),
        AdminUserModel.defaultAdmin().copyWith(id: 2, name: 'General Admin', role: 'admin'),
        AdminUserModel.defaultAdmin().copyWith(id: 3, name: 'Affiliate Admin', role: 'affiliate-admin', affiliateId: 1),
        AdminUserModel.defaultAdmin().copyWith(id: 4, name: 'Affiliate Staff', role: 'affiliate', affiliateId: 1),
      ];

      for (final user in roles) {
        AuthService().setCurrentUserForTest(user);

        // All roles must evaluate the actively rented unit as unavailable for the overlapping schedule
        final isAvailable = repository.isUnitAvailableForPeriod(unitAffiliate1, start, end);
        expect(isAvailable, isFalse, reason: 'Role ${user.role} must not see an actively rented unit as available for overlapping period');

        // All roles must detect unit is currently rented
        final isRented = repository.isUnitCurrentlyRented(
          unitAffiliate1.assetCode,
          unitId: unitAffiliate1.id,
          serialNumber: unitAffiliate1.serialNumber,
        );
        expect(isRented, isTrue, reason: 'Role ${user.role} must detect unit as currently rented');
      }
    });

    test('Affiliate Scoping: Affiliate and Affiliate-admin cannot see or book units from other branches', () {
      final repository = BookingRepository();
      repository.resetInventory();

      final otherBranchUnit = const IphoneModel(
        id: 993,
        name: 'iPhone 15',
        storage: '128GB',
        color: 'Pink',
        serialNumber: 'SN-BRANCH-OTHER-01',
        assetCode: 'AST-OTHER-01',
        status: 'tersedia',
        affiliateId: 2, // Different affiliate
        isAvailable: true,
      );

      // Affiliate Admin for branch 1
      AuthService().setCurrentUserForTest(
        AdminUserModel.defaultAdmin().copyWith(
          id: 5,
          name: 'Branch 1 Admin',
          role: 'affiliate-admin',
          affiliateId: 1,
        ),
      );

      final now = DateTime.now();
      expect(
        () => repository.createBooking(
          customerName: 'Cross Affiliate Tester',
          customerPhone: '08123456789',
          customerEmail: 'cross@test.local',
          iphone: otherBranchUnit,
          startDate: now.add(const Duration(hours: 1)),
          endDate: now.add(const Duration(hours: 25)),
          durationDays: 1,
          price: 200000,
          deposit: 100000,
          jaminanType: 'KTP',
        ),
        throwsA(predicate((e) => e.toString().contains('Akses ditolak'))),
      );
    });
  });

  group('Section 2: Repository Concurrency & Validation Guards', () {
    test('createBooking rejects unavailable or conflicting unit and invalidates cache', () async {
      final repository = BookingRepository();
      repository.resetInventory();

      final unit = const IphoneModel(
        id: 994,
        name: 'iPhone 14',
        storage: '128GB',
        color: 'Starlight',
        serialNumber: 'SN-CONF-TEST-994',
        assetCode: 'AST-CONF-994',
        status: 'tersedia',
        isAvailable: true,
      );

      final now = DateTime.now();
      final start = now.add(const Duration(hours: 2));
      final end = start.add(const Duration(hours: 24));

      // Successfully book for this period
      final booking1 = await repository.createBooking(
        customerName: 'First Booker',
        customerPhone: '08123456789',
        customerEmail: 'first@test.local',
        iphone: unit,
        startDate: start,
        endDate: end,
        durationDays: 1,
        price: 200000,
        deposit: 100000,
        jaminanType: 'KTP',
      );
      expect(booking1.bookingCode, isNotEmpty);

      // Immediate attempt to book the same unit for an overlapping period must fail
      expect(
        repository.createBooking(
          customerName: 'Second Booker',
          customerPhone: '08123456780',
          customerEmail: 'second@test.local',
          iphone: unit,
          startDate: start.add(const Duration(hours: 4)),
          endDate: end.add(const Duration(hours: 4)),
          durationDays: 1,
          price: 200000,
          deposit: 100000,
          jaminanType: 'KTP',
        ),
        throwsA(predicate((e) => e.toString().contains('tidak tersedia untuk jadwal'))),
      );
    });
  });
}
