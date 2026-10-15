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
    final api = ref.watch(apiProvider);
    final cache = ref.watch(cacheStoreProvider);

    try {
      final summary = await api.home();
      await cache.saveHome(summary);
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
