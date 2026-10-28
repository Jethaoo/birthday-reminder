import 'dart:async';

import 'package:birthday_reminder/app/theme.dart';
import 'package:birthday_reminder/core/providers.dart';
import 'package:birthday_reminder/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget harness(GoRouter router) {
    return ProviderScope(
      overrides: [
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  GoRouter shellRouter() {
    return GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => Scaffold(
                    body: Column(
                      children: [
                        const Text('HOME SCREEN'),
                        TextButton(
                          onPressed: () => context.go('/birthdays'),
                          child: const Text('GO TO BIRTHDAYS'),
                        ),
                        TextButton(
                          onPressed: () => context.push('/details'),
                          child: const Text('PUSH DETAILS'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/birthdays',
                  builder: (context, state) =>
                      const Scaffold(body: Text('BIRTHDAYS SCREEN')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/calendar',
                  builder: (context, state) =>
                      const Scaffold(body: Text('CALENDAR SCREEN')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) =>
                      const Scaffold(body: Text('SETTINGS SCREEN')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/details',
          builder: (context, state) =>
              Scaffold(appBar: AppBar(), body: const Text('DETAIL SCREEN')),
        ),
      ],
    );
  }

  Future<void> pressSystemBack(WidgetTester tester) async {
    // The future stays pending while a confirmation dialog is open.
    unawaited(tester.binding.handlePopRoute());
    await tester.pumpAndSettle();
  }

  testWidgets('system back returns to the previously visited tab', (
    tester,
  ) async {
    await tester.pumpWidget(harness(shellRouter()));
    await tester.pumpAndSettle();
    expect(find.text('HOME SCREEN'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS SCREEN'), findsOneWidget);

    await pressSystemBack(tester);

    expect(find.text('HOME SCREEN'), findsOneWidget);
    expect(find.text('SETTINGS SCREEN'), findsNothing);
  });

  testWidgets('system back unwinds each visited tab in reverse order', (
    tester,
  ) async {
    await tester.pumpWidget(harness(shellRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('CALENDAR SCREEN'), findsOneWidget);

    await pressSystemBack(tester);
    expect(find.text('SETTINGS SCREEN'), findsOneWidget);

    await pressSystemBack(tester);
    expect(find.text('HOME SCREEN'), findsOneWidget);
  });

  testWidgets('system back unwinds routes selected with go', (tester) async {
    await tester.pumpWidget(harness(shellRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GO TO BIRTHDAYS'));
    await tester.pumpAndSettle();
    expect(find.text('BIRTHDAYS SCREEN'), findsOneWidget);

    await pressSystemBack(tester);

    expect(find.text('HOME SCREEN'), findsOneWidget);
  });

  testWidgets('system back still pops a full-screen route above the shell', (
    tester,
  ) async {
    await tester.pumpWidget(harness(shellRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PUSH DETAILS'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL SCREEN'), findsOneWidget);

    await pressSystemBack(tester);

    expect(find.text('HOME SCREEN'), findsOneWidget);
    expect(find.text('DETAIL SCREEN'), findsNothing);
  });

  testWidgets('system back asks before exiting from Home', (tester) async {
    final platformCalls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(harness(shellRouter()));
    await tester.pumpAndSettle();

    await pressSystemBack(tester);
    expect(find.text('Exit app?'), findsOneWidget);
    expect(find.text('Do you want to exit Birthday Reminder?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Exit app?'), findsNothing);
    expect(find.text('HOME SCREEN'), findsOneWidget);
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      isEmpty,
    );

    await pressSystemBack(tester);
    expect(find.text('Exit app?'), findsOneWidget);
    await pressSystemBack(tester);
    expect(find.text('Exit app?'), findsNothing);
    expect(find.text('HOME SCREEN'), findsOneWidget);

    await pressSystemBack(tester);
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(
      platformCalls,
      contains(
        predicate((MethodCall call) => call.method == 'SystemNavigator.pop'),
      ),
    );
  });
}
