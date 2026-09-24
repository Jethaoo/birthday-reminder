import 'package:birthday_reminder/core/notifications/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for a startup crash: the constructor used to resolve
/// `FirebaseMessaging.instance` before `Firebase.initializeApp()` had run, which
/// threw `[core/no-app]` and stopped `runApp` from ever being called.
void main() {
  test('constructing the service does not touch Firebase', () {
    final service = PushService();

    expect(service.isAvailable, isFalse);
  });

  test('initialize reports false instead of throwing without Firebase', () async {
    final service = PushService();

    expect(await service.initialize(), isFalse);
    expect(service.isAvailable, isFalse);
  });

  test('push calls are safe no-ops before initialization', () async {
    final service = PushService();

    await expectLater(service.requestPermission(), completes);
    expect(await service.token(), isNull);
    expect(await service.initialMessage(), isNull);
    expect(() => service.onTokenRefresh((_) {}), returnsNormally);
    expect(() => service.onForegroundMessage((_) {}), returnsNormally);
    expect(() => service.onNotificationTap((_) {}), returnsNormally);
  });
}
