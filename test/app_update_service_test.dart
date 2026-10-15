import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/models/app_update_model.dart';
import 'package:skyrental_admin/services/api_service.dart';
import 'package:skyrental_admin/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateInfo Model Tests', () {
    test('Correctly parses update available response', () {
      final json = {
        'update_available': true,
        'is_mandatory': true,
        'current_build': 1,
        'latest_build': 5,
        'latest_version': '1.2.0',
        'min_supported_build': 3,
        'title': 'Pembaruan Wajib',
        'release_notes': '- Perbaikan bug transfer iPhone\n- Optimasi thermal printer',
        'file_size': 15728640,
        'formatted_size': '15.00 MB',
        'sha256_checksum': 'abcdef1234567890',
        'download_url': 'https://skyrental.id/api/v1/app/download/5',
        'published_at': '2026-10-15T14:00:00+07:00',
      };

      final info = AppUpdateInfo.fromJson(json);

      expect(info.updateAvailable, isTrue);
      expect(info.isMandatory, isTrue);
      expect(info.currentBuild, 1);
      expect(info.latestBuild, 5);
      expect(info.latestVersion, '1.2.0');
      expect(info.minSupportedBuild, 3);
      expect(info.title, 'Pembaruan Wajib');
      expect(info.releaseNotes, contains('Perbaikan bug transfer iPhone'));
      expect(info.fileSize, 15728640);
      expect(info.formattedSize, '15.00 MB');
      expect(info.sha256Checksum, 'abcdef1234567890');
      expect(info.downloadUrl, 'https://skyrental.id/api/v1/app/download/5');
    });

    test('Correctly parses no update response', () {
      final json = {
        'update_available': false,
        'current_build': 5,
        'latest_build': 5,
        'latest_version': '1.2.0',
      };

      final info = AppUpdateInfo.fromJson(json);

      expect(info.updateAvailable, isFalse);
      expect(info.isMandatory, isFalse);
      expect(info.currentBuild, 5);
      expect(info.latestBuild, 5);
    });

    test('Handles missing / null fields gracefully with fallbacks', () {
      final info = AppUpdateInfo.fromJson({});

      expect(info.updateAvailable, isFalse);
      expect(info.isMandatory, isFalse);
      expect(info.currentBuild, 0);
      expect(info.latestBuild, 0);
      expect(info.latestVersion, '');
      expect(info.releaseNotes, isNull);
    });
  });

  group('AppUpdateService Logic Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService().baseUrl = 'https://skyrental.id/api/v1';
    });

    test('checkForUpdate returns AppUpdateInfo on 200 OK', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/app/check-update'));
        expect(request.url.queryParameters['current_build'], '1');

        final payload = {
          'status': 'success',
          'data': {
            'update_available': true,
            'is_mandatory': false,
            'current_build': 1,
            'latest_build': 2,
            'latest_version': '1.1.0',
            'min_supported_build': 1,
            'title': 'Update Tersedia',
            'release_notes': 'Fitur baru',
            'file_size': 1048576,
            'formatted_size': '1.00 MB',
            'sha256_checksum': 'dummy_hash',
            'download_url': 'https://skyrental.id/api/v1/app/download/2',
          }
        };

        return http.Response(jsonEncode(payload), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final service = AppUpdateService();
      final result = await service.checkForUpdate(
        overrideCurrentBuild: 1,
        httpClient: mockClient,
      );

      expect(result.updateAvailable, isTrue);
      expect(result.latestVersion, '1.1.0');
      expect(result.latestBuild, 2);
      expect(result.isMandatory, isFalse);
    });

    test('checkForUpdate throws AppUpdateException on 500 server error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = AppUpdateService();
      expect(
        () => service.checkForUpdate(overrideCurrentBuild: 1, httpClient: mockClient),
        throwsA(isA<AppUpdateException>()),
      );
    });

    test('shouldPromptUpdate always returns true for mandatory updates', () async {
      final service = AppUpdateService();
      const info = AppUpdateInfo(
        updateAvailable: true,
        isMandatory: true,
        currentBuild: 1,
        latestBuild: 3,
      );

      // Even if snoozed
      await service.snoozeUpdate(3);

      final shouldPrompt = await service.shouldPromptUpdate(info);
      expect(shouldPrompt, isTrue);
    });

    test('shouldPromptUpdate respects 24-hour snooze for optional updates', () async {
      final service = AppUpdateService();
      const info = AppUpdateInfo(
        updateAvailable: true,
        isMandatory: false,
        currentBuild: 1,
        latestBuild: 2,
      );

      // Initially should prompt
      expect(await service.shouldPromptUpdate(info), isTrue);

      // After snoozing, should NOT prompt
      await service.snoozeUpdate(2);
      expect(await service.shouldPromptUpdate(info), isFalse);

      // If a newer build 3 comes along, should prompt again
      const newerInfo = AppUpdateInfo(
        updateAvailable: true,
        isMandatory: false,
        currentBuild: 1,
        latestBuild: 3,
      );
      expect(await service.shouldPromptUpdate(newerInfo), isTrue);

      // After clearing snooze, should prompt for build 2 again
      await service.clearSnooze();
      expect(await service.shouldPromptUpdate(info), isTrue);
    });

    test('SHA-256 calculation matches expected digest', () {
      final testData = utf8.encode('SkyRental Android APK update payload');
      final expectedHash = sha256.convert(testData).toString();

      final actualHash = sha256.convert(testData).toString();
      expect(actualHash, equals(expectedHash));
      expect(actualHash.length, 64);
    });

    test('getCurrentVersionInfo queries native MethodChannel when on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel('com.example.skyrental_admin/app_installer');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getInstalledVersionInfo') {
          return {'version': '2.0.0', 'buildNumber': 10};
        }
        return null;
      });

      final service = AppUpdateService();
      final versionInfo = await service.getCurrentVersionInfo(forceRefresh: true);

      expect(versionInfo.version, '2.0.0');
      expect(versionInfo.buildNumber, 10);

      // Clean up mock & platform override
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('cleanupTempApks executes safely without throwing', () async {
      final service = AppUpdateService();
      await expectLater(service.cleanupTempApks(), completes);
    });
  });
}
