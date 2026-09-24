import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/birthday_reminder_api.dart';
import '../../core/providers.dart';
import '../../shared/models/birthday.dart';
import '../../shared/models/reminder.dart';
import '../home/home_providers.dart';

/// Search, filter, sort and pagination state for the Birthdays tab.
class BirthdayListState {
  const BirthdayListState({
    required this.items,
    required this.total,
    this.search = '',
    this.filter = 'all',
    this.sort = 'upcoming',
    this.loadingMore = false,
    this.offline = false,
  });

  final List<Birthday> items;
  final int total;
  final String search;
  final String filter;
  final String sort;
  final bool loadingMore;
  final bool offline;

  bool get hasMore => items.length < total;
  bool get isEmpty => items.isEmpty;

  BirthdayListState copyWith({
    List<Birthday>? items,
    int? total,
    String? search,
    String? filter,
    String? sort,
    bool? loadingMore,
    bool? offline,
  }) =>
      BirthdayListState(
        items: items ?? this.items,
        total: total ?? this.total,
        search: search ?? this.search,
        filter: filter ?? this.filter,
        sort: sort ?? this.sort,
        loadingMore: loadingMore ?? this.loadingMore,
        offline: offline ?? this.offline,
      );
}

class BirthdayListController extends AsyncNotifier<BirthdayListState> {
  static const _pageSize = 25;

  String _search = '';
  String _filter = 'all';
  String _sort = 'upcoming';

  @override
  Future<BirthdayListState> build() async {
    final api = ref.watch(apiProvider);
    final cache = ref.watch(cacheStoreProvider);

    try {
      final page = await api.birthdays(
        BirthdayQuery(search: _search, filter: _filter, sort: _sort, limit: _pageSize),
      );
      if (_search.isEmpty && _filter == 'all' && _sort == 'upcoming') {
        await cache.saveBirthdays(page.items);
      }
      return BirthdayListState(items: page.items, total: page.total, search: _search, filter: _filter, sort: _sort);
    } on ApiException {
      final cached = await cache.readBirthdays();
      if (cached != null) {
        return BirthdayListState(
          items: cached,
          total: cached.length,
          search: _search,
          filter: _filter,
          sort: _sort,
          offline: true,
        );
      }
      rethrow;
    }
  }

  Future<void> _reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> setSearch(String value) async {
    _search = value.trim();
    await _reload();
  }

  Future<void> setFilter(String value) async {
    _filter = value;
    await _reload();
  }

  Future<void> setSort(String value) async {
    _sort = value;
    await _reload();
  }

  Future<void> refresh() => _reload();

  /// Loads the next page and appends it to the current list.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(apiProvider).birthdays(
            BirthdayQuery(
              search: _search,
              filter: _filter,
              sort: _sort,
              limit: _pageSize,
              offset: current.items.length,
            ),
          );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          total: page.total,
          loadingMore: false,
        ),
      );
    } on ApiException {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final birthdayListProvider =
    AsyncNotifierProvider<BirthdayListController, BirthdayListState>(BirthdayListController.new);

/// Full record for the detail screen, including reminders.
class BirthdayDetailController extends FamilyAsyncNotifier<Birthday, String> {
  @override
  Future<Birthday> build(String birthdayId) async {
    return ref.watch(apiProvider).birthday(birthdayId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }
}

final birthdayDetailProvider =
    AsyncNotifierProvider.family<BirthdayDetailController, Birthday, String>(
  BirthdayDetailController.new,
);

/// Mutations shared by the form, detail and reminder screens.
class BirthdayActions {
  BirthdayActions(this._ref);

  final Ref _ref;

  BirthdayReminderApi get _api => _ref.read(apiProvider);

  Future<Birthday> create(Birthday birthday) async {
    final created = await _api.createBirthday(birthday);
    _invalidateLists();
    return created;
  }

  Future<Birthday> update(Birthday birthday) async {
    final updated = await _api.updateBirthday(birthday);
    _ref.invalidate(birthdayDetailProvider(birthday.id));
    _invalidateLists();
    return updated;
  }

  Future<void> delete(String birthdayId) async {
    await _api.deleteBirthday(birthdayId);
    _invalidateLists();
  }

  Future<List<Reminder>> reminders(String birthdayId) => _api.reminders(birthdayId);

  Future<Reminder> addReminder(String birthdayId, Reminder reminder) async {
    final created = await _api.createReminder(birthdayId, reminder);
    _ref.invalidate(birthdayDetailProvider(birthdayId));
    return created;
  }

  Future<Reminder> updateReminder(String birthdayId, Reminder reminder) async {
    final updated = await _api.updateReminder(reminder.id, reminder);
    _ref.invalidate(birthdayDetailProvider(birthdayId));
    return updated;
  }

  Future<void> deleteReminder(String birthdayId, String reminderId) async {
    await _api.deleteReminder(reminderId);
    _ref.invalidate(birthdayDetailProvider(birthdayId));
  }

  void _invalidateLists() {
    _ref.invalidate(birthdayListProvider);
    _ref.invalidate(homeProvider);
  }
}

final birthdayActionsProvider = Provider<BirthdayActions>(BirthdayActions.new);
