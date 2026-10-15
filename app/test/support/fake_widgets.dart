import 'dart:async';

import 'package:birthday_reminder/core/widgets/widget_bridge.dart';
import 'package:birthday_reminder/core/widgets/widget_snapshot.dart';

/// Records what the app asks the platform to do, without touching the plugin.
class FakeWidgetBridge implements WidgetBridge {
  final List<WidgetSnapshot> snapshots = [];
  final List<DateTime> scheduledTimes = [];
  int updates = 0;
  int schedules = 0;
  int cancels = 0;
  bool cleared = false;
  bool failWrites = false;

  Uri? launchUri;

  final _clicks = StreamController<Uri?>.broadcast();

  /// Simulates a tap on a widget while the app is running.
  void emit(Uri uri) => _clicks.add(uri);

  @override
  Future<void> saveSnapshot(WidgetSnapshot snapshot) async {
    if (failWrites) throw StateError('platform unavailable');
    snapshots.add(snapshot);
  }

  @override
  Future<void> clear() async {
    if (failWrites) throw StateError('platform unavailable');
    cleared = true;
    snapshots.clear();
  }

  @override
  Future<void> updateAll() async => updates++;

  @override
  Future<void> scheduleRefreshes(DateTime from) async {
    schedules++;
    scheduledTimes
      ..clear()
      ..addAll([
        for (var night = 1; night <= 3; night++)
          DateTime(from.year, from.month, from.day + night, 0, 5),
      ]);
  }

  @override
  Future<void> cancelRefreshes() async => cancels++;

  @override
  Stream<Uri?> get clicks => _clicks.stream;

  @override
  Future<Uri?> initialUri() async => launchUri;

  void dispose() => _clicks.close();
}
