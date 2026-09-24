import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/widgets/offline_banner.dart';

/// Bottom-navigation shell with the glass pill bar from the design.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final showAddButton = navigationShell.currentIndex == 0 || navigationShell.currentIndex == 1;

    return Scaffold(
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
    );
  }
}
