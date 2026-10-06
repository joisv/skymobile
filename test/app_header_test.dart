import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/screens/account/account_screen.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/screens/dashboard/dashboard_screen.dart';
import 'package:skyrental_admin/screens/dashboard/sales_report_screen.dart';
import 'package:skyrental_admin/screens/receipt/printer_settings_screen.dart';
import 'package:skyrental_admin/screens/unit_status/unit_status_list_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/services/printer_storage_service.dart';
import 'package:skyrental_admin/widgets/app_header.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    await PrinterStorageService().init();
  });
  group('AppHeader Unit & Logic Tests', () {
    test('getUserInitials generates initials correctly for 1-word and multi-word names', () {
      // 1-word name -> first letter
      expect(AppHeader.getUserInitials('Admin'), 'A');
      expect(AppHeader.getUserInitials('Budi'), 'B');
      expect(AppHeader.getUserInitials('superadmin'), 'S');

      // Multi-word name -> first letter of first word + first letter of second word
      expect(AppHeader.getUserInitials('John Doe'), 'JD');
      expect(AppHeader.getUserInitials('Budi Santoso'), 'BS');
      expect(AppHeader.getUserInitials('Siti Aminah Putri'), 'SA');
      expect(AppHeader.getUserInitials('  Ahmad   Dahlan  '), 'AD');

      // Null or empty fallbacks
      expect(AppHeader.getUserInitials(null), 'U');
      expect(AppHeader.getUserInitials(''), 'U');
      expect(AppHeader.getUserInitials('   '), 'U');
    });

    test('formatRole accurately maps roles and distinguishes Affiliate Admin from Admin', () {
      expect(AppHeader.formatRole('affiliate-admin'), 'Affiliate Admin');
      expect(AppHeader.formatRole('affiliate_admin'), 'Affiliate Admin');
      expect(AppHeader.formatRole('affiliate admin'), 'Affiliate Admin');
      expect(AppHeader.formatRole('super-admin'), 'Super Admin');
      expect(AppHeader.formatRole('superadmin'), 'Super Admin');
      expect(AppHeader.formatRole('admin'), 'Admin');
      expect(AppHeader.formatRole('kasir'), 'Kasir');
      expect(AppHeader.formatRole('staff'), 'Staff');
      expect(AppHeader.formatRole(null), 'Staff Operasional');
    });

    test('getRoleBadgeText accurately creates uppercase badge text without mislabeling Affiliate Admin', () {
      expect(AppHeader.getRoleBadgeText('affiliate-admin'), 'AFFILIATE ADMIN');
      expect(AppHeader.getRoleBadgeText('affiliate_admin'), 'AFFILIATE ADMIN');
      expect(AppHeader.getRoleBadgeText('super-admin'), 'SUPER ADMIN');
      expect(AppHeader.getRoleBadgeText('admin'), 'ADMIN');
      expect(AppHeader.getRoleBadgeText('kasir'), 'KASIR');
      expect(AppHeader.getRoleBadgeText('staff'), 'STAFF');
      expect(AppHeader.getRoleBadgeText(null), 'KASIR');
    });
  });

  group('AppHeader Widget Rendering Tests', () {
    setUp(() {
      AuthService().setCurrentUserForTest(const AdminUserModel(
        id: 10,
        name: 'John Doe',
        email: 'john@mitra.com',
        phone: '081234567890',
        role: 'affiliate-admin',
        outletName: 'Mitra Jogja',
        shiftName: 'Shift Pagi • POS-01',
      ));
    });

    tearDown(() {
      AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    });

    testWidgets('AppHeader displays authenticated user name, Affiliate Admin role, and JD initials on mobile', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppHeader(
              title: 'Unit iPhone',
              showBackButton: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check User Name
      expect(find.text('John Doe'), findsOneWidget);

      // Check Role Badge is AFFILIATE ADMIN (not ADMIN)
      expect(find.text('AFFILIATE ADMIN'), findsOneWidget);
      expect(find.text('ADMIN'), findsNothing);

      // Check Title
      expect(find.text('Unit iPhone'), findsOneWidget);

      // Check Back Button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Check Initials Avatar 'JD'
      expect(find.text('JD'), findsOneWidget);

      // Check no printer connection text exists
      expect(find.textContaining('Printer'), findsNothing);
      expect(find.textContaining('Thermal'), findsNothing);
      expect(find.textContaining('Connected'), findsNothing);
      expect(find.textContaining('Terhubung'), findsNothing);
    });

    testWidgets('AppHeader displays brand, date, and user info on tablet', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppHeader(
              isTablet: true,
              title: 'Unit iPhone',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SKYRental'), findsOneWidget);
      expect(find.text('Unit iPhone'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('AFFILIATE ADMIN'), findsOneWidget);
      expect(find.text('JD'), findsOneWidget);
      expect(find.text('Shift Pagi • POS-01'), findsOneWidget);

      // Verify NO printer connection status
      expect(find.textContaining('Printer'), findsNothing);
      expect(find.textContaining('Thermal'), findsNothing);
      expect(find.textContaining('Connected'), findsNothing);
    });

    testWidgets('AppHeader updates dynamically when auth state changes', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('JD'), findsOneWidget);
      expect(find.text('AFFILIATE ADMIN'), findsOneWidget);

      // Switch to a different user
      AuthService().setCurrentUserForTest(const AdminUserModel(
        id: 20,
        name: 'Ahmad Dahlan',
        email: 'ahmad@skyrental.id',
        phone: '081234567891',
        role: 'super-admin',
        outletName: 'Outlet Pusat',
        shiftName: 'Shift Siang',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ahmad Dahlan'), findsOneWidget);
      expect(find.text('AD'), findsOneWidget);
      expect(find.text('SUPER ADMIN'), findsOneWidget);
      expect(find.text('Super Admin'), findsOneWidget);
    });
  });

  group('Target Screens AppHeader Integration Tests', () {
    late BookingRepository repository;

    setUp(() {
      repository = BookingRepository();
      AuthService().setCurrentUserForTest(const AdminUserModel(
        id: 15,
        name: 'Budi Santoso',
        email: 'budi@skyrental.id',
        phone: '08123456789',
        role: 'affiliate-admin',
        outletName: 'Outlet Gandaria',
        shiftName: 'Shift Pagi • POS-01',
      ));
    });

    tearDown(() {
      AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    });

    testWidgets('DashboardScreen renders unified AppHeader with correct user data', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('BS'), findsOneWidget);
      expect(find.text('AFFILIATE ADMIN'), findsOneWidget);
    });

    testWidgets('SalesReportScreen renders unified AppHeader with correct user data', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: SalesReportScreen(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('BS'), findsOneWidget);
    });

    testWidgets('UnitStatusListScreen renders unified AppHeader with title and user data', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: UnitStatusListScreen(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('Status Unit iPhone'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('BS'), findsOneWidget);
    });

    testWidgets('AccountScreen (Shift & Printer Tab) renders unified AppHeader', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AccountScreen(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('Budi Santoso'), findsWidgets);
      expect(find.text('BS'), findsOneWidget);
      expect(find.text('AFFILIATE ADMIN'), findsWidgets);
    });

    testWidgets('CreateBookingScreen renders unified AppHeader on tablet and mobile', (tester) async {
      // Mobile
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CreateBookingScreen(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('Buat Booking Baru'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('BS'), findsOneWidget);

      // Tablet
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('SKYRental'), findsOneWidget);
      expect(find.text('Buat Booking Baru'), findsWidgets);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('BS'), findsOneWidget);
    });

    testWidgets('PrinterSettingsScreen renders unified AppHeader', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PrinterSettingsScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('Pengaturan & Uji Printer'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('BS'), findsOneWidget);
    });
  });
}
