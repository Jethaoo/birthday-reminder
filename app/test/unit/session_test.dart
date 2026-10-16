import 'package:birthday_reminder/core/auth/auth_controller.dart';
import 'package:birthday_reminder/core/auth/session_store.dart';
import 'package:birthday_reminder/core/notifications/push_service.dart';
import 'package:birthday_reminder/core/providers.dart';
import 'package:birthday_reminder/features/home/home_providers.dart';
import 'package:birthday_reminder/shared/models/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

const _otherUser = AppUser(
  id: 'user-2',
  name: 'Alex Lim',
  email: 'alex@example.com',
  timezone: 'Asia/Kuala_Lumpur',
);

const _utcUser = AppUser(
  id: 'user-1',
  name: 'Jordan Davis',
  email: 'jordan@example.com',
  timezone: 'UTC',
);

/// A container with a stored session, so the real [AuthController] restores it.
ProviderContainer _signedInContainer(FakeApi api, FakeSessionStore sessions) {
  sessions
    ..token = 'token-1'
    ..user = testUser;
  final container = ProviderContainer(
    overrides: [
      apiProvider.overrideWithValue(api),
      sessionStoreProvider.overrideWithValue(sessions),
      deviceTimezoneProvider.overrideWith((ref) => 'Asia/Kuala_Lumpur'),
      pushServiceProvider.overrideWithValue(PushService()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sign-out unregisters this device and clears the session', () async {
    final api = FakeApi();
    final sessions = FakeSessionStore()..deviceId = 'device-7';
    final container = _signedInContainer(api, sessions);

    container.read(authControllerProvider);
    await _settle();
    expect(container.read(authControllerProvider).isSignedIn, isTrue);

    await container.read(authControllerProvider.notifier).signOut();

    expect(api.unregisteredDevices, ['device-7']);
    expect(sessions.token, isNull);
    expect(sessions.deviceId, isNull);
    expect(container.read(authControllerProvider).isSignedIn, isFalse);
  });

  test('a 401 from an authenticated request ends the session', () async {
    final api = FakeApi();
    final container = _signedInContainer(api, FakeSessionStore());

    container.read(authControllerProvider);
    await _settle();
    expect(container.read(authControllerProvider).isSignedIn, isTrue);

    api.onUnauthorizedCallback?.call();
    await _settle();

    expect(container.read(authControllerProvider).isSignedIn, isFalse);
    // The server already rejected the token, so it is not used again.
    expect(api.calls['unregisterDevice'], isNull);
  });

  test('data providers reload when a different account signs in', () async {
    final api = FakeApi();
    final container = _signedInContainer(api, FakeSessionStore());

    container.read(authControllerProvider);
    await _settle();
    await container.read(homeProvider.future);
    final callsForFirstUser = api.calls['home'];

    await container.read(authControllerProvider.notifier).signOut();
    api.user = _otherUser;
    await container.read(authControllerProvider.notifier).signIn(email: 'alex@example.com', password: 'x');
    await container.read(homeProvider.future);

    expect(api.calls['home'], greaterThan(callsForFirstUser ?? 0));
  });

  test('an unreadable keystore signs out instead of hanging on restore', () async {
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(FakeApi()),
        sessionStoreProvider.overrideWithValue(_ThrowingSessionStore()),
        deviceTimezoneProvider.overrideWith((ref) => 'Asia/Kuala_Lumpur'),
      ],
    );
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    await _settle();

    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
  });

  test('a blank stored token is no session, and its leftovers are cleared', () async {
    final api = FakeApi();
    final sessions = FakeSessionStore()
      // What the timezone sync used to write when it could not read the token.
      ..token = ''
      ..user = testUser;
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        sessionStoreProvider.overrideWithValue(sessions),
        deviceTimezoneProvider.overrideWith((ref) => 'Asia/Kuala_Lumpur'),
        pushServiceProvider.overrideWithValue(PushService()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    await _settle();

    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
    // Regression: a blank token counted as signed in, so the app built its
    // signed-in screens, sent every request without an Authorization header,
    // took a 401 on the first one and signed out — on every single launch.
    expect(api.calls, isEmpty);
    expect(sessions.token, isNull);
    expect(sessions.user, isNull);
  });

  test('a timezone sync never blanks a stored token it cannot read', () async {
    final api = FakeApi()..user = _utcUser;
    final sessions = FakeSessionStore();
    final container = _signedInContainer(api, sessions);

    container.read(authControllerProvider);
    await _settle();
    expect(container.read(authControllerProvider).isSignedIn, isTrue);

    // The token is unreadable while the sync is in flight.
    sessions.token = null;
    await container.read(authControllerProvider.notifier).syncTimezone();

    expect(api.calls['updateMe'], 1);
    // Regression: this wrote `?? ''` over the session, and every launch after it
    // restored an empty token that could not authenticate anything.
    expect(sessions.token, isNull);
  });

  test('refuses to store an empty access token', () async {
    final store = SessionStore();

    await expectLater(store.save(token: '', user: testUser), throwsArgumentError);
    await expectLater(store.save(token: '   ', user: testUser), throwsArgumentError);
  });
}

class _ThrowingSessionStore extends FakeSessionStore {
  @override
  Future<String?> readToken() async => throw Exception('BAD_DECRYPT');
}
