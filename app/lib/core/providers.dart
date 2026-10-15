import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/user_settings.dart';
import 'api/birthday_reminder_api.dart';
import 'auth/auth_controller.dart';
import 'auth/session_store.dart';
import 'notifications/push_service.dart';
import 'storage/cache_store.dart';
import 'utils/timezone_utils.dart';
import 'widgets/widget_bridge.dart';
import 'widgets/widget_sync.dart';

/// Overridden with `--dart-define=API_BASE_URL=...`. The default targets the
/// Android emulator's alias for the host machine.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8787',
);

/// Overridden in tests with a fake; the app uses the HTTP implementation.
final apiProvider = Provider<BirthdayReminderApi>(
  (ref) => HttpBirthdayReminderApi(baseUrl: apiBaseUrl),
);

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final cacheStoreProvider = Provider<CacheStore>((ref) => CacheStore());

/// When the app last wrote fresh data to the cache. The offline banner reads it
/// so a cached screen says how old it is instead of looking current.
final lastSyncedProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(cacheStoreProvider).lastSyncedAt(),
);

final pushServiceProvider = Provider<PushService>((ref) => PushService());

/// Overridden in tests (and on platforms without widgets) with a fake.
final widgetBridgeProvider = Provider<WidgetBridge>((ref) => const HomeWidgetBridge());

final widgetSyncProvider = Provider<WidgetSync>(
  (ref) => WidgetSync(ref.watch(widgetBridgeProvider)),
);

/// The device's IANA timezone, resolved through the platform channel.
/// Overridden in tests so no plugin is required.
final deviceTimezoneProvider = FutureProvider<String>((ref) => deviceTimezone());

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The signed-in user's id, or null. Data providers watch this so that signing
/// out, or another account signing in, rebuilds them instead of leaving the
/// previous user's records on screen.
final sessionUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider.select((state) => state.user?.id)),
);

/// Connectivity is only used to show the offline banner and disable writes.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((result) => result != ConnectivityResult.none));
});

class ThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    Future.microtask(_restore);
    return AppThemeMode.system;
  }

  Future<void> _restore() async {
    state = await ref.read(cacheStoreProvider).readThemeMode();
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    await ref.read(cacheStoreProvider).saveThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, AppThemeMode>(ThemeModeController.new);
