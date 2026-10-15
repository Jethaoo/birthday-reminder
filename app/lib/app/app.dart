import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../core/auth/auth_controller.dart';
import '../core/notifications/push_service.dart';
import '../core/providers.dart';
import '../shared/models/user_settings.dart';
import 'data_refresh_coordinator.dart';
import 'router.dart';
import 'theme.dart';
import 'widget_coordinator.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class BirthdayReminderApp extends ConsumerWidget {
  const BirthdayReminderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Birthday Reminder',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      routerConfig: router,
      builder: (context, child) => PushCoordinator(
        child: WidgetCoordinator(
          child: DataRefreshCoordinator(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Registers the device for push and routes notification taps to their screen.
class PushCoordinator extends ConsumerStatefulWidget {
  const PushCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushCoordinator> createState() => _PushCoordinatorState();
}

class _PushCoordinatorState extends ConsumerState<PushCoordinator> with WidgetsBindingObserver {
  /// Only true once the server has accepted this device's current token.
  bool _registered = false;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final push = ref.read(pushServiceProvider);

    push.onTokenRefresh((token) {
      if (ref.read(authControllerProvider).isSignedIn) {
        _saveRegistration(token).catchError((_) {});
      }
    });

    // Pushed, not `go`: a notification can open this screen while the app has no
    // history, and `go` would replace the stack so Back closed the app.
    void openBirthdayFromNotification(String route) {
      final router = ref.read(routerProvider);
      if (router.state.matchedLocation == route) return;
      router.push(route);
    }

    push.onNotificationTap((message) {
      final route = routeFromMessage(message);
      if (route != null) openBirthdayFromNotification(route);
    });

    push.onForegroundMessage((message) {
      final title = message.notification?.title;
      final body = message.notification?.body;
      if (title == null && body == null) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text([title, body].whereType<String>().join(' · '))),
      );
    });

    push.initialMessage().then((message) {
      final route = message == null ? null : routeFromMessage(message);
      if (route != null) openBirthdayFromNotification(route);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A token can go stale while the app is alive (app data cleared, the Firebase
  /// key rotated, FCM rotating the token). Re-checking on resume means a device
  /// that stopped being reachable heals itself instead of staying silent until
  /// the process restarts.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(authControllerProvider).isSignedIn) {
      // Fire and forget: the next resume retries, so a failure here must not
      // surface as an unhandled async error.
      _registerDevice().catchError((_) {});
    }
  }

  Future<void> _registerDevice() async {
    if (_registered || _registering) return;
    _registering = true;
    try {
      final push = ref.read(pushServiceProvider);
      // Firebase may not be configured in this build; a later resume retries.
      if (!push.isAvailable) return;

      // Without permission Android drops every notification, so there is nothing
      // to register; the app asks again on the next start.
      if (!await push.requestPermissionGranted()) {
        _registered = false;
        return;
      }
      final token = await push.token();
      if (token == null) return;

      try {
        await _saveRegistration(token);
        _registered = true;
      } on ApiException {
        // Registration is retried the next time the app starts.
        _registered = false;
      }
    } finally {
      _registering = false;
    }
  }

  /// Registers [token] and remembers the device id so sign-out can remove it.
  Future<void> _saveRegistration(String token) async {
    final deviceId = await ref.read(apiProvider).registerDevice(fcmToken: token);
    if (deviceId != null) await ref.read(sessionStoreProvider).saveDeviceId(deviceId);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.isSignedIn) {
        _registerDevice();
        ref.read(authControllerProvider.notifier).syncTimezone();
      } else if (previous?.isSignedIn ?? false) {
        _registered = false;
      }
    });

    return widget.child;
  }
}
