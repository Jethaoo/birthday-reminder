import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles background messages. Firebase requires a top-level function.
@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  // Nothing to do here: the notification is rendered by the OS, and tapping it
  // opens the app, where the payload is routed to the right screen.
}

/// Thin wrapper over FCM so the rest of the app never touches Firebase directly.
class PushService {
  PushService({FirebaseMessaging? messaging}) : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  bool _available = false;

  bool get isAvailable => _available;

  /// Returns false when Firebase credentials are missing, so local builds and
  /// tests keep working without `google-services.json`.
  Future<bool> initialize() async {
    if (!Platform.isAndroid && !kIsWeb) {
      _available = false;
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
      _available = true;
      return true;
    } catch (error) {
      debugPrint('Push notifications unavailable: $error');
      _available = false;
      return false;
    }
  }

  Future<void> requestPermission() async {
    if (!_available) return;
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }
  }

  Future<String?> token() async {
    if (!_available) return null;
    try {
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('Could not read the FCM token: $error');
      return null;
    }
  }

  /// Called by FCM when the token rotates; the app re-registers the device.
  void onTokenRefresh(void Function(String token) listener) {
    if (!_available) return;
    _messaging.onTokenRefresh.listen(listener);
  }

  /// Foreground messages are shown in-app because Android does not render them.
  void onForegroundMessage(void Function(RemoteMessage message) listener) {
    if (!_available) return;
    FirebaseMessaging.onMessage.listen(listener);
  }

  /// Fires when the user taps a notification while the app is running.
  void onNotificationTap(void Function(RemoteMessage message) listener) {
    if (!_available) return;
    FirebaseMessaging.onMessageOpenedApp.listen(listener);
  }

  /// The tap that launched the app from a terminated state, if any.
  Future<RemoteMessage?> initialMessage() async {
    if (!_available) return null;
    try {
      return await _messaging.getInitialMessage();
    } catch (_) {
      return null;
    }
  }
}

/// Extracts the deep-link route from a push payload.
String? routeFromMessage(RemoteMessage message) {
  final route = message.data['route'] as String?;
  if (route != null && route.isNotEmpty) return route;
  final birthdayId = message.data['birthdayId'] as String?;
  if (birthdayId != null && birthdayId.isNotEmpty) return '/birthdays/$birthdayId';
  return null;
}
