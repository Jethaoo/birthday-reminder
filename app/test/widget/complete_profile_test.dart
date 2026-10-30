import 'package:birthday_reminder/features/auth/presentation/complete_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

void main() {
  setUp(setUpPrefs);

  testWidgets('requires a birthday date before continuing', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi();

    await tester.pumpWidget(
      wrapWithRouter(
        const CompleteProfileScreen(),
        api: api,
        auth: profileIncompleteState,
      ),
    );
    await tester.pump();

    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save my birthday'),
    );

    expect(find.text('Choose a month.'), findsOneWidget);
    expect(find.text('Choose a day.'), findsOneWidget);
    expect(api.calls['setMyBirthday'], isNull);
  });

  testWidgets('sets the one-time birthday and continues to Home', (
    tester,
  ) async {
    await useTallSurface(tester);
    final api = FakeApi();

    await tester.pumpWidget(
      wrapWithRouter(
        const CompleteProfileScreen(),
        api: api,
        auth: profileIncompleteState,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('June').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('23').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, '2000');
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save my birthday'),
    );
    await tester.pumpAndSettle();

    expect(api.calls['setMyBirthday'], 1);
    expect(find.text('STUB /home'), findsOneWidget);
  });

  testWidgets('clamps the selected day when the month changes', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi();

    await tester.pumpWidget(
      wrapWithRouter(
        const CompleteProfileScreen(),
        api: api,
        auth: profileIncompleteState,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('January').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.pumpAndSettle();
    final day31 = find.text('31').last;
    await tester.ensureVisible(day31);
    await tester.pumpAndSettle();
    await tester.tap(day31);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('February').last);
    await tester.pumpAndSettle();

    final monthField = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>).at(0),
    );
    final dayField = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>).at(1),
    );
    expect(monthField.initialValue, 2);
    expect(dayField.initialValue, 29);
    expect(find.text('29'), findsOneWidget);
    expect(find.text('31'), findsNothing);

    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save my birthday'),
    );
    await tester.pumpAndSettle();

    expect(api.user.birthdayMonth, 2);
    expect(api.user.birthdayDay, 29);
  });
}
