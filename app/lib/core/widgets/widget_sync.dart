import 'package:flutter/foundation.dart';

import '../../shared/models/home_summary.dart';
import 'widget_bridge.dart';
import 'widget_snapshot.dart';

/// Keeps the home screen widgets fed from the Home data the app already has.
///
/// The backend stays the source of truth: this only ever publishes a snapshot of
/// what the app most recently fetched, and the widgets recompute the countdown
/// from those facts themselves.
class WidgetSync {
  const WidgetSync(this._bridge);

  final WidgetBridge _bridge;

  /// Publishes Home, refreshes the widgets and re-arms the midnight refreshes.
  Future<void> publish(
    HomeSummary summary, {
    required String timezone,
    DateTime? now,
  }) async {
    final publishedAt = now ?? DateTime.now();
    try {
      await _bridge.saveSnapshot(
        WidgetSnapshot.fromHome(summary, timezone: timezone, syncedAt: publishedAt),
      );
      await _bridge.updateAll();
      await _bridge.scheduleRefreshes(publishedAt);
    } catch (error) {
      // A widget is never worth failing a screen over.
      debugPrint('Home screen widget sync skipped: $error');
    }
  }

  /// Forgets the snapshot, so a signed-out phone never shows names on the home
  /// screen.
  Future<void> clear() async {
    try {
      await _bridge.clear();
      await _bridge.cancelRefreshes();
      await _bridge.updateAll();
    } catch (error) {
      debugPrint('Home screen widget clear skipped: $error');
    }
  }
}
