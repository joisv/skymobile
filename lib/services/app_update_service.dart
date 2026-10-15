import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update_model.dart';
import 'api_service.dart';

class AppUpdateException implements Exception {
  final String message;
  AppUpdateException(this.message);

  @override
  String toString() => message;
}

class AppUpdateVerificationException extends AppUpdateException {
  AppUpdateVerificationException(super.message);
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  static const MethodChannel _installerChannel =
      MethodChannel('com.example.skyrental_admin/app_installer');

  static const String _prefKeySnoozedBuild = 'update_snoozed_build';
  static const String _prefKeySnoozedTime = 'update_snoozed_time';

  /// Get current application package version & build number.
  /// If [forceRefresh] is true or on Android, it queries the native Android
  /// PackageManager via MethodChannel to bypass static memory caching in package_info_plus.
  Future<({String version, int buildNumber})> getCurrentVersionInfo({
    bool forceRefresh = false,
  }) async {
    // If on Android or test environment mimicking Android, query native PackageManager directly
    if (defaultTargetPlatform == TargetPlatform.android || (!kIsWeb && Platform.isAndroid)) {
      try {
        final dynamic rawInfo =
            await _installerChannel.invokeMethod('getInstalledVersionInfo');
        if (rawInfo is Map) {
          final version = rawInfo['version']?.toString() ?? '1.0.0';
          final build = rawInfo['buildNumber'] is num
              ? (rawInfo['buildNumber'] as num).toInt()
              : int.tryParse(rawInfo['buildNumber']?.toString() ?? '0') ?? 0;
          return (version: version, buildNumber: build);
        }
      } on MissingPluginException {
        // Fallback to PackageInfo in test/non-Android environments
      } catch (e) {
        debugPrint('Notice: Native getInstalledVersionInfo error: $e');
      }
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final build = int.tryParse(packageInfo.buildNumber) ?? 0;
      return (version: packageInfo.version, buildNumber: build);
    } catch (e) {
      debugPrint('Error getting package info: $e');
      return (version: '1.0.0', buildNumber: 0);
    }
  }

  /// Delete any cached update APK files in temporary directory
  Future<void> cleanupTempApks() async {
    try {
      final tempDir = await getTemporaryDirectory().timeout(const Duration(seconds: 3));
      final updateDir = Directory('${tempDir.path}/updates');
      if (await updateDir.exists()) {
        final files = updateDir.listSync();
        for (final file in files) {
          if (file is File && file.path.endsWith('.apk')) {
            try {
              file.deleteSync();
            } catch (e) {
              debugPrint('Notice: Could not delete temp apk ${file.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Notice: Error cleaning temp APKs: $e');
    }
  }

  /// Check if an update is available on the server
  Future<AppUpdateInfo> checkForUpdate({
    int? overrideCurrentBuild,
    http.Client? httpClient,
    bool forceRefreshVersion = false,
  }) async {
    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;

    try {
      final currentBuild = overrideCurrentBuild ??
          (await getCurrentVersionInfo(forceRefresh: forceRefreshVersion)).buildNumber;
      final baseUrl = ApiService().baseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseUrl/app/check-update?current_build=$currentBuild');

      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (ApiService().authToken != null) {
        headers['Authorization'] = 'Bearer ${ApiService().authToken}';
      }

      final response = await client.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'success') {
          final data = body['data'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(body['data'] as Map)
              : <String, dynamic>{};

          // Fallback to top-level properties if not present in data
          data['update_available'] = data['update_available'] ??
              body['update_available'] ??
              body['has_update'] ??
              data['has_update'] ??
              false;
          data['is_mandatory'] = data['is_mandatory'] ?? body['is_mandatory'] ?? false;
          data['current_build'] = data['current_build'] ?? body['current_build'] ?? currentBuild;
          data['message'] = data['message'] ?? body['message'];

          final info = AppUpdateInfo.fromJson(data);
          debugPrint(
            'AppUpdateService: check-update response status=${response.statusCode}, '
            'updateAvailable=${info.updateAvailable}, currentBuild=$currentBuild, latestBuild=${info.latestBuild}',
          );
          return info;
        } else {
          return AppUpdateInfo(
            updateAvailable: false,
            currentBuild: currentBuild,
            message: body['message'] as String? ?? 'Respon server tidak valid.',
          );
        }
      } else {
        throw AppUpdateException('Gagal memeriksa pembaruan (HTTP ${response.statusCode})');
      }
    } catch (e) {
      if (e is AppUpdateException) rethrow;
      throw AppUpdateException('Terjadi kendala saat menghubungi server pembaruan: $e');
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  /// Determines if user should be prompted automatically on launch
  Future<bool> shouldPromptUpdate(AppUpdateInfo info) async {
    if (!info.updateAvailable) return false;

    // Mandatory updates must never be snoozed
    if (info.isMandatory) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final snoozedBuild = prefs.getInt(_prefKeySnoozedBuild);
      final snoozedTime = prefs.getInt(_prefKeySnoozedTime);

      if (snoozedBuild == info.latestBuild && snoozedTime != null) {
        final lastSnoozedDate = DateTime.fromMillisecondsSinceEpoch(snoozedTime);
        final elapsed = DateTime.now().difference(lastSnoozedDate);
        // Snooze for 24 hours
        if (elapsed.inHours < 24) {
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error reading snooze preference: $e');
    }

    return true;
  }

  /// Snooze an optional update prompt for 24 hours
  Future<void> snoozeUpdate(int buildNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKeySnoozedBuild, buildNumber);
      await prefs.setInt(_prefKeySnoozedTime, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving snooze preference: $e');
    }
  }

  /// Reset snooze preferences
  Future<void> clearSnooze() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeySnoozedBuild);
      await prefs.remove(_prefKeySnoozedTime);
    } catch (e) {
      debugPrint('Error clearing snooze preference: $e');
    }
  }

  /// Check if the app has permission to install unknown apps (Android 8.0+)
  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? canInstall =
          await _installerChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return canInstall ?? true;
    } on PlatformException catch (e) {
      debugPrint('PlatformException checking package install permission: ${e.message}');
      return true;
    } catch (e) {
      debugPrint('Error checking package install permission: $e');
      return true;
    }
  }

