import 'package:birthday_reminder/features/birthdays/presentation/birthday_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

void main() {
  testWidgets('shows the birthday', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi(
      birthdays: [sampleBirthday(id: 'birthday-1', name: 'Alex Lim', notes: 'Likes travelling')],
    );

    await tester.pumpWidget(
      wrapWithRouter(
        const BirthdayDetailsScreen(birthdayId: 'birthday-1'),
        api: api,
        auth: signedInState,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Alex Lim'), findsOneWidget);
    expect(find.text('Likes travelling'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Edit birthday'), findsOneWidget);
  });

  testWidgets('back goes to the birthday list instead of closing the app', (tester) async {
    await useTallSurface(tester);
    // Regression: a notification opens this screen with nothing beneath it, so
    // popping the last route closed the app rather than returning anywhere.
    final api = FakeApi(birthdays: [sampleBirthday(id: 'birthday-1', name: 'Alex Lim')]);

    await tester.pumpWidget(
      wrapWithRouter(
        const BirthdayDetailsScreen(birthdayId: 'birthday-1'),
        api: api,
        auth: signedInState,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tapVisible(tester, find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('STUB /birthdays'), findsOneWidget);
  });

  testWidgets('says Tomorrow rather than Tomorrow left, with the actions pinned', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeApi(birthdays: [sampleBirthday(id: 'birthday-1', daysUntil: 1)]);

    await tester.pumpWidget(
      wrapWithRouter(
        const BirthdayDetailsScreen(birthdayId: 'birthday-1'),
        api: api,
        auth: signedInState,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Regression: the pill built its sentence by hand, so a birthday tomorrow
    // read "Tomorrow left" (and a past one "3 days ago left").
    expect(find.text('🎂 Tomorrow'), findsOneWidget);
    expect(find.textContaining('Tomorrow left'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Edit birthday').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Delete').hitTestable(), findsOneWidget);
  });
}
