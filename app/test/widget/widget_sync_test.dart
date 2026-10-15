import 'package:birthday_reminder/app/theme.dart';
import 'package:birthday_reminder/app/widget_coordinator.dart';
import 'package:birthday_reminder/app/router.dart';
import 'package:birthday_reminder/core/providers.dart';
import 'package:birthday_reminder/features/home/home_providers.dart';
import 'package:birthday_reminder/shared/models/birthday.dart';
import 'package:birthday_reminder/shared/models/home_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_api.dart';
import '../support/fake_widgets.dart';
import '../support/harness.dart';

BirthdaySummary person({
  required String id,
  required String name,
  int daysUntil = 7,
  int day = 30,
}) =>
    BirthdaySummary(
      id: id,
      name: name,
      birthdayMonth: 9,
      birthdayDay: day,
      birthYear: 2000,
      nextOccurrence: DateTime(2026, 9, day),
      daysUntil: daysUntil,
      turningAge: 26,
    );

HomeSummary homeWith({required String nextUp}) => HomeSummary(
      today: [person(id: 'birthday-1', name: 'Sarah Tan', daysUntil: 0)],
      upcoming: [person(id: 'birthday-2', name: nextUp, daysUntil: 12)],
      monthlySummary: const MonthlySummary(
        month: 9,
        monthName: 'September',
        year: 2026,
        total: 2,
        upcoming: 1,
        today: 1,
      ),
    );

ProviderContainer containerWith(FakeWidgetBridge bridge, {FakeApi? api}) {
  return ProviderContainer(
    overrides: [
      apiProvider.overrideWithValue(api ?? FakeApi(home: homeWith(nextUp: 'Alex Lim'))),
      sessionStoreProvider.overrideWithValue(FakeSessionStore()),
      deviceTimezoneProvider.overrideWith((ref) => 'Asia/Kuala_Lumpur'),
      widgetBridgeProvider.overrideWithValue(bridge),
      authControllerProvider.overrideWith(() => FakeAuthController(testUser)),
    ],
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpPrefs();
  });

  test('publishes the Home snapshot to the widgets', () async {
    final bridge = FakeWidgetBridge();
    addTearDown(bridge.dispose);
    final container = containerWith(bridge);
    addTearDown(container.dispose);

    await container.read(homeProvider.future);
    await pumpEventQueue();

    final published = bridge.snapshots.single;
    expect(published.birthdays.map((birthday) => birthday.name).toList(), [
      'Sarah Tan',
      'Alex Lim',
    ]);
    expect(published.timezone, 'Asia/Kuala_Lumpur');
    expect(bridge.updates, 1);
  });

  test('arms a refresh just after each of the next local midnights', () async {
    final bridge = FakeWidgetBridge();
    addTearDown(bridge.dispose);
    final container = containerWith(bridge);
    addTearDown(container.dispose);

    await container.read(homeProvider.future);
    await pumpEventQueue();

    expect(bridge.scheduledTimes, hasLength(3));
    expect(
      bridge.scheduledTimes.map((time) => '${time.hour}:${time.minute}').toSet(),
      {'0:5'},
    );
    expect(bridge.scheduledTimes.first.day, DateTime.now().day + 1);
  });

  test('a failed widget write never breaks the Home screen', () async {
    final bridge = FakeWidgetBridge()..failWrites = true;
    addTearDown(bridge.dispose);
    final container = containerWith(bridge);
    addTearDown(container.dispose);

    final summary = await container.read(homeProvider.future);

    expect(summary.today.single.name, 'Sarah Tan');
  });

  test('signing out takes the names back off the home screen', () async {
    final bridge = FakeWidgetBridge();
    addTearDown(bridge.dispose);
    final container = containerWith(bridge);
    addTearDown(container.dispose);

    await container.read(homeProvider.future);
    await pumpEventQueue();
    await container.read(authControllerProvider.notifier).signOut(notifyServer: false);
    await pumpEventQueue();

    expect(bridge.cleared, isTrue);
    expect(bridge.snapshots, isEmpty);
    expect(bridge.cancels, 1);
    expect(bridge.updates, 2);
  });

  testWidgets('a widget tap opens the person it points at', (tester) async {
    final bridge = FakeWidgetBridge();
    addTearDown(bridge.dispose);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('HOME'))),
        GoRoute(
          path: '/birthdays/:id',
          builder: (_, state) =>
              Scaffold(body: Text('BIRTHDAY ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(FakeApi()),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
          deviceTimezoneProvider.overrideWith((ref) => 'Asia/Kuala_Lumpur'),
          widgetBridgeProvider.overrideWithValue(bridge),
          authControllerProvider.overrideWith(() => FakeAuthController(testUser)),
          routerProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) =>
              WidgetCoordinator(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);

    bridge.emit(Uri.parse('birthdayreminder://birthdays/birthday-9'));
    await tester.pumpAndSettle();

    expect(find.text('BIRTHDAY birthday-9'), findsOneWidget);
  });
}
