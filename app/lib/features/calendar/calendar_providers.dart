import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers.dart';
import '../../shared/models/calendar_month.dart';

/// Calendar data for one month, keyed by `YYYY-MM`.
class CalendarController extends FamilyAsyncNotifier<CalendarMonth, String> {
  @override
  Future<CalendarMonth> build(String key) async {
    final parts = key.split('-');
    ref.watch(sessionUserIdProvider);
    ref.watch(apiProvider);
    ref.watch(cacheStoreProvider);
    return _load(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Refreshes in place for the foreground and reconnect refresh.
  Future<void> revalidate() async {
    final parts = arg.split('-');
    final next = await AsyncValue.guard(() => _load(int.parse(parts[0]), int.parse(parts[1])));
    if (next.hasValue) state = next;
  }

  Future<CalendarMonth> _load(int year, int month) async {
    final api = ref.read(apiProvider);
    final cache = ref.read(cacheStoreProvider);
    try {
      final result = await api.calendar(month: month, year: year);
      await cache.saveCalendar(result);
      ref.invalidate(lastSyncedProvider);
      return result;
    } on ApiException catch (error) {
      if (error.isUnauthorized) rethrow;
      final cached = await cache.readCalendar(year, month);
      if (cached != null) return cached;
      rethrow;
    }
  }
}

final calendarProvider = AsyncNotifierProvider.family<CalendarController, CalendarMonth, String>(
  CalendarController.new,
);

String calendarKey(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';
