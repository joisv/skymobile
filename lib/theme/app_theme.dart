import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AppTheme {
  // Default Static Fallbacks
  static const Color defaultPrimary = Color(0xFF0F172A); // Solid Navy / Slate 900
  static const Color defaultPrimaryDark = Color(0xFF0B1C30); // On Surface / Dark
  static const Color defaultAccent = Color(0xFF0EA5E9); // Sky Blue 500
  static const Color defaultAccentLight = Color(0xFFEFF4FF);

  // Dynamic Stitch Primary & Brand Colors (terhubung langsung ke ThemeService)
  static Color get primary => ThemeService().primaryColor;
  static Color get primaryDark => ThemeService().primaryDarkColor;
  static Color get primaryContainer => ThemeService().primaryColor;
  static Color get brandBlue => ThemeService().accentColor;
  static Color get accent => ThemeService().accentColor;
  static Color get secondary => ThemeService().accentColor;
  static Color get secondaryContainer => ThemeService().accentLightColor;
  static Color get accentLight => ThemeService().accentLightColor;

  // Neutral & Surfaces (Dynamic based on ThemeService dark mode)
  static Color get background => ThemeService().isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFF8F9FF);
  static Color get surface => ThemeService().isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  static Color get surfaceContainerLow => ThemeService().accentLightColor;
  static Color get surfaceContainer => ThemeService().isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5EEFF);
  static Color get surfaceContainerHigh => ThemeService().isDarkMode ? const Color(0xFF475569) : const Color(0xFFDCE9FF);
  static Color get cardBorder => ThemeService().isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  static Color get outline => ThemeService().isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

  // Text Colors (Dynamic based on ThemeService dark mode)
  static Color get textPrimary => ThemeService().isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0B1C30);
  static Color get textSecondary => ThemeService().isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textMuted => ThemeService().isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Status & Feedback Tokens (Stitch Tokens)
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successContainer = Color(0xFFECFDF5);
  static const Color onSuccessContainer = Color(0xFF047857);
  static const Color successBorder = Color(0xFFA7F3D0);

  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningContainer = Color(0xFFFFFBEB);
  static const Color onWarningContainer = Color(0xFFB45309);
  static const Color warningBorder = Color(0xFFFDE68A);

  static const Color error = Color(0xFFEF4444); // Rose / Red
  static const Color errorContainer = Color(0xFFFEF2F2);
  static const Color onErrorContainer = Color(0xFFB91C1C);
  static const Color errorBorder = Color(0xFFFECACA);

  static const Color infoContainer = Color(0xFFEFF6FF);
  static const Color onInfoContainer = Color(0xFF1D4ED8);
  static const Color infoBorder = Color(0xFFBFDBFE);

  // Legacy Status Badges mapping for backward compatibility
  static const Color statusPendingText = onWarningContainer;
  static const Color statusPendingBg = warningContainer;

  static const Color statusConfirmedText = onSuccessContainer;
  static const Color statusConfirmedBg = successContainer;

  static const Color statusRentedText = onInfoContainer;
  static const Color statusRentedBg = infoContainer;

  static const Color statusReturnedText = Color(0xFF475569);
  static const Color statusReturnedBg = Color(0xFFF1F5F9);

  static const Color statusCancelledText = onErrorContainer;
  static const Color statusCancelledBg = errorContainer;

  static ThemeData get lightTheme {
    return buildTheme(
      primary: primary,
      accent: accent,
      accentLight: accentLight,
      primaryDark: primaryDark,
    );
  }

  static ThemeData get darkTheme {
    return buildDarkTheme(
      primary: primary,
      accent: accent,
      accentLight: accentLight,
      primaryDark: primaryDark,
    );
  }

  static ThemeData buildTheme({
    required Color primary,
    required Color accent,
    Color? accentLight,
    Color? primaryDark,
  }) {
    final lightAccent = accentLight ?? accent.withValues(alpha: 0.12);
    final darkPrimary = primaryDark ?? primary;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        primaryContainer: darkPrimary,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightAccent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(color: textMuted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: cardBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      fontFamily: 'Inter',
    );
  }

  static ThemeData buildDarkTheme({
    required Color primary,
    required Color accent,
    Color? accentLight,
    Color? primaryDark,
  }) {
    const darkBackground = Color(0xFF0B1120); // Slate 950 / Deep Slate
    const darkSurface = Color(0xFF1E293B);    // Slate 800
    const darkBorder = Color(0xFF334155);     // Slate 700
    const darkTextPrimary = Color(0xFFF8FAFC);// Near white
    const darkTextSecondary = Color(0xFF94A3B8); // Slate 400
    const darkTextMuted = Color(0xFF64748B);     // Slate 500

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: darkSurface,
        error: error,
        primaryContainer: primary,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextSecondary),
        bodySmall: TextStyle(color: darkTextMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: darkTextMuted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
      ),
      fontFamily: 'Inter',
    );
  }
}
