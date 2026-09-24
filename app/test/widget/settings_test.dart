import 'package:birthday_reminder/features/settings/presentation/settings_screen.dart';
import 'package:birthday_reminder/shared/models/user_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

void main() {
  setUp(() {
    configureTestFonts();
    setUpPrefs();
  });

  testWidgets('shows the account and notification preferences', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi();

    await tester.pumpWidget(wrapWithRouter(const SettingsScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Jordan Davis'), findsOneWidget);
    expect(find.text('jordan@example.com'), findsOneWidget);
    expect(find.text('Birthday reminders'), findsOneWidget);
    expect(find.text("Today's birthdays"), findsOneWidget);
    expect(find.text('7 days before'), findsOneWidget);
  });

  testWidgets('saves a toggled preference', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi();

    await tester.pumpWidget(wrapWithRouter(const SettingsScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Switches are ordered: reminders, today, tomorrow, sound.
    await tapVisible(tester, find.byType(Switch).at(1));
    await tester.pump(const Duration(milliseconds: 200));

    expect(api.calls['updateSettings'], 1);
    expect(api.settingsValue.todayEnabled, isFalse);
  });

  testWidgets('reflects a dark theme selection', (tester) async {
    await useTallSurface(tester);
    SharedPreferences.setMockInitialValues({'pref_theme_mode': 'dark'});
    final api = FakeApi(settingsValue: const UserSettings(themeMode: AppThemeMode.dark));

    await tester.pumpWidget(wrapWithRouter(const SettingsScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dark'), findsOneWidget);
  });
}
