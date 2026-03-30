import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/env.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted push notification permission');
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await registerFCMToken();

    _messaging.onTokenRefresh.listen((newToken) {
      _sendTokenToBackend(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground FCM message: ${message.messageId}');
      // A UI toaster or banner could be triggered here natively
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('User tapped the notification banner! ID: ${message.messageId}');
      _handleNotificationTap(message);
    });
  }

  static Future<void> registerFCMToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('Failed to extract local FCM token: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      String platformLabel = defaultTargetPlatform.name;
      await ApiService.post('${Env.apiBase}/notifications/register-device/', {
        'token': fcmToken,
        'platform': platformLabel,
      });
      debugPrint('Successfully registered physical FCM token with Django Backend.');
    } catch (e) {
      debugPrint('FCM upstream registry failed securely: $e');
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
      // Stub for contextual deep linking based on `message.data` maps later.
  }
}
