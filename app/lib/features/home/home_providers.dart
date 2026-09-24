import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers.dart';
import '../../shared/models/home_summary.dart';

/// Home data with a cached fallback so the dashboard still renders offline.
class HomeController extends AsyncNotifier<HomeSummary> {
  @override
  Future<HomeSummary> build() async {
    final api = ref.watch(apiProvider);
    final cache = ref.watch(cacheStoreProvider);

    try {
      final summary = await api.home();
      await cache.saveHome(summary);
      return summary;
    } on ApiException {
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
