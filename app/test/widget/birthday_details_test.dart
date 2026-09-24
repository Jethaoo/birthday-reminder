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
}
