import 'package:birthday_reminder/features/calendar/presentation/calendar_screen.dart';
import 'package:birthday_reminder/shared/models/birthday.dart';
import 'package:birthday_reminder/shared/models/calendar_month.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

BirthdaySummary entry({required String id, required String name, required int day}) => BirthdaySummary(
      id: id,
      name: name,
      birthdayMonth: 9,
      birthdayDay: day,
      relationship: 'Friend',
      nextOccurrence: DateTime(2026, 9, day),
      daysUntil: 0,
      turningAge: 26,
    );

void main() {
  setUp(() {
    configureTestFonts();
    setUpPrefs();
  });

  testWidgets('shows the month grid and the birthdays for the selected day', (tester) async {
    final today = DateTime.now();
    final api = FakeApi()
      ..calendarValue = CalendarMonth(
        month: today.month,
        year: today.year,
        days: [
          CalendarDay(
            date: DateTime(today.year, today.month, today.day),
            birthdays: [entry(id: 'a', name: 'Sarah Tan', day: today.day)],
          ),
        ],
      );

    await tester.pumpWidget(wrapWithRouter(const CalendarScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Mo'), findsOneWidget);
    // Today is selected by default, so its birthdays are listed underneath.
    expect(find.text('Sarah Tan'), findsOneWidget);
    expect(api.calls['calendar'], 1);
  });

  testWidgets('loads the next month when navigating', (tester) async {
    final api = FakeApi();

    await tester.pumpWidget(wrapWithRouter(const CalendarScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.calls['calendar'], 1);

    await tapVisible(tester, find.byTooltip('Next month'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.calls['calendar'], 2);
  });
}
