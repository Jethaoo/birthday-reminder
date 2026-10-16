import 'package:birthday_reminder/app/launch_splash.dart';
import 'package:birthday_reminder/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required bool ready, bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: LaunchSplash(
            ready: ready,
            child: const Scaffold(body: Text('THE APP')),
          ),
        ),
      ),
    );

void main() {
  testWidgets('plays the launch sequence over the app, then reveals it', (tester) async {
    await tester.pumpWidget(_app(ready: true));

    // The mark is on screen and the app is already mounted underneath it, so its
    // first frame — and its data — are ready by the time it is revealed.
    expect(find.byType(BirthdayAppIcon), findsOneWidget);
    expect(find.text('THE APP'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200)); // entrance and hold
    await tester.pump(const Duration(milliseconds: 700)); // exit
    await tester.pumpAndSettle(); // the app settling into place

    expect(find.byType(BirthdayAppIcon), findsNothing);
    expect(find.text('THE APP'), findsOneWidget);
  });

  testWidgets('holds on the mark until the app says it is ready', (tester) async {
    await tester.pumpWidget(_app(ready: false));

    // Well past the 1.8s sequence: revealing now would show a half-built app.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(BirthdayAppIcon), findsOneWidget);

    await tester.pumpWidget(_app(ready: true));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byType(BirthdayAppIcon), findsNothing);
    expect(find.text('THE APP'), findsOneWidget);
  });

  testWidgets('skips the animation when motion is disabled', (tester) async {
    await tester.pumpWidget(_app(ready: true, reduceMotion: true));
    expect(find.byType(BirthdayAppIcon), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(BirthdayAppIcon), findsNothing);
    expect(find.text('THE APP'), findsOneWidget);
  });
}
