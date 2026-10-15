import 'package:birthday_reminder/app/app.dart';
import 'package:birthday_reminder/core/api/api_exception.dart';
import 'package:birthday_reminder/core/auth/auth_controller.dart';
import 'package:birthday_reminder/core/notifications/push_service.dart';
import 'package:birthday_reminder/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

/// Stands in for Firebase: no platform channels, and the token can start out
/// unavailable the way it does when Firebase cannot issue one.
class FakePushService extends PushService {
  FakePushService({
    this.available = true,
    this.tokenValue = 'device-token',
    this.permissionGranted = true,
  });

  bool available;
  String? tokenValue;
  bool permissionGranted;
  int permissionChecks = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<bool> requestPermissionGranted() async {
    permissionChecks += 1;
    return permissionGranted;
  }

  @override
  Future<String?> token() async => tokenValue;
}

/// Restores a session asynchronously, like the real controller does, so the
/// auth listener actually observes a transition to signed in.
class RestoringAuthController extends AuthController {
  @override
  AuthState build() {
    Future.microtask(() => state = const AuthState(status: AuthStatus.signedIn, user: testUser));
    return const AuthState.restoring();
  }
}

Widget _app({required PushService push, required FakeApi api}) {
  return ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(api),
      pushServiceProvider.overrideWithValue(push),
      sessionStoreProvider.overrideWithValue(FakeSessionStore()),
      deviceTimezoneProvider.overrideWith((ref) => 'Asia/Kuala_Lumpur'),
      authControllerProvider.overrideWith(RestoringAuthController.new),
    ],
    child: MaterialApp(home: PushCoordinator(child: const SizedBox.shrink())),
  );
}

/// Delivers a lifecycle message the way the Android host does.
Future<void> sendLifecycle(WidgetTester tester, AppLifecycleState state) async {
  final message = const StringCodec().encodeMessage(state.toString());
  await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage('flutter/lifecycle', message, (ByteData? _) {});
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('registers the device once the session is signed in', (tester) async {
    final api = FakeApi();
    final push = FakePushService();

    await tester.pumpWidget(_app(push: push, api: api));
    await tester.pumpAndSettle();

    expect(api.calls['registerDevice'], 1);
  });

  testWidgets('retries on resume when Firebase could not issue a token', (tester) async {
    final api = FakeApi();
    final push = FakePushService(tokenValue: null);

    await tester.pumpWidget(_app(push: push, api: api));
    await tester.pumpAndSettle();

    // Firebase had no token, so nothing was sent to the server.
    expect(push.permissionChecks, 1);
    expect(api.calls['registerDevice'], isNull);

    // A token becomes available on a later attempt, for example once the
    // Firebase key is fixed or the app is reinstalled.
    push.tokenValue = 'device-token';
    await sendLifecycle(tester, AppLifecycleState.paused);
    await sendLifecycle(tester, AppLifecycleState.resumed);

    expect(api.calls['registerDevice'], 1);
  });

  testWidgets('retries when the server rejects the registration', (tester) async {
    final api = FakeApi()..nextError = ApiException.network();
    final push = FakePushService();

    await tester.pumpWidget(_app(push: push, api: api));
    await tester.pumpAndSettle();

    expect(api.calls['registerDevice'], 1);

    await sendLifecycle(tester, AppLifecycleState.paused);
    await sendLifecycle(tester, AppLifecycleState.resumed);

    expect(api.calls['registerDevice'], 2);
  });

  testWidgets('does not re-register on every resume once it has succeeded', (tester) async {
    final api = FakeApi();
    final push = FakePushService();

    await tester.pumpWidget(_app(push: push, api: api));
    await tester.pumpAndSettle();
    expect(api.calls['registerDevice'], 1);

    for (var i = 0; i < 3; i++) {
      await sendLifecycle(tester, AppLifecycleState.paused);
      await sendLifecycle(tester, AppLifecycleState.resumed);
    }

    expect(api.calls['registerDevice'], 1);
  });

  testWidgets('does nothing when Firebase is unavailable in this build', (tester) async {
    final api = FakeApi();
    final push = FakePushService(available: false);

    await tester.pumpWidget(_app(push: push, api: api));
    await tester.pumpAndSettle();

    expect(push.permissionChecks, 0);
    expect(api.calls['registerDevice'], isNull);
  });
}