  /// Open Android system settings to grant "Install Unknown Apps" permission
  Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? result =
          await _installerChannel.invokeMethod<bool>('openInstallPermissionSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('PlatformException opening install settings: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error opening install settings: $e');
      return false;
    }
  }

  /// Download APK with streaming progress and verify SHA-256 checksum
  Future<File> downloadAndVerifyApk(
    AppUpdateInfo updateInfo, {
    void Function(int received, int total, double progress)? onProgress,
    http.Client? httpClient,
  }) async {
    if (updateInfo.downloadUrl == null || updateInfo.downloadUrl!.isEmpty) {
      throw AppUpdateException('URL unduhan APK tidak valid.');
    }

    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;

    try {
      final tempDir = await getTemporaryDirectory();
      final updateDir = Directory('${tempDir.path}/updates');
      if (!await updateDir.exists()) {
        await updateDir.create(recursive: true);
      }

      // Clean up previous APK files in the directory to save space
      try {
        final existingFiles = updateDir.listSync();
        for (final file in existingFiles) {
          if (file is File && file.path.endsWith('.apk')) {
            file.deleteSync();
          }
        }
      } catch (e) {
        debugPrint('Notice: Error cleaning old updates: $e');
      }

      final fileName =
          'skymobile_v${updateInfo.latestVersion}_${updateInfo.latestBuild}.apk';
      final apkFile = File('${updateDir.path}/$fileName');

      final downloadUrlString = updateInfo.downloadUrl ?? '';
      final baseUrl = ApiService().baseUrl.replaceAll(RegExp(r'/+$'), '');
      final resolvedUri = (downloadUrlString.isEmpty ||
              downloadUrlString.contains('localhost') ||
              downloadUrlString.contains('127.0.0.1'))
          ? Uri.parse('$baseUrl/app/download/${updateInfo.latestBuild}')
          : Uri.parse(downloadUrlString);

      final request = http.Request('GET', resolvedUri);
      request.headers['Accept'] = 'application/octet-stream';
      if (ApiService().authToken != null) {
        request.headers['Authorization'] = 'Bearer ${ApiService().authToken}';
      }

      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppUpdateException('Unduhan gagal dengan status kode ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? updateInfo.fileSize;
      int receivedBytes = 0;

      final sink = apkFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (onProgress != null) {
            final progress = totalBytes > 0
                ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
                : 0.0;
            onProgress(receivedBytes, totalBytes, progress);
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      // Verify SHA-256 Checksum if provided
      if (updateInfo.sha256Checksum != null &&
          updateInfo.sha256Checksum!.trim().isNotEmpty) {
        final expectedHash = updateInfo.sha256Checksum!.trim().toLowerCase();
        final digest = await sha256.bind(apkFile.openRead()).first;
        final calculatedHash = digest.toString().toLowerCase();

        if (calculatedHash != expectedHash) {
          try {
            await apkFile.delete();
          } catch (_) {}
          throw AppUpdateVerificationException(
            'Integritas berkas APK gagal (SHA-256 mismatch).\n'
            'Diharapkan: $expectedHash\n'
            'Didapat: $calculatedHash',
          );
        }
      }

      return apkFile;
    } catch (e) {
      if (e is AppUpdateException) rethrow;
      throw AppUpdateException('Gagal mengunduh berkas APK: $e');
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  /// Launch Android Package Installer for the downloaded APK file
  Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      throw AppUpdateException('Instalasi APK hanya didukung pada sistem Android.');
    }

    try {
      final bool? result = await _installerChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw AppUpdateException('Gagal memasang APK: ${e.message}');
    } catch (e) {
      throw AppUpdateException('Terjadi kendala saat membuka penginstal sistem: $e');
    }
  }
}
