import 'package:flutter/material.dart';

/// Model preset tema warna aplikasi SKYRental Admin.
class AppThemePreset {
  final String id;
  final String name;
  final String description;
  final Color primary;
  final Color accent;
  final Color accentLight;
  final Color primaryDark;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.accent,
    required this.accentLight,
    Color? primaryDark,
  }) : primaryDark = primaryDark ?? primary;

  /// Daftar preset warna bawaan profesional
  static const List<AppThemePreset> defaultPresets = [
    AppThemePreset(
      id: 'sky_blue',
      name: 'Biru Langit (Default)',
      description: 'Nuansa modern, bersih, dan profesional khas SKYRental',
      primary: Color(0xFF0F172A), // Slate 900
      accent: Color(0xFF0EA5E9), // Sky Blue 500
      accentLight: Color(0xFFEFF6FF), // Blue 50
      primaryDark: Color(0xFF0B1C30),
    ),
    AppThemePreset(
      id: 'royal_indigo',
      name: 'Royal Indigo',
      description: 'Kesan mewah, premium, dan berwibawa dengan aksen indigo',
      primary: Color(0xFF1E1B4B), // Indigo 950
      accent: Color(0xFF4F46E5), // Indigo 600
      accentLight: Color(0xFFEEF2FF), // Indigo 50
      primaryDark: Color(0xFF13103A),
    ),
    AppThemePreset(
      id: 'emerald_green',
      name: 'Hijau Zamrud',
      description: 'Segar, elegan, dan menenangkan dengan aksen emerald alami',
      primary: Color(0xFF064E3B), // Emerald 900
      accent: Color(0xFF10B981), // Emerald 500
      accentLight: Color(0xFFECFDF5), // Emerald 50
      primaryDark: Color(0xFF022C22),
    ),
    AppThemePreset(
      id: 'sunset_amber',
      name: 'Oranye Sunset',
      description: 'Hangat, dinamis, energik, dan penuh semangat operasional',
      primary: Color(0xFF78350F), // Amber 900
      accent: Color(0xFFF59E0B), // Amber 500
      accentLight: Color(0xFFFFFBEB), // Amber 50
      primaryDark: Color(0xFF451A03),
    ),
    AppThemePreset(
      id: 'crimson_ruby',
      name: 'Merah Ruby',
      description: 'Berani, percaya diri, eksklusif, dan memiliki daya tarik kuat',
      primary: Color(0xFF881337), // Rose 900
      accent: Color(0xFFE11D48), // Rose 600
      accentLight: Color(0xFFFFF1F2), // Rose 50
      primaryDark: Color(0xFF4C0519),
    ),
    AppThemePreset(
      id: 'royal_purple',
      name: 'Ungu Lavender',
      description: 'Artistik, futuristik, kreatif, dan elegan dalam setiap sudut',
      primary: Color(0xFF581C87), // Purple 900
      accent: Color(0xFF8B5CF6), // Purple 500
      accentLight: Color(0xFFF5F3FF), // Purple 50
      primaryDark: Color(0xFF3B0764),
    ),
    AppThemePreset(
      id: 'midnight_teal',
      name: 'Midnight Teal',
      description: 'Kombinasi modern bernuansa samudera dalam dan teal cerah',
      primary: Color(0xFF134E4A), // Teal 900
      accent: Color(0xFF14B8A6), // Teal 500
      accentLight: Color(0xFFF0FDFA), // Teal 50
      primaryDark: Color(0xFF042F2E),
    ),
    AppThemePreset(
      id: 'slate_monochrome',
      name: 'Slate Monokrom',
      description: 'Minimalis, simpel, berkelas dengan paduan abu-abu gelap',
      primary: Color(0xFF18181B), // Zinc 900
      accent: Color(0xFF64748B), // Slate 500
      accentLight: Color(0xFFF1F5F9), // Slate 100
      primaryDark: Color(0xFF09090B),
    ),
  ];

  /// Ambil preset berdasarkan ID, kembalikan default jika tidak ditemukan
  static AppThemePreset getById(String id) {
    return defaultPresets.firstWhere(
      (p) => p.id == id,
      orElse: () => defaultPresets.first,
    );
  }
}
