import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme_model.dart';
import '../theme/app_theme.dart';

/// Service pengelolaan tema dan warna aplikasi secara dinamis & persisten.
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _keyPresetId = 'theme_preset_id';
  static const String _keyIsCustom = 'theme_is_custom';
  static const String _keyCustomPrimary = 'theme_custom_primary';
  static const String _keyCustomAccent = 'theme_custom_accent';
  static const String _keyCustomAccentLight = 'theme_custom_accent_light';
  static const String _keyThemeMode = 'theme_mode_setting';

  String _activePresetId = 'sky_blue';
  bool _isCustom = false;
  Color _customPrimary = const Color(0xFF0F172A);
  Color _customAccent = const Color(0xFF0EA5E9);
  Color _customAccentLight = const Color(0xFFEFF6FF);
  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  String get activePresetId => _activePresetId;
  bool get isCustom => _isCustom;
  ThemeMode get themeMode => _themeMode;

  /// Status apakah aplikasi sedang dalam mode gelap
  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    try {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    } catch (_) {
      return false;
    }
  }

  /// Preset aktif saat ini
  AppThemePreset get currentPreset => AppThemePreset.getById(_activePresetId);

  /// Warna primary aktif
  Color get primaryColor => _isCustom ? _customPrimary : currentPreset.primary;

  /// Warna accent/sekunder aktif
  Color get accentColor => _isCustom ? _customAccent : currentPreset.accent;

  /// Warna accentLight aktif untuk latar kartu/badge
  Color get accentLightColor => _isCustom ? _customAccentLight : currentPreset.accentLight;

  /// Warna primaryDark aktif
  Color get primaryDarkColor => _isCustom ? _customPrimary : currentPreset.primaryDark;

  /// Objek ThemeData untuk mode terang
  ThemeData get lightTheme => AppTheme.buildTheme(
        primary: primaryColor,
        accent: accentColor,
        accentLight: accentLightColor,
        primaryDark: primaryDarkColor,
      );

  /// Objek ThemeData untuk mode gelap
  ThemeData get darkTheme => AppTheme.buildDarkTheme(
        primary: primaryColor,
        accent: accentColor,
        accentLight: accentLightColor,
        primaryDark: primaryDarkColor,
      );

  /// Objek ThemeData aktif yang siap disematkan pada MaterialApp
  ThemeData get themeData => isDarkMode ? darkTheme : lightTheme;

  /// Inisialisasi service dan membaca pengaturan tema dari SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isCustom = prefs.getBool(_keyIsCustom) ?? false;
      _activePresetId = prefs.getString(_keyPresetId) ?? 'sky_blue';

      final modeStr = prefs.getString(_keyThemeMode);
      if (modeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (modeStr == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.light;
      }

      if (_isCustom) {
        final primaryVal = prefs.getInt(_keyCustomPrimary);
        final accentVal = prefs.getInt(_keyCustomAccent);
        final accentLightVal = prefs.getInt(_keyCustomAccentLight);

        if (primaryVal != null) _customPrimary = Color(primaryVal);
        if (accentVal != null) _customAccent = Color(accentVal);
        if (accentLightVal != null) {
          _customAccentLight = Color(accentLightVal);
        } else {
          _customAccentLight = _customAccent.withValues(alpha: 0.12);
        }
      }
    } catch (_) {
      // Fallback ke tema default jika terjadi kendala membaca storage
      _activePresetId = 'sky_blue';
      _isCustom = false;
      _themeMode = ThemeMode.light;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Ganti mode tampilan (Terang / Gelap / Sistem)
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      if (mode == ThemeMode.system) val = 'system';
      await prefs.setString(_keyThemeMode, val);
    } catch (_) {}
  }

  /// Terapkan salah satu preset tema bawaan
  Future<void> setPreset(String presetId) async {
    _activePresetId = presetId;
    _isCustom = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPresetId, presetId);
      await prefs.setBool(_keyIsCustom, false);
    } catch (_) {}
  }

  /// Terapkan warna kustom mandiri pilihan pengguna
  Future<void> setCustomColors({
    required Color primary,
    required Color accent,
    Color? accentLight,
  }) async {
    _isCustom = true;
    _activePresetId = 'custom';
    _customPrimary = primary;
    _customAccent = accent;
    _customAccentLight = accentLight ?? accent.withValues(alpha: 0.12);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsCustom, true);
      await prefs.setString(_keyPresetId, 'custom');
      await prefs.setInt(_keyCustomPrimary, _customPrimary.toARGB32());
      await prefs.setInt(_keyCustomAccent, _customAccent.toARGB32());
      await prefs.setInt(_keyCustomAccentLight, _customAccentLight.toARGB32());
    } catch (_) {}
  }

  /// Reset tema kembali ke standar Biru Langit (Sky Blue)
  Future<void> resetToDefault() async {
    await setPreset('sky_blue');
  }

  /// Helper untuk pengujian (Testing)
  @visibleForTesting
  void setValuesForTesting({
    required String presetId,
    bool isCustom = false,
    Color? primary,
    Color? accent,
    Color? accentLight,
    ThemeMode? themeMode,
  }) {
    _activePresetId = presetId;
    _isCustom = isCustom;
    if (primary != null) _customPrimary = primary;
    if (accent != null) _customAccent = accent;
    if (accentLight != null) _customAccentLight = accentLight;
    if (themeMode != null) _themeMode = themeMode;
    _isInitialized = true;
    notifyListeners();
  }
}
