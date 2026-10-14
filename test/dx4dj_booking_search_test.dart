import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  const dx4djUnit = IphoneModel(
    id: 32,
    name: 'iPhone XR Putih',
    storage: '64GB',
    color: 'Putih',
    serialNumber: 'DX4DJ9E6KXKN',
    assetCode: 'IP-XR-032',
    status: 'ready',
    affiliateId: 4,
    branchName: 'Genteng Pusat',
    isAvailable: true,
  );

  group('DX4DJ Scoping & Booking Search Tests', () {
    test('Role Scoping: Super-admin & Admin are global, Affiliate-admin is scoped', () {
      final auth = AuthService();

      // 1. Super-admin at Genteng (affiliateId: 4)
      auth.setCurrentUserForTest(const AdminUserModel(
        id: 1,
        name: 'Skyrental Pusat',
        email: 'super-admin@example.com',
        phone: '081234567890',
        role: 'super-admin',
        outletName: 'Genteng Pusat',
        shiftName: 'Shift 1',
        affiliateId: 4,
        roles: ['super-admin'],
      ));
      expect(auth.isSuperAdmin, isTrue);
      expect(auth.isAffiliateScoped, isFalse);

      // 2. Admin at Genteng (affiliateId: 4)
      auth.setCurrentUserForTest(const AdminUserModel(
        id: 2,
        name: 'admin',
        email: 'admin@skyrental.id',
        phone: '081234567891',
        role: 'admin',
        outletName: 'Genteng Pusat',
        shiftName: 'Shift 1',
        affiliateId: 4,
        roles: ['admin'],
      ));
      expect(auth.isSuperAdmin, isFalse);
      expect(auth.isAdmin, isTrue);
      expect(auth.isAffiliateAdmin, isFalse);
      expect(auth.isAffiliateScoped, isFalse);

      // 3. Affiliate-admin at Purwoharjo (affiliateId: 2)
      auth.setCurrentUserForTest(const AdminUserModel(
        id: 3,
        name: 'Siva',
        email: 'zhrsivaa@gmail.com',
        phone: '081234567892',
        role: 'affiliate-admin',
        outletName: 'Affiliate Purwoharjo',
        shiftName: 'Shift 1',
        affiliateId: 2,
        roles: ['affiliate-admin'],
      ));
      expect(auth.isSuperAdmin, isFalse);
      expect(auth.isAffiliateAdmin, isTrue);
      expect(auth.isAffiliateScoped, isTrue);
      expect(auth.affiliateId, equals(2));
    });

    test('IphoneModel.fromJson parses is_available correctly', () {
      final jsonAvailable = {
        'id': 32,
        'name': 'iPhone XR Putih',
        'serial_number': 'DX4DJ9E6KXKN',
        'status': 'ready',
        'is_available': true,
        'affiliate_id': 4,
      };
      final unit1 = IphoneModel.fromJson(jsonAvailable);
      expect(unit1.isAvailable, isTrue);
      expect(unit1.affiliateId, equals(4));

      final jsonUnavailable = {
        'id': 32,
        'name': 'iPhone XR Putih',
        'serial_number': 'DX4DJ9E6KXKN',
        'status': 'ready',
        'is_available': false,
        'affiliate_id': 4,
      };
      final unit2 = IphoneModel.fromJson(jsonUnavailable);
      expect(unit2.isAvailable, isFalse);
    });

    testWidgets('DX4DJ appears and is selectable in CreateBookingScreen Section 2 for Admin at Genteng', (tester) async {
      AuthService().setCurrentUserForTest(const AdminUserModel(
        id: 2,
        name: 'admin',
        email: 'admin@skyrental.id',
        phone: '081234567891',
        role: 'admin',
        outletName: 'Genteng Pusat',
        shiftName: 'Shift 1',
        affiliateId: 4,
        roles: ['admin'],
      ));

      final repository = BookingRepository();
      repository.resetInventory();
      // Inject DX4DJ into inventory for test
      repository.inventory.add(dx4djUnit);

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repository)));
      await tester.pumpAndSettle();

      // Fill Step 1
      await tester.enterText(find.byType(TextFormField).at(0), 'Pelanggan Genteng');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Genteng Pusat');
      await tester.pumpAndSettle();

      // Go to Section 2
      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Search DX4DJ
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'DX4DJ');
      await tester.pumpAndSettle();

      // Verify DX4DJ is rendered
      expect(find.textContaining('DX4DJ9E6KXKN'), findsOneWidget);
      expect(find.text('iPhone tidak ditemukan'), findsNothing);

      // Tap on unit to select it
      await tester.tap(find.textContaining('DX4DJ9E6KXKN'));
      await tester.pumpAndSettle();

      // Verify it is selected
      expect(find.text('Terpilih'), findsOneWidget);
    });

    testWidgets('DX4DJ is excluded for Affiliate Purwoharjo (affiliateId: 2) since unit belongs to Genteng (affiliateId: 4)', (tester) async {
      AuthService().setCurrentUserForTest(const AdminUserModel(
        id: 3,
        name: 'Siva',
        email: 'zhrsivaa@gmail.com',
        phone: '081234567892',
        role: 'affiliate-admin',
        outletName: 'Affiliate Purwoharjo',
        shiftName: 'Shift 1',
        affiliateId: 2,
        roles: ['affiliate-admin'],
      ));

      final repository = BookingRepository();
      repository.resetInventory();
      repository.inventory.add(dx4djUnit);

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repository)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Pelanggan Purwoharjo');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Purwoharjo');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Search DX4DJ
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'DX4DJ');
      await tester.pumpAndSettle();

      // Since unit belongs to affiliate 4, affiliate 2 must NOT see it
      expect(find.textContaining('DX4DJ9E6KXKN'), findsNothing);
    });
  });
}
