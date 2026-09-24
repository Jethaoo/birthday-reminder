import 'package:birthday_reminder/features/birthdays/presentation/birthdays_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

void main() {
  setUp(() {
    configureTestFonts();
    setUpPrefs();
  });

  testWidgets('lists saved birthdays with their countdown', (tester) async {
    final api = FakeApi(
      birthdays: [
        sampleBirthday(id: 'a', name: 'Sarah Tan', daysUntil: 7),
        sampleBirthday(id: 'b', name: 'Alex Lim', daysUntil: 12, relationship: 'Family'),
      ],
    );

    await tester.pumpWidget(wrapWithRouter(const BirthdaysScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sarah Tan'), findsOneWidget);
    expect(find.text('Alex Lim'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('2 birthdays'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing is saved', (tester) async {
    final api = FakeApi();

    await tester.pumpWidget(wrapWithRouter(const BirthdaysScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No birthdays yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add birthday'), findsOneWidget);
  });

  testWidgets('searches by name after the debounce', (tester) async {
    final api = FakeApi(
      birthdays: [
        sampleBirthday(id: 'a', name: 'Sarah Tan'),
        sampleBirthday(id: 'b', name: 'Alex Lim'),
      ],
    );

    await tester.pumpWidget(wrapWithRouter(const BirthdaysScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Alex Lim'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'sarah');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sarah Tan'), findsOneWidget);
    expect(find.text('Alex Lim'), findsNothing);
    expect(api.queries.last.search, 'sarah');
  });

  testWidgets('filters by today and shows the filtered empty state', (tester) async {
    final api = FakeApi(
      birthdays: [sampleBirthday(id: 'a', name: 'Sarah Tan', daysUntil: 8)],
    );

    await tester.pumpWidget(wrapWithRouter(const BirthdaysScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Today'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.queries.last.filter, 'today');
    expect(find.text('No birthdays found'), findsOneWidget);
  });
}
