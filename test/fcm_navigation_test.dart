import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/services/fcm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FCM Notification Navigation Tests', () {
    late String lastPushedRoute;
    late dynamic lastPushedArgs;

    setUp(() {
      lastPushedRoute = '';
      lastPushedArgs = null;
    });

    testWidgets('handleNotificationNavigation routes new_booking to bookingDetail with booking code',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          onGenerateRoute: (settings) {
            lastPushedRoute = settings.name ?? '';
            lastPushedArgs = settings.arguments;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
          home: const Scaffold(body: Text('Home')),
        ),
      );

      FcmService().handleNotificationNavigation({
        'type': 'new_booking',
        'booking_id': '10',
        'booking_code': 'SKY261007TEST',
      });
      await tester.pumpAndSettle();

      expect(lastPushedRoute, equals(AppRoutes.bookingDetail));
      expect(lastPushedArgs, equals('SKY261007TEST'));
    });

    testWidgets('handleNotificationNavigation routes booking_payment to bookingDetail',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          onGenerateRoute: (settings) {
            lastPushedRoute = settings.name ?? '';
            lastPushedArgs = settings.arguments;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
          home: const Scaffold(body: Text('Home')),
        ),
      );

      FcmService().handleNotificationNavigation({
        'type': 'booking_payment',
        'booking_id': '42',
        'booking_code': 'SKY-PAY-42',
      });
      await tester.pumpAndSettle();

      expect(lastPushedRoute, equals(AppRoutes.bookingDetail));
      expect(lastPushedArgs, equals('SKY-PAY-42'));
    });

    testWidgets('handleNotificationNavigation routes booking_confirmed to bookingDetail',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          onGenerateRoute: (settings) {
            lastPushedRoute = settings.name ?? '';
            lastPushedArgs = settings.arguments;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
          home: const Scaffold(body: Text('Home')),
        ),
      );

      FcmService().handleNotificationNavigation({
        'type': 'booking_confirmed',
        'booking_id': '99',
      });
      await tester.pumpAndSettle();

      expect(lastPushedRoute, equals(AppRoutes.bookingDetail));
      expect(lastPushedArgs, equals('99'));
    });

    testWidgets('handleNotificationNavigation routes iphone_transfer to iphoneTransfer screen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          onGenerateRoute: (settings) {
            lastPushedRoute = settings.name ?? '';
            lastPushedArgs = settings.arguments;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
          home: const Scaffold(body: Text('Home')),
        ),
      );

      FcmService().handleNotificationNavigation({
        'type': 'iphone_transfer',
        'transfer_id': '5',
        'to_affiliate_id': '2',
      });
      await tester.pumpAndSettle();

      expect(lastPushedRoute, equals(AppRoutes.iphoneTransfer));
      expect(lastPushedArgs, equals(2));
    });

    testWidgets('handleNotificationNavigation routes return_reminder to bookingDetail',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          onGenerateRoute: (settings) {
            lastPushedRoute = settings.name ?? '';
            lastPushedArgs = settings.arguments;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
          home: const Scaffold(body: Text('Home')),
        ),
      );

      FcmService().handleNotificationNavigation({
        'type': 'return_reminder',
        'booking_code': 'SKY-REMIND-01',
      });
      await tester.pumpAndSettle();

      expect(lastPushedRoute, equals(AppRoutes.bookingDetail));
      expect(lastPushedArgs, equals('SKY-REMIND-01'));
    });
  });
}
