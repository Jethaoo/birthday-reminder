import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/offline_banner.dart';

/// Bottom-navigation shell with the glass pill bar from the design.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _tabLocations = {
    '/home',
    '/birthdays',
    '/calendar',
    '/settings',
  };
  static const _tabIndexByLocation = {
    '/home': 0,
    '/birthdays': 1,
    '/calendar': 2,
    '/settings': 3,
  };

  /// Tabs are switched without route changes on Android's back stack, so keep
  /// their visit order here and unwind it before allowing the app to close.
  late final List<int> _tabHistory = [widget.navigationShell.currentIndex];
  GoRouter? _router;
  bool _handlingBack = false;
  bool _confirmingExit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_recordTabChange);
    _router = router;
    router.routerDelegate.addListener(_recordTabChange);
    _recordTabChange();
  }

  void _recordTabChange() {
    final index = _tabIndexByLocation[_router?.state.matchedLocation];
    if (index != null && _tabHistory.last != index) _tabHistory.add(index);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_recordTabChange);
    super.dispose();
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<bool> _handleBack() async {
    // Let full-screen routes above the shell handle their own back action.
    if (!_tabLocations.contains(GoRouter.of(context).state.matchedLocation)) {
      return false;
    }
    if (_confirmingExit) {
      Navigator.of(context, rootNavigator: true).maybePop(false);
      return true;
    }
    if (_handlingBack) return true;
    _handlingBack = true;

    try {
      if (_tabHistory.length > 1) {
        _tabHistory.removeLast();
        widget.navigationShell.goBranch(_tabHistory.last);
        return true;
      }

      _confirmingExit = true;
      final shouldExit = await confirmExitApp(context);
      if (mounted && shouldExit) SystemNavigator.pop();
      return true;
    } finally {
      _handlingBack = false;
      _confirmingExit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final navigationShell = widget.navigationShell;
    final showAddButton =
        navigationShell.currentIndex == 0 || navigationShell.currentIndex == 1;

    return BackButtonListener(
      onBackButtonPressed: _handleBack,
      child: Scaffold(
        body: Column(
          children: [
            // The banner sits above the screen content, so it owns the top inset;
            // the screens below then no longer need to pad for the status bar.
            const SafeArea(bottom: false, child: OfflineBanner()),
            Expanded(child: navigationShell),
          ],
        ),
        floatingActionButton: showAddButton
            ? FloatingActionButton(
                onPressed: () => context.push('/birthdays/new'),
                tooltip: 'Add birthday',
                child: const Icon(Icons.add, size: 28),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: palette.border),
                ),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _goBranch,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.celebration_outlined),
                      selectedIcon: Icon(Icons.celebration_rounded),
                      label: 'Birthdays',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month_rounded),
                      label: 'Calendar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
