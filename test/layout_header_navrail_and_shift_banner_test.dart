import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/screens/dashboard/expenses_screen.dart';
import 'package:skyrental_admin/screens/dashboard/sales_report_screen.dart';
import 'package:skyrental_admin/screens/main_navigation_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/widgets/app_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(
      const AdminUserModel(
        id: 1,
        name: 'Rian Cashier',
        email: 'rian@skyrental.id',
        phone: '08123456789',
        role: 'cashier',
        outletName: 'Genteng Pusat',
        shiftName: 'Shift Pagi',
        affiliateId: 4,
      ),
    );
  });

  group('1. Tablet Navigation Rail (Sidebar Menu) Tests', () {
    testWidgets('Removes top storefront icon and vertically centers navigation items', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = BookingRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0284C7)),
          ),
          home: MainNavigationScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Top storefront icon should be removed
      expect(find.byIcon(Icons.storefront_rounded), findsNothing);

      // Verify all navigation items exist
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Unit iPhone'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Active nav rail item applies primary theme color ONLY to icon background container and text', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const customPrimary = Color(0xFF6366F1); // Indigo theme
      final repo = BookingRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: customPrimary,
              primary: customPrimary,
            ),
          ),
          home: MainNavigationScreen(repository: repo, initialIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      // Dashboard is active (index 0)
      final dashboardText = tester.widget<Text>(find.text('Dashboard'));
      expect(dashboardText.style?.color, equals(customPrimary));
      expect(dashboardText.style?.fontWeight, equals(FontWeight.bold));

      // Inactive item Report (index 1) has muted color
      final reportText = tester.widget<Text>(find.text('Report'));
      expect(reportText.style?.color, equals(const Color(0xFF64748B)));

      // Active icon container has customPrimary background
      final activeContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.byType(Container),
        ),
      );

      final iconBackgroundContainers = activeContainers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration && decoration.color == customPrimary) {
          return true;
        }
        return false;
      }).toList();

      expect(iconBackgroundContainers.isNotEmpty, isTrue);
    });
  });

  group('2. Global Header Standardization Tests', () {
    testWidgets('Header displays uppercase SKYRENTAL and removes POS Station #01 subtitle', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppHeader(
              isTablet: true,
              title: 'Laporan Penjualan',
            ),
            body: SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Brand title must be uppercase SKYRENTAL
      expect(find.text('SKYRENTAL'), findsOneWidget);
      expect(find.text('SKYRental'), findsNothing);

      // Subtitle "POS Station #01" must NOT exist
      expect(find.text('POS Station #01'), findsNothing);
    });

    testWidgets('User profile pill removes Shift Aktif • POS-01 subtitle text', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppHeader(
              isTablet: true,
            ),
            body: SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Profile avatar initials and name
      expect(find.text('Rian Cashier'), findsOneWidget);
      expect(find.text('RC'), findsOneWidget);

      // Role badge
      expect(find.text('KASIR'), findsOneWidget);

      // Subtitle "Shift Aktif • POS-01" or any "POS-01" must NOT be displayed
      expect(find.textContaining('POS-01'), findsNothing);
      expect(find.textContaining('Shift Aktif •'), findsNothing);
    });
  });

  group('3. Shift Status Notification Relocation in Report Tests', () {
    testWidgets('SalesReportScreen displays shift status banner in reconciliation card', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = BookingRepository();

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/cashier-shift': (context) => const Scaffold(body: Text('Cashier Shift Route')),
          },
          home: SalesReportScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Verify reconciliation section exists
      expect(find.text('Rekonsiliasi Kas Laci & Biaya Cabang'), findsOneWidget);

      // Verify shift status banner appears inside reconciliation section
      expect(find.textContaining('Shift Kasir'), findsWidgets);
      expect(find.byType(ElevatedButton), findsWidgets);
    });
  });

  group('4. Expenses Screen FAB Dynamic Theme Color Tests', () {
    testWidgets('Floating Action Button dynamically matches active primary theme color', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const customPrimary = Color(0xFF0D9488); // Teal theme
      final repo = BookingRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: customPrimary,
              primary: customPrimary,
            ),
          ),
          home: ExpensesScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byKey(const Key('btn_fab_catat_biaya'));
      expect(fabFinder, findsOneWidget);

      final fab = tester.widget<FloatingActionButton>(fabFinder);
      expect(fab.backgroundColor, equals(customPrimary));
      expect(fab.foregroundColor, equals(Colors.white));

      // Verify text and icon inside FAB
      expect(find.text('Catat Biaya'), findsOneWidget);
      expect(find.descendant(of: fabFinder, matching: find.byIcon(Icons.add_rounded)), findsOneWidget);
    });
  });
}
