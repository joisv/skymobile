import 'package:flutter/foundation.dart';

/// Centralized Environment-Based API Configuration for SkyMobile.
///
/// Supports compile-time environment configuration via Flutter `--dart-define`:
/// - `flutter run --dart-define=API_BASE_URL=http://192.168.1.93:8000/api/v1`
/// - `flutter run --dart-define=API_URL=http://localhost:8000`
///
/// Safety Guarantees:
/// 1. Default release builds ALWAYS resolve to the official HTTPS production domain.
/// 2. Release builds strictly reject localhost, loopback, or private development IPs.
/// 3. Local development URLs are only used when explicitly supplied during debugging.
class ApiConfig {
  ApiConfig._();

  /// Official HTTPS production API base URL
  static const String defaultProductionBaseUrl = 'https://skyrental.id/api/v1';

  /// Compile-time environment override via `--dart-define`
  /// Checks `API_BASE_URL` first, then falls back to `API_URL`.
  static const String _dartDefineUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment('API_URL', defaultValue: ''),
  );

  /// Determine if a URL is a localhost, loopback, or private LAN address
  static bool isLocalOrPrivateUrl(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.isEmpty) return false;

    // Check scheme: cleartext http is typically local/development
    final uri = Uri.tryParse(lower);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '10.0.2.2' || // Android emulator host loopback
        host == '10.0.3.2' || // Genymotion emulator loopback
        host.endsWith('.local') ||
        host.endsWith('.test') ||
        host.endsWith('.lan')) {
      return true;
    }

    // Check private IPv4 ranges (10.x.x.x, 172.16-31.x.x, 192.168.x.x, 127.x.x.x)
    final ipv4Parts = host.split('.');
    if (ipv4Parts.length == 4) {
      final p0 = int.tryParse(ipv4Parts[0]);
      final p1 = int.tryParse(ipv4Parts[1]);
      if (p0 != null && p1 != null) {
        if (p0 == 10) return true;
        if (p0 == 192 && p1 == 168) return true;
        if (p0 == 172 && p1 >= 16 && p1 <= 31) return true;
        if (p0 == 127) return true;
      }
    }

    // Non-secure HTTP scheme is treated as development/local
    if (uri.scheme == 'http') {
      return true;
    }

    return false;
  }

  /// Normalize any incoming URL to ensure correct scheme and trailing `/api/v1` path
  static String normalizeBaseUrl(String inputUrl) {
    String clean = inputUrl.trim();
    if (clean.isEmpty) return defaultProductionBaseUrl;

    // Default scheme to http:// if missing and appears to be IP/port, otherwise https://
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      final isIpOrLocal = clean.contains(':') ||
          clean.startsWith('192.') ||
          clean.startsWith('10.') ||
          clean.startsWith('127.') ||
          clean.startsWith('localhost');
      clean = isIpOrLocal ? 'http://$clean' : 'https://$clean';
    }

    // Clean trailing slashes
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }

    // Ensure ending with /api/v1
    if (!clean.endsWith('/api/v1')) {
      if (clean.endsWith('/api')) {
        clean = '$clean/v1';
      } else {
        clean = '$clean/api/v1';
      }
    }

    return clean;
  }

  /// Extracts the origin/host part (scheme + host + optional port) without `/api/v1`
  static String getBackendHost(String fullApiUrl) {
    final clean = fullApiUrl.trim().replaceAll(RegExp(r'/api/v1/?$'), '');
    return clean.isEmpty ? 'https://skyrental.id' : clean;
  }

  /// Extracts the base public storage URL
  static String getStorageBaseUrl(String fullApiUrl) {
    final host = getBackendHost(fullApiUrl);
    return '$host/storage';
  }

  /// Resolves the effective base URL for the current runtime environment.
  ///
  /// Rules:
  /// - Release Mode (`kReleaseMode`):
  ///   Must default to `defaultProductionBaseUrl`.
  ///   If an explicit `--dart-define` is supplied, it is ONLY accepted if it is a secure HTTPS production URL
  ///   (never localhost or private LAN IP).
  /// - Debug / Profile Mode:
  ///   If `--dart-define` is supplied, normalizes and uses it.
  ///   Otherwise, defaults to `defaultProductionBaseUrl`.
  static String resolveInitialBaseUrl() {
    if (kReleaseMode) {
      // Release mode: strictly enforce production domain safety
      if (_dartDefineUrl.trim().isNotEmpty) {
        final normalized = normalizeBaseUrl(_dartDefineUrl);
        if (!isLocalOrPrivateUrl(normalized) && normalized.startsWith('https://')) {
          return normalized;
        }
        // If release was passed a local/private URL, reject it and fallback to official production URL
        debugPrint('[ApiConfig] WARNING: Local/private URL ignored in release build. Defaulting to production HTTPS.');
        return defaultProductionBaseUrl;
      }
      return defaultProductionBaseUrl;
    }

    // Debug / Profile mode:
    if (_dartDefineUrl.trim().isNotEmpty) {
      return normalizeBaseUrl(_dartDefineUrl);
    }

    // Default when no --dart-define is supplied
    return defaultProductionBaseUrl;
  }

  /// Helper for unit testing environment resolution logic with simulated release mode and input URL
  @visibleForTesting
  static String resolveBaseUrlForTesting({
    required bool isReleaseMode,
    String? explicitDartDefine,
  }) {
    final rawInput = explicitDartDefine ?? _dartDefineUrl;
    if (isReleaseMode) {
      if (rawInput.trim().isNotEmpty) {
        final normalized = normalizeBaseUrl(rawInput);
        if (!isLocalOrPrivateUrl(normalized) && normalized.startsWith('https://')) {
          return normalized;
        }
        return defaultProductionBaseUrl;
      }
      return defaultProductionBaseUrl;
    }

    if (rawInput.trim().isNotEmpty) {
      return normalizeBaseUrl(rawInput);
    }
    return defaultProductionBaseUrl;
  }

  /// Whether compile-time --dart-define was explicitly provided
  static bool get hasDartDefineUrl => _dartDefineUrl.trim().isNotEmpty;

  /// Returns the compile-time --dart-define URL if provided
  static String? get dartDefineUrl => hasDartDefineUrl ? normalizeBaseUrl(_dartDefineUrl) : null;
}
