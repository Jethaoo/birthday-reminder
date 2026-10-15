import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/widgets/widget_bridge.dart';
import '../features/home/home_providers.dart';
import 'router.dart';

/// Routes home screen widget taps into the app and keeps the widgets armed.
///
/// Sits alongside `PushCoordinator`: notification taps and widget taps open the
/// same screens, they just arrive on different channels.
class WidgetCoordinator extends ConsumerStatefulWidget {
  const WidgetCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WidgetCoordinator> createState() => _WidgetCoordinatorState();
}

class _WidgetCoordinatorState extends ConsumerState<WidgetCoordinator>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _clicks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final bridge = ref.read(widgetBridgeProvider);
    _clicks = bridge.clicks.listen(
      _open,
      // A launcher or plugin that cannot deliver taps must not take the app
      // down with an unhandled stream error.
      onError: (Object error) => debugPrint('Home screen widget tap ignored: $error'),
    );
    // A tap that launched the app arrives as the initial intent rather than on
    // the stream.
    bridge.initialUri().then(_open, onError: (Object _) {});
  }

  @override
  void dispose() {
    _clicks?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Resuming is the cheapest moment to re-arm the midnight refreshes, which a
  /// force-stop or a battery optimisation sweep can throw away. It republishes
  /// the data the app already holds, so it costs no request.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final auth = ref.read(authControllerProvider);
    final summary = ref.read(homeProvider).valueOrNull;
    if (!auth.isSignedIn || summary == null) return;

    unawaited(
      ref.read(widgetSyncProvider).publish(summary, timezone: auth.user?.timezone ?? ''),
    );
  }

  void _open(Uri? uri) {
    final route = widgetRoute(uri);
    if (route == null) return;

    // Pushed, not `go`: a widget can open a screen while the app has no history,
    // and `go` would leave Back with nothing to return to.
    final router = ref.read(routerProvider);
    if (router.state.matchedLocation == route) return;
    router.push(route);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
