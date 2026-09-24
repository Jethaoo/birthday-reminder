import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers.dart';
import '../../shared/models/user_settings.dart';

/// Notification, default-reminder and appearance preferences.
class SettingsController extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    final cache = ref.watch(cacheStoreProvider);
    try {
      final settings = await ref.watch(apiProvider).settings();
      await cache.saveSettings(settings);
      return settings;
    } on ApiException {
      final cached = await cache.readSettings();
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Applies optimistically, rolling back when the server rejects the change.
  Future<void> save(UserSettings next) async {
    final previous = state.valueOrNull ?? const UserSettings();
    state = AsyncData(next);

    try {
      final saved = await ref.read(apiProvider).updateSettings(next);
      await ref.read(cacheStoreProvider).saveSettings(saved);
      state = AsyncData(saved);
      await ref.read(themeModeProvider.notifier).setMode(saved.themeMode);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, UserSettings>(SettingsController.new);
