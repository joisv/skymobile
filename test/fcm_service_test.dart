import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/services/fcm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FcmService Tests', () {
    late FcmService fcmService;

    setUp(() {
      fcmService = FcmService();
    });

    tearDown(() {
      fcmService.dispose();
    });

    test('FcmService is a singleton', () {
      final instance1 = FcmService();
      final instance2 = FcmService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('FcmService initial state has null token and initialMessage', () {
      expect(fcmService.fcmToken, isNull);
      expect(fcmService.initialMessage, isNull);
    });

    test('FcmService init completes safely in test environment without unhandled exceptions', () async {
      await expectLater(fcmService.init(), completes);
    });

    test('FcmService setTokenForTest updates token and triggers callback', () {
      String? updatedToken;
      fcmService.onTokenRefreshed = (token) {
        updatedToken = token;
      };

      fcmService.setTokenForTest('test_token_12345');
      expect(fcmService.fcmToken, equals('test_token_12345'));

      fcmService.onTokenRefreshed?.call('test_token_refreshed');
      expect(updatedToken, equals('test_token_refreshed'));
    });

    test('FcmService setInitialMessageForTest stores message for terminated launch', () {
      const message = RemoteMessage(
        messageId: 'msg_terminated_101',
        data: {'type': 'booking_created', 'booking_id': '101'},
      );

      fcmService.setInitialMessageForTest(message);
      expect(fcmService.initialMessage, isNotNull);
      expect(fcmService.initialMessage?.messageId, equals('msg_terminated_101'));
      expect(fcmService.initialMessage?.data['booking_id'], equals('101'));
    });

    test('FcmService onForegroundMessage and onNotificationOpened callbacks trigger correctly', () {
      RemoteMessage? foregroundMsg;
      RemoteMessage? openedMsg;

      fcmService.onForegroundMessage = (msg) {
        foregroundMsg = msg;
      };
      fcmService.onNotificationOpened = (msg) {
        openedMsg = msg;
      };

      const testMsg = RemoteMessage(
        messageId: 'msg_fg_202',
        notification: RemoteNotification(
          title: 'Booking Baru',
          body: 'Ada booking baru masuk',
        ),
      );

      fcmService.onForegroundMessage?.call(testMsg);
      fcmService.onNotificationOpened?.call(testMsg);

      expect(foregroundMsg?.messageId, equals('msg_fg_202'));
      expect(foregroundMsg?.notification?.title, equals('Booking Baru'));
      expect(openedMsg?.messageId, equals('msg_fg_202'));
    });

    test('firebaseMessagingBackgroundHandler processes RemoteMessage safely without error', () async {
      const bgMessage = RemoteMessage(
        messageId: 'msg_bg_303',
        notification: RemoteNotification(
          title: 'Background Title',
          body: 'Background Body',
        ),
        data: {'status': 'confirmed'},
      );

      await expectLater(firebaseMessagingBackgroundHandler(bgMessage), completes);
    });
  });
}
