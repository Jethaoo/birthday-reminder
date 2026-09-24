import 'package:birthday_reminder/app/theme.dart';
import 'package:birthday_reminder/core/auth/auth_controller.dart';
import 'package:birthday_reminder/core/providers.dart';
import 'package:birthday_reminder/shared/models/app_user.dart';
import 'package:birthday_reminder/shared/models/birthday.dart';
import 'package:birthday_reminder/core/auth/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';

const testUser = AppUser(
  id: 'user-1',
  name: 'Jordan Davis',
  email: 'jordan@example.com',
  timezone: 'Asia/Kuala_Lumpur',
);

/// Signed-in state used by screens that require a session.
const signedInState = AuthState(status: AuthStatus.signedIn, user: testUser);

/// Signed-out state for the authentication screens.
const signedOutState = AuthState(status: AuthStatus.signedOut);

/// Google Fonts cannot be fetched in tests; the bundled fallback is used.
void configureTestFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// A session that is already signed in, so screens render without a login step.
class FakeAuthController extends AuthController {
  FakeAuthController(this.initialUser);

  final AppUser initialUser;

  @override
  AuthState build() {
    return AuthState(status: AuthStatus.signedIn, user: initialUser);
  }
}

class FakeSignedOutAuthController extends AuthController {
  @override
  AuthState build() => const AuthState.signedOut();
}

/// Keeps the session in memory so tests never touch the platform keystore.
class FakeSessionStore implements SessionStore {
  String? token;
  AppUser? user;

  @override
  Future<void> save({required String token, required AppUser user}) async {
    this.token = token;
    this.user = user;
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<AppUser?> readUser() async => user;

  @override
  Future<void> clear() async {
    token = null;
    user = null;
  }
}

/// Convenience factory for a birthday with sensible defaults.
Birthday sampleBirthday({
  String id = 'birthday-1',
  String name = 'Sarah Tan',
  int month = 9,
  int day = 30,
  int daysUntil = 7,
  String? relationship = 'Friend',
  String? notes,
}) =>
    Birthday(
      id: id,
      name: name,
      birthdayMonth: month,
      birthdayDay: day,
      birthYear: 2000,
      relationship: relationship,
      notes: notes,
      giftIdeas: const ['Perfume'],
      reminders: const [],
      nextOccurrence: DateTime(2026, month, day),
      daysUntil: daysUntil,
      turningAge: 26,
    );

/// Wraps a screen with the app theme and provider overrides.
Widget wrapScreen(
  Widget child, {
  required FakeApi api,
  AuthState? auth,
}) {
  return ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(api),
      sessionStoreProvider.overrideWithValue(FakeSessionStore()),
      deviceTimezoneProvider.overrideWith((ref) => 'Asia/Kuala_Lumpur'),
      if (auth != null)
        authControllerProvider.overrideWith(() {
          return auth.isSignedIn ? FakeAuthController(auth.user ?? testUser) : FakeSignedOutAuthController();
        }),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

/// Wraps a screen that performs navigation, with stub destinations.
Widget wrapWithRouter(
  Widget child, {
  required FakeApi api,
  AuthState? auth,
  String initialLocation = '/',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      // The real app mounts these screens inside AppShell's Scaffold.
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
      for (final path in const [
        '/home',
        '/login',
        '/register',
        '/forgot-password',
        '/birthdays',
        '/birthdays/new',
        '/birthdays/:id',
        '/birthdays/:id/edit',
        '/contacts',
        '/settings/account',
        '/settings/notifications',
        '/settings/appearance',
        '/settings/about',
      ])
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text('STUB $path')),
        ),
    ],
  );

  return ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(api),
      sessionStoreProvider.overrideWithValue(FakeSessionStore()),
      deviceTimezoneProvider.overrideWith((ref) => 'Asia/Kuala_Lumpur'),
      if (auth != null)
        authControllerProvider.overrideWith(() {
          return auth.isSignedIn ? FakeAuthController(auth.user ?? testUser) : FakeSignedOutAuthController();
        }),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

/// Scrolls a control into view before tapping, so long forms stay tappable.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Gives tests a phone-shaped but tall surface so long screens build fully.
Future<void> useTallSurface(WidgetTester tester, {Size size = const Size(430, 1800)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void setUpPrefs() {
  SharedPreferences.setMockInitialValues({});
}
