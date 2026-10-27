import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/config/api_config.dart';
import 'package:skyrental_admin/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiConfig Environment-Based Configuration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Scenario 1: Default production base URL is valid HTTPS domain', () {
      expect(ApiConfig.defaultProductionBaseUrl, 'https://skyrental.id/api/v1');
      expect(ApiConfig.isLocalOrPrivateUrl(ApiConfig.defaultProductionBaseUrl), isFalse);
    });

    test('Scenario 2: Normalizes diverse URL formats correctly', () {
      // Missing protocol and api/v1
      expect(
        ApiConfig.normalizeBaseUrl('192.168.1.93:8000'),
        'http://192.168.1.93:8000/api/v1',
      );

      // Trailing slashes
      expect(
        ApiConfig.normalizeBaseUrl('http://localhost:8000///'),
        'http://localhost:8000/api/v1',
      );

      // Already has /api
      expect(
        ApiConfig.normalizeBaseUrl('http://10.0.2.2:8000/api'),
        'http://10.0.2.2:8000/api/v1',
      );

      // Already fully qualified
      expect(
        ApiConfig.normalizeBaseUrl('http://127.0.0.1:8000/api/v1'),
        'http://127.0.0.1:8000/api/v1',
      );

      // Public domain
      expect(
        ApiConfig.normalizeBaseUrl('https://skyrental.id'),
        'https://skyrental.id/api/v1',
      );
    });

    test('Scenario 3: Correctly identifies local and private development URLs', () {
      expect(ApiConfig.isLocalOrPrivateUrl('http://localhost:8000/api/v1'), isTrue);
      expect(ApiConfig.isLocalOrPrivateUrl('http://127.0.0.1:8000/api/v1'), isTrue);
      expect(ApiConfig.isLocalOrPrivateUrl('http://10.0.2.2:8000/api/v1'), isTrue);
      expect(ApiConfig.isLocalOrPrivateUrl('http://192.168.1.93:8000/api/v1'), isTrue);
      expect(ApiConfig.isLocalOrPrivateUrl('http://10.0.0.5:8000/api/v1'), isTrue);
      expect(ApiConfig.isLocalOrPrivateUrl('http://my-pc.local:8000/api/v1'), isTrue);
      expect(ApiConfig.isLocalOrPrivateUrl('http://server.test/api/v1'), isTrue);

      // Any HTTP cleartext URL is treated as local/insecure
      expect(ApiConfig.isLocalOrPrivateUrl('http://skyrental.id/api/v1'), isTrue);

      // Public HTTPS domain is NOT local
      expect(ApiConfig.isLocalOrPrivateUrl('https://skyrental.id/api/v1'), isFalse);
      expect(ApiConfig.isLocalOrPrivateUrl('https://api.skyrental.id/v1'), isFalse);
    });

    test('Scenario 4: Release mode strictly rejects local development URLs and defaults to production', () {
      // In release mode with accidental localhost dart-define -> falls back to production
      final resolvedLocal = ApiConfig.resolveBaseUrlForTesting(
        isReleaseMode: true,
        explicitDartDefine: 'http://127.0.0.1:8000',
      );
      expect(resolvedLocal, ApiConfig.defaultProductionBaseUrl);

      // In release mode with accidental private LAN dart-define -> falls back to production
      final resolvedLan = ApiConfig.resolveBaseUrlForTesting(
        isReleaseMode: true,
        explicitDartDefine: 'http://192.168.1.93:8000/api/v1',
      );
      expect(resolvedLan, ApiConfig.defaultProductionBaseUrl);

      // In release mode without dart-define -> defaults to production
      final resolvedEmpty = ApiConfig.resolveBaseUrlForTesting(
        isReleaseMode: true,
        explicitDartDefine: '',
      );
      expect(resolvedEmpty, ApiConfig.defaultProductionBaseUrl);

      // In release mode with valid public HTTPS -> accepted
      final resolvedProd = ApiConfig.resolveBaseUrlForTesting(
        isReleaseMode: true,
        explicitDartDefine: 'https://skyrental.id/api/v1',
      );
      expect(resolvedProd, 'https://skyrental.id/api/v1');
    });

    test('Scenario 5: Debug mode uses local development URL when explicitly supplied', () {
      final resolvedDebug = ApiConfig.resolveBaseUrlForTesting(
        isReleaseMode: false,
        explicitDartDefine: 'http://192.168.1.93:8000',
      );
      expect(resolvedDebug, 'http://192.168.1.93:8000/api/v1');

      final resolvedEmulator = ApiConfig.resolveBaseUrlForTesting(
        isReleaseMode: false,
        explicitDartDefine: 'http://10.0.2.2:8000',
      );
      expect(resolvedEmulator, 'http://10.0.2.2:8000/api/v1');

      // Debug mode without dart-define defaults to production domain
      final resolvedDefault = ApiConfig.resolveBaseUrlForTesting(
        isReleaseMode: false,
        explicitDartDefine: '',
      );
      expect(resolvedDefault, ApiConfig.defaultProductionBaseUrl);
    });

    test('Scenario 6: Backend host and storage URL helpers extract clean origins', () {
      expect(
        ApiConfig.getBackendHost('https://skyrental.id/api/v1'),
        'https://skyrental.id',
      );
      expect(
        ApiConfig.getStorageBaseUrl('https://skyrental.id/api/v1'),
        'https://skyrental.id/storage',
      );
      expect(
        ApiConfig.getBackendHost('http://192.168.1.93:8000/api/v1'),
        'http://192.168.1.93:8000',
      );
      expect(
        ApiConfig.getStorageBaseUrl('http://192.168.1.93:8000/api/v1'),
        'http://192.168.1.93:8000/storage',
      );
    });

    test('Scenario 7: ApiService exposes centralized getters and resets cleanly', () async {
      final api = ApiService();
      expect(ApiService.productionBaseUrl, ApiConfig.defaultProductionBaseUrl);
      expect(api.backendHost, startsWith('http'));
      expect(api.storageBaseUrl, contains('/storage'));

      // Test custom base URL update and reset
      await api.setCustomBaseUrl('http://192.168.1.93:8000');
      expect(api.baseUrl, 'http://192.168.1.93:8000/api/v1');
      expect(api.isLocalDevelopment, isTrue);

      await api.resetBaseUrl();
      expect(api.baseUrl, ApiConfig.resolveInitialBaseUrl());
    });
  });
}
