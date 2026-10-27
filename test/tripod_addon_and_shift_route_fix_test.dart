import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 2: Add-on Device (Tripod) Classification and Visibility', () {
    test('Tripod JSON without is_addon field is accurately classified as isAddon = true', () {
      // Exact payload structure returned by backend for newly created Tripod
      final tripodJson = {
        'id': 82,
        'asset_code': 'ADDON1310',
        'affiliate_id': null,
        'status': 'ready',
        'name': 'tripod',
        'gallery_id': 62,
        'serial_number': 'ACC1A17CAEBEC0',
        'slug': 'tripod',
        'is_booked': 0,
      };

      final tripodModel = IphoneModel.fromJson(tripodJson);

      expect(tripodModel.isAddon, isTrue,
          reason: 'Devices with asset_code starting with ADDON or serial starting with ACC must be classified as add-ons');
      expect(tripodModel.name, 'tripod');
      expect(tripodModel.assetCode, 'ADDON1310');
      expect(tripodModel.serialNumber, 'ACC1A17CAEBEC0');
    });

    test('Regular iPhone is not mistakenly classified as an add-on', () {
      final iphoneJson = {
        'id': 15,
        'asset_code': 'IPHSKY2024',
        'affiliate_id': 4,
        'status': 'ready',
        'name': 'iPhone 15 Pro',
        'gallery_id': 10,
        'serial_number': 'DX987654321',
      };

      final iphoneModel = IphoneModel.fromJson(iphoneJson);

      expect(iphoneModel.isAddon, isFalse);
    });

    test('BookingRepository.getAvailableAddonUnits returns Tripod even when cashier has branch scope', () async {
      final repository = BookingRepository();

      // Set cashier with branch scope (affiliateId: 4)
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

      final tripodUnit = IphoneModel(
        id: 82,
        name: 'tripod',
        storage: '',
        color: 'Hitam',
        serialNumber: 'ACC1A17CAEBEC0',
        assetCode: 'ADDON1310',
        status: 'ready',
        affiliateId: null, // Unassigned / central inventory
        isAddon: true,
        durations: const [
          IphoneDurationOption(id: 1, name: '24 Jam', hours: 24, price: 25000),
        ],
      );

      repository.setTestInventory([tripodUnit]);

      final addons = await repository.getAvailableAddonUnits();

      expect(addons, isNotEmpty);
      expect(addons.any((a) => a.id == 82 && a.name == 'tripod'), isTrue,
          reason: 'Unassigned add-ons (affiliateId == null) must remain available for all scoped branches');
    });

    testWidgets('New Booking Section 2 displays Tripod in Additional Items area', (tester) async {
      final repository = BookingRepository();

      AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());

      final primaryIphone = const IphoneModel(
        id: 101,
        name: 'iPhone 15 Pro',
        storage: '128 GB',
        color: 'Natural Titanium',
        serialNumber: 'DX101',
        assetCode: 'IPH-101',
        status: 'ready',
        affiliateId: 4,
        isAddon: false,
        durations: [
          IphoneDurationOption(id: 1, name: '24 Jam', hours: 24, price: 150000),
        ],
      );

      final tripodUnit = const IphoneModel(
        id: 82,
        name: 'tripod',
        storage: '',
        color: 'Standar',
        serialNumber: 'ACC1A17CAEBEC0',
        assetCode: 'ADDON1310',
        status: 'ready',
        affiliateId: null,
        isAddon: true,
        durations: [
          IphoneDurationOption(id: 1, name: '24 Jam', hours: 24, price: 25000),
        ],
      );

      repository.setTestInventory([primaryIphone, tripodUnit]);

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateBookingScreen(
              repository: repository,
              initialIphone: primaryIphone,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Fill Step 1 Form
      await tester.enterText(find.byType(TextFormField).at(0), 'Budi Santoso');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Gatot Subroto No. 5');
      await tester.pumpAndSettle();

      // Advance to Step 2
      final nextBtn = find.byKey(const Key('btn_next_to_step_2'));
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Find Section 2: Item Tambahan / Add-on
      expect(find.text('Item Tambahan / Add-on (Opsional)'), findsWidgets);

      // Verify Tripod is displayed in Section 2 list
      final tripodTile = find.byKey(const Key('addon_tile_82'));
      expect(tripodTile, findsOneWidget, reason: 'Tripod tile must be present in Section 2 add-on list');
      expect(find.text('tripod'), findsWidgets);
      expect(find.textContaining('ADDON1310'), findsWidgets);

      // Select Tripod checkbox and verify
      await tester.ensureVisible(tripodTile);
      await tester.pumpAndSettle();
      await tester.tap(tripodTile);
      await tester.pumpAndSettle();

      final tripodCheckbox = tester.widget<Checkbox>(find.byKey(const Key('addon_checkbox_82')));
      expect(tripodCheckbox.value, isTrue);
    });
  });

  group('Issue 1: Shift Opening Routing Fault Tolerance', () {
    test('BookingRepository.openShift gracefully handles remote 404 without crashing', () async {
      final repository = BookingRepository();

      AuthService().setCurrentUserForTest(
        const AdminUserModel(
          id: 2,
          name: 'Kasir Shift',
          email: 'kasir2@skyrent.id',
          phone: '081234567891',
          outletName: 'Genteng Pusat',
          shiftName: 'Shift Pagi',
          role: 'Staff Kasir',
          affiliateId: 4,
          roles: ['staff'],
        ),
      );

      MockBookingData.resetShifts();

      // Opening shift must return an active open shift session even if remote backend returns 404
      final shift = await repository.openShift(
        openingCashFloat: 150000,
        notes: 'Uang modal awal shift pagi',
      );

      expect(shift, isNotNull);
      expect(shift.isOpen, isTrue);
      expect(shift.openingCashFloat, 150000);
      expect(shift.shiftNumber, isNotEmpty);
      expect(repository.activeShift?.isOpen, isTrue);
    });
  });
}
