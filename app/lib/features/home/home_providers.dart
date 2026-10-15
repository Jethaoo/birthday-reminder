import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers.dart';
import '../../shared/models/home_summary.dart';

/// Home data with a cached fallback so the dashboard still renders offline.
class HomeController extends AsyncNotifier<HomeSummary> {
  @override
  Future<HomeSummary> build() async {
    ref.watch(sessionUserIdProvider);
    ref.watch(apiProvider);
    ref.watch(cacheStoreProvider);
    return _load();
  }

  /// Refreshes in place for a foreground or reconnect refresh: the dashboard
  /// keeps what it has until the server answers, so a background refresh never
  /// flashes a skeleton — or an error — over what the user is reading.
  Future<void> revalidate() async {
    final next = await AsyncValue.guard(_load);
    if (next.hasValue) state = next;
  }

  Future<HomeSummary> _load() async {
    final api = ref.read(apiProvider);
    final cache = ref.read(cacheStoreProvider);
    try {
      final summary = await api.home();
      await cache.saveHome(summary);
      ref.invalidate(lastSyncedProvider);
      // Keep the home screen widgets on the same data the dashboard is showing.
      // Not awaited: the dashboard should never wait on a launcher.
      unawaited(
        ref.read(widgetSyncProvider).publish(
              summary,
              timezone: ref.read(authControllerProvider).user?.timezone ?? '',
            ),
      );
      return summary;
    } on ApiException catch (error) {
      // An ended session is not a reason to show the last snapshot.
      if (error.isUnauthorized) rethrow;
      final cached = await cache.readHome();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final homeProvider = AsyncNotifierProvider<HomeController, HomeSummary>(HomeController.new);
