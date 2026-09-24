import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers.dart';
import '../../shared/models/calendar_month.dart';

/// Calendar data for one month, keyed by `YYYY-MM`.
class CalendarController extends FamilyAsyncNotifier<CalendarMonth, String> {
  @override
  Future<CalendarMonth> build(String key) async {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final api = ref.watch(apiProvider);
    final cache = ref.watch(cacheStoreProvider);

    try {
      final result = await api.calendar(month: month, year: year);
      await cache.saveCalendar(result);
      return result;
    } on ApiException {
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
