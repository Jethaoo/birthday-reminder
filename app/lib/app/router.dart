import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/providers.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/complete_profile_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/birthdays/presentation/birthday_details_screen.dart';
import '../features/birthdays/presentation/birthday_form_screen.dart';
import '../features/birthdays/presentation/birthdays_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/contacts/presentation/contact_import_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/settings/presentation/about_screen.dart';
import '../features/settings/presentation/account_screen.dart';
import '../features/settings/presentation/appearance_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/app_shell.dart';
import 'splash_screen.dart';

/// Routes that do not require a session.
const _publicRoutes = <String>{
  '/',
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
};

/// Shown while the stored session resolves.
const splashRoute = '/splash';
const completeProfileRoute = '/complete-profile';

String _signedInLanding(AuthState auth) {
  return auth.user?.hasBirthday == true ? '/home' : completeProfileRoute;
}

/// Where a navigation request should go for the current [auth] state.
///
/// While the session is still resolving, everything waits on [splashRoute]: the
/// signed-in shell fetches as it builds, and a request sent before the token is
/// attached comes back 401 — which ended the very session being restored, on
/// every launch. Returning `null` means "render the requested route", so the
/// restoring case must name a route instead.
String? sessionRedirect(AuthState auth, String location) {
  if (auth.isRestoring) return location == splashRoute ? null : splashRoute;

  // The session has resolved, so the splash screen has done its job: send the
  // user where they belong instead of leaving them on the spinner.
  if (location == splashRoute) {
    return auth.isSignedIn ? _signedInLanding(auth) : '/';
  }

  final isPublic = _publicRoutes.contains(location);
  if (!auth.isSignedIn) return isPublic ? null : '/';
  if (isPublic) return _signedInLanding(auth);

  final needsBirthday = auth.user?.hasBirthday != true;
  if (needsBirthday) {
    return location == completeProfileRoute ? null : completeProfileRoute;
  }
  if (location == completeProfileRoute) return '/home';
  return null;
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Bridges Riverpod auth state changes into GoRouter's refresh mechanism.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) => sessionRedirect(
      ref.read(authControllerProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: splashRoute,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: completeProfileRoute,
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/birthdays',
                builder: (context, state) => const BirthdaysScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes pushed above the shell.
      GoRoute(
        path: '/birthdays/new',
        builder: (context, state) => const BirthdayFormScreen(),
      ),
      GoRoute(
        path: '/birthdays/:id',
        builder: (context, state) =>
            BirthdayDetailsScreen(birthdayId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/birthdays/:id/edit',
        builder: (context, state) =>
            BirthdayFormScreen(birthdayId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactImportScreen(),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (context, state) => const AppearanceScreen(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => const AboutScreen(),
      ),
    ],
  );
});
