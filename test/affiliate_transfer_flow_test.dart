import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
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
  });
}
