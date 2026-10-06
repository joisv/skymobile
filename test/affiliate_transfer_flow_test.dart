import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/affiliate_model.dart';
import 'package:skyrental_admin/models/iphone_transfer_model.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/screens/affiliate/iphone_transfer_list_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('IphoneTransferModel Unit Tests', () {
    test('parses UUID sent_by and received_by properly without crashing', () {
      final json = {
        'id': 15,
        'iphone_id': 102,
        'iphone_name': 'iPhone 15 Pro 128GB',
        'iphone_serial': 'SN-IPH15P-001',
        'iphone_color': 'Blue Titanium',
        'from_affiliate_id': 1,
        'from_affiliate_name': 'Affiliate Pusat',
        'from_affiliate_code': 'PST',
        'to_affiliate_id': 7,
        'to_affiliate_name': 'Affiliate Purwoharjo',
        'to_affiliate_code': 'PWJ',
        'sent_by': '01a0f739-b876-717b-aeb6-32f9cbc84395',
        'sender_name': 'Super Admin',
        'received_by': '01a0f739-9999-717b-aeb6-111111111111',
        'receiver_name': 'Admin Purwoharjo',
        'status': 'in_transit',
        'notes': 'Unit baru cabang Purwoharjo',
        'sent_at': '2026-10-01T10:00:00Z',
      };

      final model = IphoneTransferModel.fromJson(json);

      expect(model.id, 15);
      expect(model.iphoneId, 102);
      expect(model.sentBy, '01a0f739-b876-717b-aeb6-32f9cbc84395');
      expect(model.receivedBy, '01a0f739-9999-717b-aeb6-111111111111');
      expect(model.isInTransit, isTrue);
      expect(model.isReceived, isFalse);
      expect(model.statusLabel, 'Dalam Pengiriman');
    });
  });

  group('BookingRepository Accept Transfer Tests', () {
    test('acceptIphoneTransfer updates transfer status and updates unit in inventory to tersedia', () async {
      final repository = BookingRepository();

      // Ensure mock inventory loaded
      final units = await repository.getAllInventoryUnits();
      final targetUnit = units.first;

      // Create a transfer for this unit
      final transfer = await repository.createIphoneTransfer(
        iphoneId: targetUnit.id,
        toAffiliateId: 7,
        notes: 'Transfer testing',
      );

      expect(transfer.isInTransit, isTrue);

      // Accept the transfer
      final accepted = await repository.acceptIphoneTransfer(transfer.id);

      expect(accepted.isReceived, isTrue);
      expect(accepted.status, 'received');

      // Verify unit in repository inventory is now updated to tersedia
      final updatedUnit = repository.inventory.firstWhere((u) => u.id == targetUnit.id);
      expect(updatedUnit.status.toLowerCase(), 'tersedia');
      expect(updatedUnit.affiliateId, 7);
    });
  });

  group('IphoneTransferListScreen for affiliate-admin', () {
    testWidgets('renders Transfer iPhone Masuk title and hides create transfer FAB', (WidgetTester tester) async {
      final repository = BookingRepository();

      // Set current user as affiliate-admin (Affiliate ID 7)
      AuthService().setCurrentUserForTest(
        const AdminUserModel(
          id: 77,
          name: 'Admin Purwoharjo',
          email: 'testmobile@gmail.com',
          phone: '+628123456789',
          role: 'affiliate-admin',
          affiliateId: 7,
          outletName: 'Cabang Purwoharjo',
          shiftName: 'Shift Reguler',
          isActive: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
          home: IphoneTransferListScreen(
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify screen title for affiliate-admin
      expect(find.text('Transfer iPhone Masuk'), findsOneWidget);

      // Verify tabs
      expect(find.textContaining('Semua'), findsWidgets);
      expect(find.textContaining('Dalam Pengiriman'), findsWidgets);
      expect(find.textContaining('Diterima'), findsWidgets);

      // Verify FAB Kirim Unit iPhone is NOT displayed for affiliate-admin
      expect(find.text('Kirim Unit iPhone'), findsNothing);
    });

    testWidgets('super-admin can open transfer sheet, search and select iPhone unit, and view transfer overview', (WidgetTester tester) async {
      final repository = BookingRepository();
      await repository.getAllInventoryUnits();
      await repository.createAffiliate(const AffiliateModel(
        id: 1,
        code: 'PST',
        name: 'Genteng Pusat',
        slug: 'genteng-pusat',
        city: 'Genteng',
      ));
      await repository.createAffiliate(const AffiliateModel(
        id: 2,
        code: 'SLR',
        name: 'Cabang Siliragung',
        slug: 'cabang-siliragung',
        city: 'Siliragung',
      ));
      await repository.getAffiliates();

      // Set current user as super-admin
      AuthService().setCurrentUserForTest(
        const AdminUserModel(
          id: 1,
          name: 'Super Admin',
          email: 'admin@skyrent.id',
          phone: '+628123456789',
          role: 'super-admin',
          outletName: 'Pusat SkyRent',
          shiftName: 'Shift Reguler',
          isActive: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
          home: IphoneTransferListScreen(
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Super-admin sees FAB
      expect(find.text('Kirim Unit iPhone'), findsOneWidget);

      // Tap FAB Kirim Unit iPhone
      await tester.tap(find.text('Kirim Unit iPhone'));
      await tester.pumpAndSettle();

      // Verify bottom sheet appears
      expect(find.text('Kirim & Mutasi iPhone'), findsOneWidget);
      expect(find.text('Pilih Unit iPhone...'), findsOneWidget);

      // Tap to open scalable searchable iPhone picker modal
      await tester.tap(find.text('Pilih Unit iPhone...'));
      await tester.pumpAndSettle();

      // Verify searchable picker modal opened
      expect(find.text('Pilih Unit iPhone'), findsWidgets);
      final searchField = find.widgetWithText(TextField, 'Cari tipe, nomor seri/aset, warna...');
      expect(searchField, findsOneWidget);

      // Search for specific model in search bar
      await tester.enterText(searchField, '15');
      await tester.pumpAndSettle();

      // Pick matching unit card
      final unitCard = find.widgetWithText(InkWell, 'iPhone 15 Pro').first;
      await tester.tap(unitCard);
      await tester.pumpAndSettle();

      // Picker is dismissed, unit is selected in the transfer bottom sheet
      expect(find.text('Ganti'), findsOneWidget);
      expect(find.text('Asal Unit: '), findsOneWidget);

      // Scroll bottom sheet to bring destination dropdown into view
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -250));
      await tester.pumpAndSettle();

      // Tap destination dropdown
      final dropdownFinder = find.byType(DropdownButtonFormField<int>);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Pick destination option in dropdown
      final itemFinder = find.byType(DropdownMenuItem<int>);
      expect(itemFinder, findsWidgets);
      await tester.tap(itemFinder.first);
      await tester.pumpAndSettle();

      // Verify transfer route preview card is rendered
      expect(find.text('Alur Mutasi Pengiriman'), findsOneWidget);
      expect(find.text('ASAL'), findsOneWidget);
      expect(find.text('TUJUAN'), findsOneWidget);

      // Scroll to submit button and tap
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('Kirim Sekarang'), findsOneWidget);
      await tester.tap(find.text('Kirim Sekarang'));
      await tester.pumpAndSettle();

      // Verify bottom sheet is dismissed and transfer completed
      expect(find.text('Kirim & Mutasi iPhone'), findsNothing);
    });
  });

  group('Role affiliate Authorization and Transfer Access Tests', () {
    test('Role affiliate has correct permissions and route guards', () {
      final auth = AuthService();
      auth.setCurrentUserForTest(
        const AdminUserModel(
          id: 55,
          name: 'Affiliate Worker',
          email: 'affiliate@skyrent.id',
          phone: '+628123456789',
          role: 'affiliate',
          affiliateId: 7,
          outletName: 'Cabang Purwoharjo',
          shiftName: 'Shift Reguler',
          isActive: true,
        ),
      );

      // Check role getters
      expect(auth.isAffiliate, isTrue);
      expect(auth.isAffiliateAdmin, isTrue);
      expect(auth.isSuperAdmin, isFalse);

      // Can access transfer routes
      expect(auth.canAccessRoute(AppRoutes.iphoneTransfer), isTrue);
      expect(auth.canAccessRoute(AppRoutes.affiliateTransferIphone), isTrue);

      // CANNOT access Super Admin only routes
      expect(auth.canAccessRoute(AppRoutes.affiliateList), isFalse);
      expect(auth.canAccessRoute(AppRoutes.rolesPermissions), isFalse);
      expect(auth.canAccessRoute('/users'), isFalse);
    });

    testWidgets('AppRoutes.onGenerateRoute allows affiliate to access transfer routes without access denied', (WidgetTester tester) async {
      final repository = BookingRepository();
      final auth = AuthService();
      auth.setCurrentUserForTest(
        const AdminUserModel(
          id: 55,
          name: 'Affiliate Worker',
          email: 'affiliate@skyrent.id',
          phone: '+628123456789',
          role: 'affiliate',
          affiliateId: 7,
          outletName: 'Cabang Purwoharjo',
          shiftName: 'Shift Reguler',
          isActive: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository, authService: auth),
          initialRoute: AppRoutes.iphoneTransfer,
        ),
      );
      await tester.pumpAndSettle();

      // Does not show access denied
      expect(find.textContaining('Akses ditolak'), findsNothing);
      // Renders the transfer screen
      expect(find.text('Transfer iPhone Masuk'), findsOneWidget);
    });

    testWidgets('Empty state for role affiliate displays proper empty message', (WidgetTester tester) async {
      final repository = BookingRepository();
      final auth = AuthService();
      auth.setCurrentUserForTest(
        const AdminUserModel(
          id: 99,
          name: 'Affiliate Baru',
          email: 'affiliate99@skyrent.id',
          phone: '+628123456789',
          role: 'affiliate',
          affiliateId: 999, // No transfers for affiliate 999
          outletName: 'Cabang Baru',
          shiftName: 'Shift Reguler',
          isActive: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository, authService: auth),
          home: IphoneTransferListScreen(
            repository: repository,
            initialAffiliateId: 999,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify custom empty state for affiliate
      expect(find.text('Belum ada transfer iPhone masuk.'), findsOneWidget);
      expect(find.text('Unit iPhone yang dikirim ke cabang Anda akan muncul di sini.'), findsOneWidget);
      expect(find.text('Tidak Ada Riwayat Transfer'), findsNothing);
      expect(find.text('Kirim Unit iPhone'), findsNothing);
    });
  });
}


