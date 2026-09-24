import 'package:birthday_reminder/features/settings/presentation/settings_screen.dart';
import 'package:birthday_reminder/features/settings/presentation/notification_settings_screen.dart';
import 'package:birthday_reminder/core/api/api_exception.dart';
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
    expect(find.text('Reminder & notification settings'), findsOneWidget);
    expect(find.text('Default: 7 days before at 9:00 AM'), findsOneWidget);
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

  testWidgets('keeps the notification entry reachable when preferences fail to load', (tester) async {
    await useTallSurface(tester);
    // The Worker being unreachable is exactly when the test notification is
    // needed, so this entry point must not disappear with the settings request.
    final api = FakeApi()..nextError = ApiException(ApiErrorCode.network, 'No internet connection.');

    await tester.pumpWidget(wrapWithRouter(const SettingsScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Reminder & notification settings'), findsOneWidget);
    expect(find.text('Default timing, sound and test notification'), findsOneWidget);
  });

  testWidgets('offers the test notification even when preferences fail to load', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi()..nextError = ApiException(ApiErrorCode.network, 'No internet connection.');

    await tester.pumpWidget(
      wrapWithRouter(const NotificationSettingsScreen(), api: api, auth: signedInState),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Could not load your preferences'), findsOneWidget);
    expect(find.text('Send a test notification'), findsOneWidget);
  });

  testWidgets('sends a test notification on request', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi();

    await tester.pumpWidget(
      wrapWithRouter(const NotificationSettingsScreen(), api: api, auth: signedInState),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tapVisible(tester, find.text('Send a test notification'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(api.calls['sendTestNotification'], 1);
  });
}
