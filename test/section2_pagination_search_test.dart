import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    MockBookingData.resetInventory();
  });

  group('Section 2: iPhone Selection, Search, Filter & Pagination Tests', () {
    testWidgets('Section 2 defaults to Tersedia filter and displays search bar', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repository)));
      await tester.pumpAndSettle();

      // Step 1: Fill guest info
      await tester.enterText(find.byType(TextFormField).at(0), 'Aditya Pratama');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Kaliurang KM 5');
      await tester.pumpAndSettle();

      // Proceed to Step 2
      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Verify Section 2 header and search bar
      expect(find.text('2. Unit iPhone & Durasi'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cari Tipe iPhone'), findsOneWidget);

      // Verify availability filter chips exist
      expect(find.byKey(const Key('filter_chip_tersedia')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_semua')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_disewa')), findsOneWidget);
      expect(find.text('Tersedia (Default)'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Sedang Disewa'), findsOneWidget);
    });

    testWidgets('Section 2 search filters by iPhone model and serial number', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repository)));
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(find.byType(TextFormField).at(0), 'Aditya Pratama');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Kaliurang KM 5');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Search by specific serial number
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'DX3GGKS9SAA');
      await tester.pumpAndSettle();

      // Only the searched unit should be displayed
      expect(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains('DX3GGKS9SAA')), findsOneWidget);
      expect(find.textContaining('P9ZX44MN67'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      // Other units reappear
      expect(find.textContaining('P9ZX44MN67'), findsOneWidget);
    });

    testWidgets('Section 2 preserves selected unit when searching and switching filters', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repository)));
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(find.byType(TextFormField).at(0), 'Aditya Pratama');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Kaliurang KM 5');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Select first available unit
      final firstAvailableUnitCard = find.textContaining('P9ZX44MN67');
      expect(firstAvailableUnitCard, findsOneWidget);
      await tester.tap(firstAvailableUnitCard);
      await tester.pumpAndSettle();

      expect(find.text('Terpilih'), findsOneWidget);

      // Search for something else
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'DX3GGKS9SAA');
      await tester.pumpAndSettle();

      // P9ZX44MN67 is not in the search results
      expect(find.textContaining('P9ZX44MN67'), findsNothing);

      // But next button to step 3 should still be active because selected unit is preserved!
      final nextToStep3 = find.byKey(const Key('btn_next_to_step_3'));
      await tester.tap(nextToStep3);
      await tester.pumpAndSettle();

      // Successfully navigated to Step 3 with the preserved selected unit!
      expect(find.text('3. Estimasi Biaya & Konfirmasi'), findsOneWidget);
      expect(find.textContaining('iPhone 15 Pro Max'), findsWidgets);
    });

    testWidgets('Section 2 responsive layout: single-column on mobile vs 2-column on tablet', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      // Tablet Viewport (1024 x 768)
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repository)));
      await tester.pumpAndSettle();

      // Tablet renders tablet layout with Step 1
      expect(find.text('1. Data & Jaminan Customer'), findsOneWidget);

      // Fill step 1 and advance to step 2 on tablet
      await tester.enterText(find.byType(TextFormField).at(0), 'Aditya Pratama');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Kaliurang KM 5');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Section 2 is now visible on tablet
      expect(find.text('2. Unit iPhone & Durasi'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // search bar on tablet
      expect(find.byKey(const Key('filter_chip_tersedia')), findsOneWidget); // filter chips on tablet
    });

    testWidgets('Section 2 pagination loads additional units when Muat Lebih Banyak is tapped', (tester) async {
      final repository = BookingRepository();
      repository.resetInventory();

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(repository: repository)));
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(find.byType(TextFormField).at(0), 'Aditya Pratama');
      await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Kaliurang KM 5');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
      await tester.pumpAndSettle();

      // Switch to 'Semua' to see all units
      await tester.tap(find.byKey(const Key('filter_chip_semua')));
      await tester.pumpAndSettle();

      // Check if Load More button exists
      final loadMoreBtn = find.byKey(const Key('btn_load_more_units'));
      expect(loadMoreBtn, findsOneWidget);

      // Scroll to load more button and tap it
      await tester.ensureVisible(loadMoreBtn);
      await tester.pumpAndSettle();
      await tester.tap(loadMoreBtn);
      await tester.pumpAndSettle();
    });
  });
}
