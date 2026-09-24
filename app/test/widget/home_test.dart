import 'package:birthday_reminder/features/home/presentation/home_screen.dart';
import 'package:birthday_reminder/core/api/api_exception.dart';
import 'package:birthday_reminder/shared/models/birthday.dart';
import 'package:birthday_reminder/shared/models/home_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

HomeSummary summaryWith({required List<BirthdaySummary> today, required List<BirthdaySummary> upcoming}) =>
    HomeSummary(
      today: today,
      upcoming: upcoming,
      monthlySummary: MonthlySummary(
        month: 9,
        monthName: 'September',
        year: 2026,
        total: today.length + upcoming.length,
        upcoming: upcoming.length,
        today: today.length,
      ),
    );

BirthdaySummary summary({
  required String id,
  required String name,
  int daysUntil = 5,
  int? turningAge,
}) =>
    BirthdaySummary(
      id: id,
      name: name,
      birthdayMonth: 9,
      birthdayDay: 30,
      relationship: 'Friend',
      nextOccurrence: DateTime(2026, 9, 30),
      daysUntil: daysUntil,
      turningAge: turningAge,
    );

void main() {
  setUp(() {
    setUpPrefs();
  });

  testWidgets('shows today, upcoming and the monthly summary', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi(
      home: summaryWith(
        today: [summary(id: 'a', name: 'Sarah Tan', daysUntil: 0, turningAge: 26)],
        upcoming: [
          summary(id: 'b', name: 'Alex Lim', daysUntil: 12),
          summary(id: 'c', name: 'Jason Lee', daysUntil: 19),
        ],
      ),
    );

    await tester.pumpWidget(wrapWithRouter(const HomeScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sarah Tan'), findsOneWidget);
    expect(find.text('Turning 26'), findsOneWidget);
    expect(find.text('Alex Lim'), findsOneWidget);
    expect(find.text('A month to celebrate'), findsOneWidget);
    expect(find.text('SEPTEMBER'), findsOneWidget);
  });

  testWidgets('shows the empty state when there is nothing saved', (tester) async {
    final api = FakeApi(home: summaryWith(today: const [], upcoming: const []));

    await tester.pumpWidget(wrapWithRouter(const HomeScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No birthdays today'), findsOneWidget);
    expect(find.text('No birthdays yet'), findsOneWidget);
  });

  testWidgets('renders the error state with a retry action', (tester) async {
    final api = FakeApi()
      ..nextError = ApiException(ApiErrorCode.network, 'No internet connection.');

    await tester.pumpWidget(wrapWithRouter(const HomeScreen(), api: api, auth: signedInState));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
