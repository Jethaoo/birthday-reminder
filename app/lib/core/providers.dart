import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/user_settings.dart';
import 'api/birthday_reminder_api.dart';
import 'auth/auth_controller.dart';
import 'auth/session_store.dart';
import 'notifications/push_service.dart';
import 'storage/cache_store.dart';
import 'utils/timezone_utils.dart';

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

final pushServiceProvider = Provider<PushService>((ref) => PushService());

/// The device's IANA timezone, resolved through the platform channel.
/// Overridden in tests so no plugin is required.
final deviceTimezoneProvider = FutureProvider<String>((ref) => deviceTimezone());

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

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
