import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/receipt_format_settings.dart';
import 'package:skyrental_admin/models/receipt_model.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/screens/booking/booking_detail_screen.dart';
import 'package:skyrental_admin/screens/receipt/receipt_format_settings_screen.dart';
import 'package:skyrental_admin/screens/receipt/receipt_screen.dart';
import 'package:skyrental_admin/screens/scanner/qr_scanner_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/services/printer_storage_service.dart';
import 'package:skyrental_admin/services/thermal_print_service.dart';

class _FastMockBookingRepository extends BookingRepository {
  @override
  Future<BookingModel?> getBookingByCode(String code) async {
    try {
      return MockBookingData.items.firstWhere(
        (b) => b.bookingCode.toLowerCase() == code.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
  });

  group('Barcode & QR ESC/POS Printing Tests', () {
    test('ReceiptFormatSettings serialization supports barcode options', () {
      const defaultSettings = ReceiptFormatSettings();
      expect(defaultSettings.showBarcode, isTrue);
      expect(defaultSettings.barcodeType, equals('code128'));
      expect(defaultSettings.showBarcodeHri, isTrue);

      final custom = defaultSettings.copyWith(
        showBarcode: false,
        barcodeType: 'qrcode',
        showBarcodeHri: false,
      );
      expect(custom.showBarcode, isFalse);
      expect(custom.barcodeType, equals('qrcode'));
      expect(custom.showBarcodeHri, isFalse);

      final json = custom.toJson();
      final fromJson = ReceiptFormatSettings.fromJson(json);
      expect(fromJson.showBarcode, isFalse);
      expect(fromJson.barcodeType, equals('qrcode'));
      expect(fromJson.showBarcodeHri, isFalse);
    });

    test('ReceiptModel.toEscPos58mm outputs [BARCODE:...] tag when showBarcode is true', () {
      final receipt = ReceiptModel(
        receiptNumber: 'REC-TEST-BARCODE',
        date: DateTime(2026, 9, 18, 10, 0),
        adminName: 'Admin Test',
        type: ReceiptType.pickup,
        bookingCode: 'SKY260909A8F1',
        customerName: 'Ahmad Pelanggan',
        customerPhone: '081234567890',
        unitName: 'iPhone 15 Pro Max',
        rentalDuration: '3 Hari',
        rentFee: 450000,
        depositFee: 300000,
        totalAmount: 750000,
        paidAmount: 750000,
        remainingAmount: 0,
        paymentMethod: 'Tunai',
        paymentStatus: 'Lunas',
      );

      final withBarcode = receipt.toEscPos58mm(
        formatSettings: const ReceiptFormatSettings(showBarcode: true),
      );
      expect(withBarcode.contains('[BARCODE:SKY260909A8F1]'), isTrue);

      final withoutBarcode = receipt.toEscPos58mm(
        formatSettings: const ReceiptFormatSettings(showBarcode: false),
      );
      expect(withoutBarcode.contains('[BARCODE:'), isFalse);
    });

    test('ReceiptModel.toEscPos58mm for returnUnit also contains [BARCODE:...] tag', () {
      final receipt = ReceiptModel(
        receiptNumber: 'RET-TEST-001',
        date: DateTime(2026, 9, 18, 10, 0),
        adminName: 'Admin Return',
        type: ReceiptType.returnUnit,
        bookingCode: 'SKY260908C4D5',
        customerName: 'Kevin Return',
        customerPhone: '081234567891',
        unitName: 'iPhone 14 Pro',
        rentalDuration: '2 Hari',
        rentFee: 300000,
        depositFee: 200000,
        finesFee: 50000,
        refundAmount: 150000,
        totalAmount: 350000,
        paidAmount: 350000,
        remainingAmount: 0,
        paymentMethod: 'Transfer BCA',
        paymentStatus: 'Selesai',
      );

      final text = receipt.toEscPos58mm(
        formatSettings: const ReceiptFormatSettings(showBarcode: true),
      );
      expect(text.contains('[BARCODE:SKY260908C4D5]'), isTrue);
      expect(text.contains('STRUK PENGEMBALIAN UNIT'), isTrue);
    });

    test('ThermalPrintService generates valid Code 128 ESC/POS bytes', () {
      final bytes = ThermalPrintService.generateBarcode128Bytes('SKY260909A8F1', height: 64, width: 2, showHri: true);

      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x61));
      expect(bytes[2], equals(0x01));

      bool hasCode128Header = false;
      for (int i = 0; i < bytes.length - 2; i++) {
        if (bytes[i] == 0x1D && bytes[i + 1] == 0x6B && bytes[i + 2] == 0x49) {
          hasCode128Header = true;
          break;
        }
      }
      expect(hasCode128Header, isTrue);
    });

    test('ThermalPrintService generates valid QR ESC/POS bytes', () {
      final bytes = ThermalPrintService.generateQrCodeBytes('SKY260909A8F1', moduleSize: 4);

      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x61));
      expect(bytes[2], equals(0x01));

      bool hasQrHeader = false;
      for (int i = 0; i < bytes.length - 2; i++) {
        if (bytes[i] == 0x1D && bytes[i + 1] == 0x28 && bytes[i + 2] == 0x6B) {
          hasQrHeader = true;
          break;
        }
      }
      expect(hasQrHeader, isTrue);
    });

    test('ThermalPrintService.formatEscPosBytes parses [BARCODE:...] tag into ESC/POS bytes', () {
      final service = ThermalPrintService();
      const rawReceipt = 'HEADER LINE\n[BARCODE:SKY260909A8F1]\nFOOTER LINE\n';

      final code128Bytes = service.formatEscPosBytes(
        rawReceipt,
        formatSettings: const ReceiptFormatSettings(showBarcode: true, barcodeType: 'code128'),
      );
      expect(code128Bytes.isNotEmpty, isTrue);

      final qrBytes = service.formatEscPosBytes(
        rawReceipt,
        formatSettings: const ReceiptFormatSettings(showBarcode: true, barcodeType: 'qrcode'),
      );
      expect(qrBytes.isNotEmpty, isTrue);

      final bothBytes = service.formatEscPosBytes(
        rawReceipt,
        formatSettings: const ReceiptFormatSettings(showBarcode: true, barcodeType: 'both'),
      );
      expect(bothBytes.length, greaterThan(code128Bytes.length));
    });
  });

  group('Barcode UI & Scanner Flow Widget Tests', () {
    testWidgets('ReceiptScreen renders BarcodeWidget when showBarcode is enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiptScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ReceiptScreen), findsOneWidget);
      expect(find.byType(BarcodeWidget), findsWidgets);
    });

    testWidgets('ReceiptFormatSettingsScreen contains Barcode & QR configuration controls', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await PrinterStorageService().init();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiptFormatSettingsScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final barcodeHeader = find.text('Barcode / QR Code Booking');
      await tester.scrollUntilVisible(barcodeHeader, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      expect(barcodeHeader, findsOneWidget);
      expect(find.text('Cetak Barcode / QR di Struk'), findsOneWidget);
      expect(find.text('Barcode 1D (Code 128)'), findsOneWidget);
      expect(find.text('QR Code (2D)'), findsOneWidget);
      expect(find.text('Keduanya (1D & QR)'), findsOneWidget);
    });

    testWidgets('QrScannerScreen detects mock code and navigates to BookingDetailScreen', (tester) async {
      final repository = _FastMockBookingRepository();
      final testController = MobileScannerController(autoStart: false);
      addTearDown(testController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
          home: QrScannerScreen(repository: repository, controller: testController),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pindai Barcode / QR Booking'), findsOneWidget);
      expect(find.text('Simulasi Scan Cepat (Data Mock):'), findsOneWidget);

      final kevinChip = find.text('SKY260908C4D5');
      expect(kevinChip, findsOneWidget);

      await tester.tap(kevinChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(BookingDetailScreen), findsOneWidget);
      expect(find.text('SKY260908C4D5'), findsWidgets);
    });

    testWidgets('ReceiptFormatSettingsScreen has Eco Mode preset and typography controls', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await PrinterStorageService().init();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiptFormatSettingsScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Mode Hemat (Eco)'), findsOneWidget);
      expect(find.text('Mode Standar'), findsOneWidget);

      final ecoButton = find.text('Mode Hemat (Eco)');
      await tester.ensureVisible(ecoButton);
      await tester.tap(ecoButton);
      await tester.pumpAndSettle();

      final typographyHeader = find.text('Header Toko & Tipografi');
      await tester.ensureVisible(typographyHeader);
      expect(typographyHeader, findsOneWidget);
      expect(find.textContaining('Ekstra Besar'), findsOneWidget);
      expect(find.textContaining('Ekstra Tebal'), findsOneWidget);
    });
  });

  group('Receipt Customization & Eco Mode Unit Tests', () {
    test('ReceiptFormatSettings.compactSettings() creates eco mode preset', () {
      final compact = ReceiptFormatSettings.compactSettings();
      expect(compact.densityMode, equals('compact'));
      expect(compact.compactSpacing, isTrue);
      expect(compact.feedLines, equals(1));
      expect(compact.barcodeSize, equals('small'));
      expect(compact.showTagline, isFalse);
      expect(compact.showBranch, isTrue);
      expect(compact.showTerms, isFalse);
      expect(compact.showContactInfo, isTrue);
    });

    test('ReceiptFormatSettings typography and visibility JSON serialization', () {
      const custom = ReceiptFormatSettings(
        businessNameFontSize: 'extraLarge',
        businessNameFontWeight: 'extraBold',
        businessNameAlignment: 'left',
        densityMode: 'compact',
        compactSpacing: true,
        feedLines: 2,
        barcodeSize: 'small',
        showCustomerPhone: false,
        showRentFee: false,
      );

      final json = custom.toJson();
      final fromJson = ReceiptFormatSettings.fromJson(json);

      expect(fromJson.businessNameFontSize, equals('extraLarge'));
      expect(fromJson.businessNameFontWeight, equals('extraBold'));
      expect(fromJson.businessNameAlignment, equals('left'));
      expect(fromJson.densityMode, equals('compact'));
      expect(fromJson.compactSpacing, isTrue);
      expect(fromJson.feedLines, equals(2));
      expect(fromJson.barcodeSize, equals('small'));
      expect(fromJson.showCustomerPhone, isFalse);
      expect(fromJson.showRentFee, isFalse);
    });

    test('ReceiptModel.toEscPos58mm injects [STORE_NAME:...] tag with styling', () {
      final receipt = ReceiptModel(
        receiptNumber: 'REC-TEST-TYPO',
        date: DateTime(2026, 9, 18, 10, 0),
        adminName: 'Admin',
        type: ReceiptType.pickup,
        bookingCode: 'SKY260909A8F1',
        customerName: 'Ahmad Pelanggan',
        customerPhone: '081234567890',
        unitName: 'iPhone 15 Pro Max',
        rentalDuration: '3 Hari',
        rentFee: 450000,
        depositFee: 300000,
        totalAmount: 450000,
        paidAmount: 450000,
        remainingAmount: 0,
        paymentMethod: 'Tunai',
        paymentStatus: 'Lunas',
      );

      const customSettings = ReceiptFormatSettings(
        businessName: 'MY RENTAL STORE',
        businessNameFontSize: 'large',
        businessNameFontWeight: 'bold',
        businessNameAlignment: 'center',
      );

      final text = receipt.toEscPos58mm(formatSettings: customSettings);
      expect(text.contains('[STORE_NAME:large:bold:center:MY RENTAL STORE]'), isTrue);
    });

    test('ReceiptModel paper estimation calculates shorter length for compact mode', () {
      final receipt = ReceiptModel(
        receiptNumber: 'REC-TEST-LEN',
        date: DateTime(2026, 9, 18, 10, 0),
        adminName: 'Admin',
        type: ReceiptType.pickup,
        bookingCode: 'SKY260909A8F1',
        customerName: 'Ahmad Pelanggan',
        customerPhone: '081234567890',
        unitName: 'iPhone 15 Pro Max',
        rentalDuration: '3 Hari',
        rentFee: 450000,
        depositFee: 300000,
        totalAmount: 750000,
        paidAmount: 750000,
        remainingAmount: 0,
        paymentMethod: 'Tunai',
        paymentStatus: 'Lunas',
      );

      const stdSettings = ReceiptFormatSettings();
      final ecoSettings = ReceiptFormatSettings.compactSettings();

      final stdText = receipt.toEscPos58mm(formatSettings: stdSettings);
      final ecoText = receipt.toEscPos58mm(formatSettings: ecoSettings);

      final stdLength = ReceiptModel.estimatePaperLengthCm(stdText, stdSettings);
      final ecoLength = ReceiptModel.estimatePaperLengthCm(ecoText, ecoSettings);

      expect(ecoLength, lessThan(stdLength));
      expect(stdLength, greaterThan(15.0));
      expect(ecoLength, lessThan(15.0));
    });

    test('ThermalPrintService formatEscPosBytes emits magnification and bold bytes for STORE_NAME', () {
      final service = ThermalPrintService();
      const rawReceipt = '[STORE_NAME:extraLarge:extraBold:center:TEST STORE]\nHEADER LINE\n';

      final bytes = service.formatEscPosBytes(
        rawReceipt,
        formatSettings: const ReceiptFormatSettings(
          businessNameFontSize: 'extraLarge',
          businessNameFontWeight: 'extraBold',
        ),
      );

      // Verify GS ! 0x11 (double width & height)
      bool hasMagnification = false;
      for (int i = 0; i < bytes.length - 2; i++) {
        if (bytes[i] == 0x1D && bytes[i + 1] == 0x21 && bytes[i + 2] == 0x11) {
          hasMagnification = true;
          break;
        }
      }
      expect(hasMagnification, isTrue);

      // Verify ESC E 1 (bold)
      bool hasBold = false;
      for (int i = 0; i < bytes.length - 2; i++) {
        if (bytes[i] == 0x1B && bytes[i + 1] == 0x45 && bytes[i + 2] == 0x01) {
          hasBold = true;
          break;
        }
      }
      expect(hasBold, isTrue);
    });
  });
}

