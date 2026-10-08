import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import '../routes/app_routes.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Top-level background message handler for FCM.
/// Must be outside of any class and annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Already initialized or platform channel unavailable
  }
  debugPrint('[FCM] Background message received: ${message.messageId}');
  debugPrint('[FCM] Background title: ${message.notification?.title}');
  debugPrint('[FCM] Background body: ${message.notification?.body}');
  debugPrint('[FCM] Background data: ${message.data}');
}

/// Minimal, self-contained Firebase Cloud Messaging (FCM) Service.
/// Reuses existing application architecture as a simple singleton service.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  /// Global Navigator key used for deep navigation on notification tap
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isInitialized = false;
  String? _fcmToken;
  RemoteMessage? _initialMessage;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  void Function(String token)? onTokenRefreshed;
  void Function(RemoteMessage message)? onForegroundMessage;
  void Function(RemoteMessage message)? onNotificationOpened;

  bool get isInitialized => _isInitialized;
  String? get fcmToken => _fcmToken;
  RemoteMessage? get initialMessage => _initialMessage;

  /// Handle navigation based on notification data payload.
  void handleNotificationNavigation(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final type = data['type'] ?? data['notification_type'];
    final bookingCode = data['booking_code'];
    final bookingId = data['booking_id'];
    final route = data['route'];

    debugPrint('[FCM] Navigating for notification type: $type, data: $data');

    final navState = navigatorKey.currentState;
    if (navState == null) {
      debugPrint('[FCM] Navigator state not ready for navigation.');
      return;
    }

    switch (type) {
      case 'new_booking':
      case 'booking_payment':
      case 'booking_confirmed':
      case 'return_reminder':
        final targetBooking = bookingCode ?? bookingId;
        if (targetBooking != null && targetBooking.toString().isNotEmpty) {
          navState.pushNamed(AppRoutes.bookingDetail, arguments: targetBooking.toString());
        } else {
          navState.pushNamed(AppRoutes.bookingList);
        }
        break;

      case 'iphone_transfer':
        final affiliateId = int.tryParse(data['to_affiliate_id']?.toString() ?? '');
        navState.pushNamed(AppRoutes.iphoneTransfer, arguments: affiliateId);
        break;

      default:
        if (route != null && route.toString().isNotEmpty) {
          navState.pushNamed(route.toString());
        }
        break;
    }
  }

  /// Initialize Firebase and configure FCM notification handlers.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase Core
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // 2. Register Background Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // 3. Request Notification Permissions (iOS & Android 13+)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // 4. Retrieve Device FCM Token
      try {
        _fcmToken = await messaging.getToken();
        debugPrint('[FCM] Device Token: $_fcmToken');
        if (_fcmToken != null && _fcmToken!.isNotEmpty && AuthService().isAuthenticated) {
          unawaited(ApiService().registerDeviceTokenApi(_fcmToken!, platform: 'android'));
        }
      } catch (e) {
        debugPrint('[FCM] Error retrieving device token: $e');
      }

      // 5. Handle Token Refresh
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
        final oldToken = _fcmToken;
        _fcmToken = newToken;
        debugPrint('[FCM] Token refreshed: $newToken');
        onTokenRefreshed?.call(newToken);

        if (AuthService().isAuthenticated) {
          ApiService().registerDeviceTokenApi(
            newToken,
            platform: 'android',
            oldToken: oldToken,
          ).catchError((e) {
            debugPrint('[FCM] Error syncing refreshed token to backend: $e');
            return false;
          });
        }
      });

      // 6. Handle Foreground Notifications
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[FCM] Foreground notification received: ${message.messageId}');
        debugPrint('[FCM] Title: ${message.notification?.title}, Body: ${message.notification?.body}');
        debugPrint('[FCM] Data: ${message.data}');
        onForegroundMessage?.call(message);

        // Display in-app notification banner so foreground device immediately shows the alert
        final navContext = navigatorKey.currentContext;
        final title = message.notification?.title ?? '';
        final body = message.notification?.body ?? '';
        if (navContext != null && (title.isNotEmpty || body.isNotEmpty)) {
          ScaffoldMessenger.maybeOf(navContext)?.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (body.isNotEmpty)
                          Text(
                            body,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              backgroundColor: const Color(0xFF1E293B),
              action: SnackBarAction(
                label: 'LIHAT',
                textColor: const Color(0xFF38BDF8),
                onPressed: () {
                  handleNotificationNavigation(message.data);
                },
              ),
            ),
          );
        }
      });

      // 7. Handle Notifications Clicked When App In Background
      _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('[FCM] Notification opened from background: ${message.messageId}');
        onNotificationOpened?.call(message);
        handleNotificationNavigation(message.data);
      });

      // 8. Handle Notification Clicked When App Was Completely Terminated
      _initialMessage = await messaging.getInitialMessage();
      if (_initialMessage != null) {
        debugPrint('[FCM] App opened from terminated state via notification: ${_initialMessage!.messageId}');
        onNotificationOpened?.call(_initialMessage!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationNavigation(_initialMessage!.data);
        });
      }

      _isInitialized = true;
      debugPrint('[FCM] FcmService initialized successfully.');
    } catch (e, stack) {
      debugPrint('[FCM] Warning: FcmService initialization encountered an issue: $e\n$stack');
      // Gracefully continue without breaking app startup (especially during widget testing or offline mode)
    }
  }

  /// Manually update token for testing purposes
  @visibleForTesting
  void setTokenForTest(String? token) {
    _fcmToken = token;
  }

  /// Manually set initial message for testing purposes
  @visibleForTesting
  void setInitialMessageForTest(RemoteMessage? message) {
    _initialMessage = message;
  }

  /// Dispose active subscriptions if needed
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedAppSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _isInitialized = false;
  }
}
