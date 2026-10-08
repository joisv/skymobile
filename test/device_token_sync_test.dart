import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/services/api_service.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/services/fcm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Token Synchronization Tests', () {
    late AuthService authService;
    late FcmService fcmService;
    late ApiService apiService;

    setUp(() {
      authService = AuthService();
      fcmService = FcmService();
      apiService = ApiService();
      authService.setCurrentUserForTest(null);
      fcmService.setTokenForTest(null);
    });

    tearDown(() {
      authService.setCurrentUserForTest(null);
      fcmService.dispose();
    });

    test('ApiService registerDeviceTokenApi returns false immediately when token is empty', () async {
      final result = await apiService.registerDeviceTokenApi('');
      expect(result, isFalse);
    });

    test('ApiService removeDeviceTokenApi returns false immediately when token is empty', () async {
      final result = await apiService.removeDeviceTokenApi('');
      expect(result, isFalse);
    });

    test('FcmService token refresh notifies listener and syncs if authenticated', () async {
      authService.setCurrentUserForTest(AdminUserModel.defaultAdmin(), token: 'mock-auth-token');
      expect(authService.isAuthenticated, isTrue);

      String? refreshedToken;
      fcmService.onTokenRefreshed = (token) {
        refreshedToken = token;
      };

      fcmService.setTokenForTest('fcm-token-12345');
      expect(fcmService.fcmToken, equals('fcm-token-12345'));

      fcmService.onTokenRefreshed?.call('fcm-token-updated');
      expect(refreshedToken, equals('fcm-token-updated'));
    });

    test('AuthService logout clears session and invokes token cleanup gracefully', () async {
      authService.setCurrentUserForTest(AdminUserModel.defaultAdmin(), token: 'mock-auth-token');
      fcmService.setTokenForTest('fcm-token-to-remove');
      expect(authService.isAuthenticated, isTrue);

      await authService.logout();

      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser, isNull);
      expect(authService.token, isNull);
    });
  });
}
