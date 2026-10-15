import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../features/birthdays/birthday_providers.dart';
import '../features/calendar/calendar_providers.dart';
import '../features/home/home_providers.dart';

/// Refreshes the data behind the screens when the app comes back to the
/// foreground, or when the connection returns.
///
/// Without this the app can sit on the last fetch of a previous session — or on
/// a cached fallback taken while it was offline — until the user pulls to
/// refresh by hand, which makes stale birthdays look current.
class DataRefreshCoordinator extends ConsumerStatefulWidget {
  const DataRefreshCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DataRefreshCoordinator> createState() => _DataRefreshCoordinatorState();
}

class _DataRefreshCoordinatorState extends ConsumerState<DataRefreshCoordinator>
    with WidgetsBindingObserver {
  /// Switching to another app and straight back is not a reason to re-fetch
  /// everything, so refreshes closer together than this are skipped.
  static const _minInterval = Duration(seconds: 45);

  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) revalidate();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      // Reconnecting makes whatever the fallback left on screen stale, so this
      // one ignores the interval.
      final wasOffline = previous?.valueOrNull == false;
      if (wasOffline && next.valueOrNull == true) revalidate(force: true);
    });
    return widget.child;
  }

  /// Refreshes what is on screen, in place, for a signed-in user.
  void revalidate({bool force = false}) {
    if (!ref.read(authControllerProvider).isSignedIn) return;

    final now = DateTime.now();
    final last = _lastRefresh;
    if (!force && last != null && now.difference(last) < _minInterval) return;
    _lastRefresh = now;

    ref.read(homeProvider.notifier).revalidate();
    ref.read(birthdayListProvider.notifier).revalidate();

    // Only refresh a month the calendar has already loaded: asking for one the
    // user has not opened would fetch data nothing is showing.
    final month = calendarKey(now.year, now.month);
    if (ref.exists(calendarProvider(month))) {
      ref.read(calendarProvider(month).notifier).revalidate();
    }
  }
}
