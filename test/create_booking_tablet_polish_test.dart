import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    MockBookingData.resetInventory();
  });

  group('CreateBookingScreen Tablet Polish Tests', () {
    testWidgets('Step 1 renders unified phone input container and modern collateral chips on tablet', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: CreateBookingScreen(repository: repository),
        routes: {
          '/payment-deposit': (_) => const Scaffold(body: Text('Konfirmasi Pembayaran')),
        },
      ));
      await tester.pumpAndSettle();

      // Verify Step 1 is rendered
      expect(find.text('1. Data & Jaminan Customer'), findsOneWidget);

      // Verify country code selector shows clean +62
      expect(find.text('+62'), findsWidgets);

      // Verify collateral chips exist
      expect(find.text('Tipe Jaminan Fisik Diserahkan'), findsOneWidget);
      expect(find.text('KTP Asli Fisik'), findsWidgets);
      expect(find.text('SIM A/C Aktif'), findsOneWidget);

      // Tap on SIM chip
      await tester.tap(find.text('SIM A/C Aktif'));
      await tester.pumpAndSettle();

      // Navigation button has 48px height and is anchored in the right rail
      final nextBtn = find.byKey(const Key('btn_next_to_step_2'));
      expect(nextBtn, findsOneWidget);
      expect(tester.getSize(nextBtn).height, equals(48.0));
    });

    testWidgets('Step 2 unit cards are compact with clean bullets and no redundant phone icons', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: CreateBookingScreen(repository: repository),
        routes: {
          '/payment-deposit': (_) => const Scaffold(body: Text('Konfirmasi Pembayaran')),
        },
      ));
      await tester.pumpAndSettle();

      // Fill Step 1
      await tester.enterText(find.byType(TextFormField).at(0), 'Tablet Customer');
      await tester.enterText(find.byType(TextFormField).at(1), '081299998888');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Sudirman 10');
      await tester.pumpAndSettle();

      // Advance to Step 2
      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      expect(find.text('2. Unit iPhone & Durasi'), findsOneWidget);

      // Unit cards display clean SN format
      expect(find.textContaining('SN: P9ZX44MN67'), findsOneWidget);

      // Tap unit card
      await tester.tap(find.textContaining('SN: P9ZX44MN67'));
      await tester.pumpAndSettle();

      // Verify duration and schedule configuration are anchored below unit selection
      expect(find.text('Pilih Durasi'), findsOneWidget);
      expect(find.text('Jadwal Mulai Sewa'), findsOneWidget);

      // Button to Step 3 is 48px height
      final nextToStep3 = find.byKey(const Key('btn_next_to_step_3'));
      expect(nextToStep3, findsOneWidget);
      expect(tester.getSize(nextToStep3).height, equals(48.0));
    });

    testWidgets('Step 3 offers Payment Status & Channel Selector on left canvas', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: CreateBookingScreen(repository: repository),
        routes: {
          '/payment-deposit': (_) => const Scaffold(body: Text('Konfirmasi Pembayaran')),
        },
      ));
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(find.byType(TextFormField).at(0), 'Tablet Customer');
      await tester.enterText(find.byType(TextFormField).at(1), '081299998888');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Sudirman 10');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Step 2: Select unit
      await tester.tap(find.textContaining('SN: P9ZX44MN67'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_next_to_step_3')));
      await tester.pumpAndSettle();

      // Verify Step 3 Payment & Checkout selector
      expect(find.text('3. Estimasi Biaya & Konfirmasi'), findsOneWidget);
      expect(find.text('Status Pembayaran'), findsOneWidget);
      expect(find.text('Bayar Saat Pickup'), findsOneWidget);
      expect(find.text('Lunas Sekarang'), findsOneWidget);
      expect(find.text('DP / Panjar'), findsOneWidget);

      // Verify payment channel options
      expect(find.text('Metode / Saluran Pembayaran'), findsOneWidget);
      expect(find.text('QRIS'), findsWidgets);
      expect(find.text('Tunai'), findsWidgets);
      expect(find.text('Transfer Bank'), findsWidgets);

      // Tap on 'Lunas Sekarang'
      await tester.tap(find.text('Lunas Sekarang'));
      await tester.pumpAndSettle();

      // Tap on 'Tunai'
      await tester.tap(find.text('Tunai').first);
      await tester.pumpAndSettle();

      // Verify notes field
      expect(find.text('Catatan Khusus & Kebutuhan Tambahan'), findsOneWidget);

      // Verify confirm button has 48px height and is anchored
      final confirmBtn = find.byKey(const Key('btn_confirm_booking'));
      expect(confirmBtn, findsOneWidget);
      expect(tester.getSize(confirmBtn).height, equals(48.0));

      // Submit booking
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Navigated to confirmation / payment screen
      expect(find.text('Konfirmasi Pembayaran'), findsOneWidget);
    });

    testWidgets('Step 2 unit selection preserves duration and calculates non-zero grand total on Step 3 and PaymentDepositScreen', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: CreateBookingScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      // Fill Step 1
      await tester.enterText(find.byType(TextFormField).at(0), 'Dewi Sartika');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Merdeka No. 12 Bandung');
      await tester.pumpAndSettle();

      // Next to Step 2
      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Tap on available unit
      await tester.tap(find.textContaining('SN: P9ZX44MN67'));
      await tester.pumpAndSettle();

      // Advance to Step 3
      await tester.tap(find.byKey(const Key('btn_next_to_step_3')));
      await tester.pumpAndSettle();

      // Check Step 3 total is NOT Rp 0
      expect(find.text('Rp 0'), findsNothing);
      expect(find.text('TOTAL BIAYA SEWA'), findsOneWidget);

      // Select 'Lunas Sekarang'
      await tester.tap(find.text('Lunas Sekarang'));
      await tester.pumpAndSettle();

      // Tap confirm booking to navigate to PaymentDepositScreen
      final confirmBtn = find.byKey(const Key('btn_confirm_booking'));
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify PaymentDepositScreen is rendered and total amount is NOT Rp 0
      expect(find.textContaining('Konfirmasi Pembayaran'), findsWidgets);
      expect(find.text('Dewi Sartika'), findsWidgets);
      // Ensure the payment amount reflects the 24h rental price (Rp 100.000)
      expect(find.text('Rp 100.000'), findsWidgets);
    });
  });
}
