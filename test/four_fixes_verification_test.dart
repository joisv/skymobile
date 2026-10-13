import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/receipt_format_settings.dart';
import 'package:skyrental_admin/models/receipt_model.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/screens/booking/booking_detail_screen.dart';
import 'package:skyrental_admin/screens/dashboard/dashboard_screen.dart';
import 'package:skyrental_admin/screens/main_navigation_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/services/printer_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    await PrinterStorageService().init();
  });

  group('Issue 1: Bottom Navigation Remains Visible When Opening Settings from Booking Details', () {
    testWidgets('Tapping Settings from Booking Details preserves bottom navigation bar and selects Settings tab',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = BookingRepository();
      final baseBooking = (await repository.getBookings()).first;
      final sampleBooking = baseBooking.copyWith(
        iphone: baseBooking.iphone.copyWith(photoUrl: ''),
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
          home: BookingDetailScreen(
            booking: sampleBooking,
            repository: repository,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // 1. In Booking Details tablet bottom nav, Settings item exists
      final settingsNavItem = find.text('Settings');
      expect(settingsNavItem, findsOneWidget);

      // 2. Tap Settings nav item in Booking Details bottom nav
      await tester.tap(settingsNavItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Verify that MainNavigationScreen is displayed with bottom navigation visible
      expect(find.byType(MainNavigationScreen), findsOneWidget);

      // Verify bottom nav items remain visible on Settings screen
      final mainNav = find.byType(MainNavigationScreen);
      expect(find.descendant(of: mainNav, matching: find.text('Dashboard')), findsOneWidget);
      expect(find.descendant(of: mainNav, matching: find.text('Report')), findsOneWidget);
      expect(find.descendant(of: mainNav, matching: find.text('Unit iPhone')), findsOneWidget);
      expect(find.descendant(of: mainNav, matching: find.text('Settings')), findsOneWidget);

      // Wait for AccountScreen init to complete
      for (int i = 0; i < 20; i++) {
        if (find.byTooltip('Kembali').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 4. Verify back button in header allows popping back to Booking Details
      final backButton = find.byTooltip('Kembali');
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Successfully returned to Booking Details
      expect(find.byType(BookingDetailScreen), findsOneWidget);
    });
  });

  group('Issue 2: Improved Receipt Layout in Echo Mode', () {
    test('Echo mode produces fields in required order with visual separator and duration units', () {
      final receipt = ReceiptModel(
        receiptNumber: 'STR-SKY-901',
        date: DateTime(2026, 10, 15, 14, 30),
        adminName: 'Admin Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.pickup,
        bookingCode: 'SKY260910A1B2',
        customerName: 'Budi Santoso',
        customerPhone: '081234567890',
        unitName: 'iPhone 15 Pro 256GB',
        rentalDuration: '2 Hari',
        rentFee: 400000,
        depositFee: 200000,
        totalAmount: 600000,
        paidAmount: 600000,
        remainingAmount: 0,
        paymentMethod: 'QRIS',
        paymentStatus: 'Lunas',
      );

      final echoSettings = ReceiptFormatSettings.compactSettings();
      final text = receipt.toEscPos58mm(formatSettings: echoSettings);
      final lines = text.split('\n');

      // 1. Line width must not exceed 32 characters (excluding typography tag)
      for (final line in lines) {
        if (!line.startsWith('[STORE_NAME:') && !line.startsWith('[BARCODE:')) {
          expect(line.length, lessThanOrEqualTo(32), reason: 'Line too long: "$line" (${line.length})');
        }
      }

      // Check required field order
      final noStrukIdx = lines.indexWhere((l) => l.contains('No. Struk') && l.contains('STR-SKY-901'));
      final kodeBookIdx = lines.indexWhere((l) => l.contains('Kode Book') && l.contains('SKY260910A1B2'));
      final separatorIdx = lines.indexWhere((l) => l.contains('--------------------------------'), kodeBookIdx);
      final pelangganIdx = lines.indexWhere((l) => l.contains('Pelanggan') && l.contains('Budi Santoso'), separatorIdx);
      final kontakIdx = lines.indexWhere((l) => l.contains('Kontak') && l.contains('081234567890'), pelangganIdx);
      final durasiIdx = lines.indexWhere((l) => l.contains('Durasi') && l.contains('2 Hari'), kontakIdx);

      // Verify strict ordering:
      // 1. Receipt number < 2. Booking code < 3. Separator < 4. Customer Name < 5. Customer Phone < 6. Duration
      expect(noStrukIdx, isNonNegative, reason: 'No. Struk should be present');
      expect(kodeBookIdx, greaterThan(noStrukIdx), reason: 'Kode Book should appear after No. Struk');
      expect(separatorIdx, greaterThan(kodeBookIdx), reason: 'Separator should appear after Kode Book');
      expect(pelangganIdx, greaterThan(separatorIdx), reason: 'Pelanggan should appear after Separator');
      expect(kontakIdx, equals(pelangganIdx + 1), reason: 'Kontak must be on separate line directly below customer name');
      expect(durasiIdx, greaterThan(kontakIdx), reason: 'Durasi should appear after Kontak');
    });

    test('Long customer name wraps neatly across lines without clipping and phone number remains visible', () {
      final receipt = ReceiptModel(
        receiptNumber: 'STR-LONG-001',
        date: DateTime(2026, 10, 15, 10, 0),
        adminName: 'Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.pickup,
        bookingCode: 'SKY260910LONG',
        customerName: 'Muhammad Alexander Setyabudhi Wijayakusuma',
        customerPhone: '+62 812-9876-5432 ext 101',
        unitName: 'iPhone 15 Pro Max',
        rentalDuration: '1 Minggu',
        rentFee: 1200000,
        depositFee: 300000,
        totalAmount: 1500000,
        paidAmount: 1500000,
        remainingAmount: 0,
        paymentMethod: 'Transfer',
        paymentStatus: 'Lunas',
      );

      final echoSettings = ReceiptFormatSettings.compactSettings();
      final text = receipt.toEscPos58mm(formatSettings: echoSettings);

      // All parts of customer name must exist in receipt
      expect(text.contains('Muhammad'), isTrue);
      expect(text.contains('Alexander'), isTrue);
      expect(text.contains('Setyabudhi'), isTrue);
      expect(text.contains('Wijayakusuma'), isTrue);

      // Customer phone must remain completely intact across wrapped lines
      expect(text.contains('+62 812-9876-5432'), isTrue);
      expect(text.contains('ext 101'), isTrue);
      expect(text.contains('1 Minggu'), isTrue);

      // All printed lines are <= 32 chars
      for (final line in text.split('\n')) {
        if (!line.startsWith('[STORE_NAME:') && !line.startsWith('[BARCODE:')) {
          expect(line.length, lessThanOrEqualTo(32), reason: 'Line too long: "$line"');
        }
      }
    });

    test('Rental duration supports various units correctly (Jam, Hari, Minggu, Bulan)', () {
      final testCases = [
        {'raw': '2 Jam', 'expected': '2 Jam'},
        {'raw': '1 Hari', 'expected': '1 Hari'},
        {'raw': '1 Minggu', 'expected': '1 Minggu'},
        {'raw': '1 Bulan', 'expected': '1 Bulan'},
        {'raw': '3 Hari', 'expected': '3 Hari'},
        {'raw': '24', 'expected': '1 Hari'},
        {'raw': '48', 'expected': '2 Hari'},
        {'raw': '168', 'expected': '1 Minggu'},
        {'raw': '720', 'expected': '1 Bulan'},
      ];

      for (final tc in testCases) {
        final formatted = ReceiptModel.formatRentalDurationText(tc['raw']!);
        expect(formatted, equals(tc['expected']));
      }
    });
  });

  group('Issue 3: Create Booking Floating Button Removed on Tablets', () {
    testWidgets('Create Booking floating action button is hidden on tablet landscape and portrait layouts',
        (WidgetTester tester) async {
      // 1. Tablet landscape (1280 x 800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      final repository = BookingRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FloatingActionButton, 'Buat Booking'), findsNothing);

      // 2. Tablet portrait (800 x 1280)
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FloatingActionButton, 'Buat Booking'), findsNothing);

      // 3. Mobile portrait (390 x 844) - floating action button MUST be visible
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FloatingActionButton, 'Buat Booking'), findsOneWidget);
    });
  });

  group('Issue 4: iPhone Handover Button Removed from Dashboard Right Column', () {
    testWidgets('Dashboard right column does NOT render iPhone Handover / Transfer button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = BookingRepository();
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
          home: DashboardScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Quick action card exists
      expect(find.text('Aksi Cepat Kasir'), findsOneWidget);
      expect(find.text('Buat Booking Baru'), findsWidgets);
      expect(find.text('Scan QR Booking'), findsOneWidget);
      expect(find.text('Cek Stok Unit'), findsOneWidget);

      // The iPhone Handover / Transfer button in the right column is absent
      expect(find.widgetWithText(ElevatedButton, 'Transfer iPhone'), findsNothing);
      expect(find.textContaining('Terima Transfer iPhone'), findsNothing);

      // Underlying handover route is still defined and accessible
      final transferRoute = AppRoutes.onGenerateRoute(
        const RouteSettings(name: AppRoutes.iphoneTransfer),
        repository,
      );
      expect(transferRoute, isNotNull);
    });
  });
}
