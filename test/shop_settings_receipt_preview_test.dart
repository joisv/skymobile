import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/screens/account/account_screen.dart';
import 'package:skyrental_admin/screens/account/shop_settings_screen.dart';
import 'package:skyrental_admin/screens/receipt/widgets/thermal_receipt_paper_preview.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/services/printer_storage_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    await PrinterStorageService().init();
  });

  group('Thermal Receipt Preview in Shop Settings Tests', () {
    testWidgets('ThermalReceiptPaperPreview renders ESC/POS 58mm layout without WiFi', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ThermalReceiptPaperPreview(
                shopName: 'TOKO GADGET JOGJA',
                outletName: 'Cabang Malioboro',
                phoneNumber: '0812-9999-8888',
                footerNote: 'Terima kasih telah menyewa unit',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header store name & branch
      expect(find.text('TOKO GADGET JOGJA'), findsOneWidget);
      expect(find.textContaining('Cabang Malioboro'), findsOneWidget);

      // Check footer and phone
      expect(find.textContaining('Terima kasih telah menyewa unit'), findsOneWidget);
      expect(find.textContaining('0812-9999-8888'), findsOneWidget);

      // Verify WiFi text and barcode WiFi validation do NOT exist
      expect(find.textContaining('WiFi:'), findsNothing);
      expect(find.textContaining('SSID'), findsNothing);
      expect(find.text('VALIDASI OUTLET RESMI'), findsNothing);

      // Verify thermal 58mm monospace subtext exists
      expect(find.text('— Lebar Kertas Standar VSC MP-58C (32 Karakter Monospace) —'), findsOneWidget);
    });

    testWidgets('ShopSettingsScreen (Mobile) shows live thermal preview and no WiFi section', (tester) async {
      final repo = BookingRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ShopSettingsScreen(repository: repo),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify simulated thermal receipt preview is present
      expect(find.byType(ThermalReceiptPaperPreview), findsOneWidget);
      expect(find.text('PRATINJAU KERTAS THERMAL 58MM (LIVE RECEIPT PREVIEW)'), findsOneWidget);

      // Verify WiFi fields are absent from the form
      expect(find.text('WIFI OUTLET (FASILITAS PELANGGAN)'), findsNothing);
      expect(find.text('Nama Jaringan WiFi (SSID)'), findsNothing);
      expect(find.text('Kata Sandi WiFi'), findsNothing);

      // Find store name textfield and update it live
      final shopNameField = find.byType(TextFormField).first;
      expect(shopNameField, findsOneWidget);

      await tester.enterText(shopNameField, 'SKYRENTAL NEW NAME');
      await tester.pump();

      // Verify live preview immediately reflects the new name
      expect(
        find.descendant(
          of: find.byType(ThermalReceiptPaperPreview),
          matching: find.text('SKYRENTAL NEW NAME'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('AccountScreen (Tablet) updates thermal preview live on field changes without WiFi card', (tester) async {
      final repo = BookingRepository();

      // Set tablet screen size (1280x800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        MaterialApp(
          home: AccountScreen(repository: repo),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify Shop Settings detail pane is active
      expect(find.text('Identitas Toko & Konfigurasi Outlet'), findsOneWidget);
      expect(find.byType(ThermalReceiptPaperPreview), findsOneWidget);

      // Verify WiFi card is absent
      expect(find.text('WIFI OUTLET (FASILITAS PELANGGAN)'), findsNothing);
      expect(find.text('Tampil di QR & Struk'), findsNothing);

      // Live change shop name textfield
      final shopNameField = find.byType(TextField).first;
      await tester.enterText(shopNameField, 'TOKO BARU TABLET');
      await tester.pump();

      // Verify receipt preview has the updated store name
      expect(
        find.descendant(
          of: find.byType(ThermalReceiptPaperPreview),
          matching: find.text('TOKO BARU TABLET'),
        ),
        findsOneWidget,
      );

      // Live change footer text (5th TextField in shop settings)
      final footerField = find.byType(TextField).at(4);
      await tester.ensureVisible(footerField);
      await tester.enterText(footerField, 'Catatan struk thermal baru');
      await tester.pump();

      // Verify receipt preview has the updated footer note
      expect(
        find.descendant(
          of: find.byType(ThermalReceiptPaperPreview),
          matching: find.textContaining('Catatan struk thermal baru'),
        ),
        findsOneWidget,
      );
    });
  });
}
