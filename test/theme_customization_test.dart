import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/app_theme_model.dart';
import 'package:skyrental_admin/screens/account/account_screen.dart';
import 'package:skyrental_admin/screens/account/theme_settings_screen.dart';
import 'package:skyrental_admin/services/theme_service.dart';
import 'package:skyrental_admin/theme/app_theme.dart';

import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/services/printer_storage_service.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    await PrinterStorageService().init();
  });

  group('AppThemePreset Tests', () {
    test('defaultPresets contains 8 curated palettes', () {
      expect(AppThemePreset.defaultPresets.length, 8);
      expect(AppThemePreset.defaultPresets.first.id, 'sky_blue');
    });

    test('getById returns matching preset or fallback', () {
      final indigo = AppThemePreset.getById('royal_indigo');
      expect(indigo.id, 'royal_indigo');
      expect(indigo.name, 'Royal Indigo');

      final fallback = AppThemePreset.getById('non_existent_preset');
      expect(fallback.id, 'sky_blue');
    });
  });

  group('ThemeService Unit Tests', () {
    test('initializes and switches presets', () async {
      final service = ThemeService();
      await service.init();
      expect(service.activePresetId, 'sky_blue');
      expect(service.isCustom, false);

      await service.setPreset('emerald_green');
      expect(service.activePresetId, 'emerald_green');
      expect(service.primaryColor, const Color(0xFF064E3B));
      expect(service.accentColor, const Color(0xFF10B981));
      expect(service.themeData, isA<ThemeData>());

      // Reset to default
      await service.resetToDefault();
      expect(service.activePresetId, 'sky_blue');
      expect(service.primaryColor, const Color(0xFF0F172A));
    });

    test('applies custom colors correctly', () async {
      final service = ThemeService();
      await service.init();

      const customPrimary = Color(0xFF1E3A8A);
      const customAccent = Color(0xFFF97316);

      await service.setCustomColors(
        primary: customPrimary,
        accent: customAccent,
      );

      expect(service.isCustom, true);
      expect(service.activePresetId, 'custom');
      expect(service.primaryColor, customPrimary);
      expect(service.accentColor, customAccent);
    });

    test('AppTheme.primary and AppTheme.accent dynamically reflect ThemeService changes', () async {
      final service = ThemeService();
      await service.init();

      await service.setPreset('emerald_green');
      expect(AppTheme.primary, const Color(0xFF064E3B));
      expect(AppTheme.accent, const Color(0xFF10B981));
      expect(AppTheme.secondary, const Color(0xFF10B981));
      expect(AppTheme.accentLight, const Color(0xFFECFDF5));

      await service.setPreset('royal_indigo');
      expect(AppTheme.primary, const Color(0xFF1E1B4B));
      expect(AppTheme.accent, const Color(0xFF4F46E5));
      expect(AppTheme.secondary, const Color(0xFF4F46E5));
      expect(AppTheme.accentLight, const Color(0xFFEEF2FF));

      await service.resetToDefault();
      expect(AppTheme.primary, const Color(0xFF0F172A));
      expect(AppTheme.accent, const Color(0xFF0EA5E9));
    });

    test('Dark Mode toggling adapts dynamic colors and themes', () async {
      final service = ThemeService();
      await service.init();
      await service.setThemeMode(ThemeMode.light);

      expect(service.themeMode, ThemeMode.light);
      expect(service.isDarkMode, false);
      expect(AppTheme.background, const Color(0xFFF8F9FF));
      expect(AppTheme.surface, Colors.white);
      expect(AppTheme.textPrimary, const Color(0xFF0B1C30));
      expect(AppTheme.cardBorder, const Color(0xFFE2E8F0));

      // Switch to Dark Mode
      await service.setThemeMode(ThemeMode.dark);
      expect(service.themeMode, ThemeMode.dark);
      expect(service.isDarkMode, true);
      expect(AppTheme.background, const Color(0xFF0B1120));
      expect(AppTheme.surface, const Color(0xFF1E293B));
      expect(AppTheme.textPrimary, const Color(0xFFF8FAFC));
      expect(AppTheme.cardBorder, const Color(0xFF334155));

      // Reset back to Light Mode
      await service.setThemeMode(ThemeMode.light);
      expect(service.isDarkMode, false);
    });

    test('Button border radius is standardized to 8px', () {
      final lightTheme = AppTheme.lightTheme;
      final darkTheme = AppTheme.darkTheme;

      final lightElevatedShape = lightTheme.elevatedButtonTheme.style?.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(lightElevatedShape?.borderRadius, BorderRadius.circular(8));

      final darkElevatedShape = darkTheme.elevatedButtonTheme.style?.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(darkElevatedShape?.borderRadius, BorderRadius.circular(8));

      final lightOutlinedShape = lightTheme.outlinedButtonTheme.style?.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(lightOutlinedShape?.borderRadius, BorderRadius.circular(8));

      final darkOutlinedShape = darkTheme.outlinedButtonTheme.style?.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(darkOutlinedShape?.borderRadius, BorderRadius.circular(8));
    });
  });

  group('ThemeSettingsScreen Widget Tests', () {
    testWidgets('renders ThemeSettingsScreen, switches mode and switches preset', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = ThemeService();
      await service.init();
      await service.resetToDefault();
      await service.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: service.lightTheme,
          darkTheme: service.darkTheme,
          themeMode: service.themeMode,
          home: const ThemeSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check title, mode section, and live preview
      expect(find.text('Tema & Warna Aplikasi'), findsOneWidget);
      expect(find.text('MODE TAMPILAN'), findsOneWidget);
      expect(find.text('Terang'), findsOneWidget);
      expect(find.text('Gelap'), findsOneWidget);
      expect(find.text('Sistem'), findsOneWidget);
      expect(find.text('Pratinjau Langsung Tema'), findsOneWidget);
      expect(find.text('PILIHAN TEMA PRESET'), findsOneWidget);

      // Tap on 'Gelap' mode
      final darkOption = find.text('Gelap');
      await tester.tap(darkOption);
      await tester.pumpAndSettle();

      expect(service.themeMode, ThemeMode.dark);
      expect(find.text('Mode Gelap diaktifkan'), findsOneWidget);

      // Tap on 'Terang' mode
      final lightOption = find.text('Terang');
      await tester.tap(lightOption);
      await tester.pumpAndSettle();

      expect(service.themeMode, ThemeMode.light);
      expect(find.text('Mode Terang diaktifkan'), findsOneWidget);

      // Check preset names
      expect(find.text('Biru Langit (Default)'), findsWidgets);
      expect(find.text('Hijau Zamrud'), findsOneWidget);
      expect(find.text('Royal Indigo'), findsOneWidget);

      // Tap on Hijau Zamrud preset
      final hijauZamrud = find.text('Hijau Zamrud');
      await tester.ensureVisible(hijauZamrud);
      await tester.tap(hijauZamrud);
      await tester.pumpAndSettle();

      // Verify theme service updated
      expect(service.activePresetId, 'emerald_green');
      expect(find.text('Tema diubah ke Hijau Zamrud'), findsOneWidget);

      // Tap reset button
      final resetButton = find.text('Kembalikan ke Tema Standar (Biru Langit)');
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      // Verify reset back to sky_blue
      expect(service.activePresetId, 'sky_blue');
      expect(find.text('Tema berhasil dikembalikan ke standar Biru Langit'), findsOneWidget);
    });

    testWidgets('AccountScreen tablet sidebar selected menu color matches active theme', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = ThemeService();
      await service.init();
      await service.resetToDefault(); // sky_blue -> accent is 0xFF0EA5E9

      final repository = BookingRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          onGenerateRoute: (settings) =>
              AppRoutes.onGenerateRoute(settings, repository),
          home: AccountScreen(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Find the selected menu item container (default is 'shopSettings' -> 'Pengaturan Nama Toko & Outlet')
      final selectedItemFinder = find.ancestor(
        of: find.text('Pengaturan Nama Toko & Outlet'),
        matching: find.byType(Container),
      );

      // Verify the decoration color of the selected menu item matches AppTheme.accent (0xFF0EA5E9)
      final containers = tester.widgetList<Container>(selectedItemFinder);
      final selectedContainer = containers.firstWhere(
        (c) => (c.decoration as BoxDecoration?)?.color == const Color(0xFF0EA5E9),
      );
      expect((selectedContainer.decoration as BoxDecoration).color, const Color(0xFF0EA5E9));

      // Switch to emerald_green theme
      await service.setPreset('emerald_green');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Verify the selected menu item color dynamically updated to emerald_green accent (0xFF10B981)
      final updatedContainers = tester.widgetList<Container>(selectedItemFinder);
      final updatedContainer = updatedContainers.firstWhere(
        (c) => (c.decoration as BoxDecoration?)?.color == const Color(0xFF10B981),
      );
      expect((updatedContainer.decoration as BoxDecoration).color, const Color(0xFF10B981));
    });
  });
}
