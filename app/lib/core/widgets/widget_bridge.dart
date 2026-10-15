import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_snapshot.dart';

/// The URI scheme the widgets use to send the user back into the app.
const widgetUriScheme = 'birthdayreminder';

/// The three receivers the app keeps refreshed, addressed by their fully
/// qualified class name.
const _widgetClassNames = <String>[
  'NextBirthdayWidgetReceiver',
  'NextBirthdaysWidgetReceiver',
  'TodayAndNextWidgetReceiver',
];

const _widgetPackage = 'com.birthdayreminder.app.widget';

/// Maps the URI behind a widget tap onto an app route, or null when the tap
/// came from something else.
String? widgetRoute(Uri? uri) {
  if (uri == null || uri.scheme != widgetUriScheme) return null;

  if (uri.host == 'home') return '/home';
  if (uri.host == 'birthdays') {
    final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return id.isEmpty ? '/birthdays' : '/birthdays/$id';
  }
  return null;
}

/// What the app needs from the platform to keep the widgets up to date.
///
/// Kept behind an interface so tests (and non-Android builds) never touch the
/// plugin.
abstract class WidgetBridge {
  Future<void> saveSnapshot(WidgetSnapshot snapshot);

  /// Removes the snapshot: the widgets fall back to their "sign in" state.
  Future<void> clear();

  Future<void> updateAll();

  /// Arms a refresh for each of the next few local midnights.
  Future<void> scheduleRefreshes(DateTime from);

  Future<void> cancelRefreshes();

  /// Taps that arrive while the app is running.
  Stream<Uri?> get clicks;

  /// The tap that launched the app, when it came from a widget.
  Future<Uri?> initialUri();
}

/// The real bridge, backed by `home_widget`.
class HomeWidgetBridge implements WidgetBridge {
  const HomeWidgetBridge();

  @override
  Future<void> saveSnapshot(WidgetSnapshot snapshot) async {
    await _guard(
      () => HomeWidget.saveWidgetData<String>(
        WidgetSnapshot.storageKey,
        jsonEncode(snapshot.toJson()),
      ),
    );
  }

  @override
  Future<void> clear() async {
    await _guard(() => HomeWidget.saveWidgetData<String>(WidgetSnapshot.storageKey, null));
  }

  @override
  Future<void> updateAll() async {
    for (final name in _widgetClassNames) {
      await _guard(
        () => HomeWidget.updateWidget(qualifiedAndroidName: '$_widgetPackage.$name'),
      );
    }
  }

  /// Nothing is drawn from a live clock, so the only refresh the widgets need is
  /// one just after each local midnight. A few nights are armed at a time so a
  /// missed alarm heals itself.
  @override
  Future<void> scheduleRefreshes(DateTime from, {int nights = 3}) async {
    final times = <DateTime>[
      for (var night = 1; night <= nights; night++)
        DateTime(from.year, from.month, from.day + night, 0, 5),
    ];

    for (final name in _widgetClassNames) {
      await _guard(
        () => HomeWidget.scheduleWidgetUpdates(
          times,
          qualifiedAndroidName: '$_widgetPackage.$name',
        ),
      );
    }
  }

  @override
  Future<void> cancelRefreshes() async {
    for (final name in _widgetClassNames) {
      await _guard(
        () => HomeWidget.cancelScheduledWidgetUpdates(
          qualifiedAndroidName: '$_widgetPackage.$name',
        ),
      );
    }
  }

  @override
  Stream<Uri?> get clicks => HomeWidget.widgetClicked;

  @override
  Future<Uri?> initialUri() async {
    return await _guard(() => HomeWidget.initiallyLaunchedFromHomeWidget());
  }

  /// Widgets are a convenience: a build without the plugin (tests, desktop, a
  /// launcher with no widget placed) must never break the app.
  Future<T?> _guard<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } catch (error) {
      debugPrint('Home screen widget update skipped: $error');
      return null;
    }
  }
}
