import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../core/auth/auth_controller.dart';
import '../core/notifications/push_service.dart';
import '../core/providers.dart';
import '../shared/models/user_settings.dart';
import 'router.dart';
import 'theme.dart';

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
      builder: (context, child) => PushCoordinator(child: child ?? const SizedBox.shrink()),
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

class _PushCoordinatorState extends ConsumerState<PushCoordinator> {
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushServiceProvider);

    push.onTokenRefresh((token) {
      if (ref.read(authControllerProvider).isSignedIn) {
        ref.read(apiProvider).registerDevice(fcmToken: token).catchError((_) {});
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

  Future<void> _registerDevice() async {
    if (_registered) return;
    _registered = true;

    final push = ref.read(pushServiceProvider);
    if (!push.isAvailable) return;

    await push.requestPermission();
    final token = await push.token();
    if (token == null) return;

    try {
      await ref.read(apiProvider).registerDevice(fcmToken: token);
    } on ApiException {
      // Registration is retried the next time the app starts.
      _registered = false;
    }
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
