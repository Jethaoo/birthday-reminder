import 'package:birthday_reminder/core/widgets/widget_bridge.dart';
import 'package:birthday_reminder/core/widgets/widget_snapshot.dart';
import 'package:birthday_reminder/shared/models/birthday.dart';
import 'package:birthday_reminder/shared/models/home_summary.dart';
import 'package:flutter_test/flutter_test.dart';

BirthdaySummary summary({
  required String id,
  required String name,
  int month = 9,
  int day = 30,
  int daysUntil = 7,
  int? birthYear = 2000,
}) =>
    BirthdaySummary(
      id: id,
      name: name,
      birthdayMonth: month,
      birthdayDay: day,
      birthYear: birthYear,
      nextOccurrence: DateTime(2026, month, day),
      daysUntil: daysUntil,
      turningAge: birthYear == null ? null : 26,
    );

HomeSummary home({
  List<BirthdaySummary> today = const [],
  List<BirthdaySummary> upcoming = const [],
}) =>
    HomeSummary(
      today: today,
      upcoming: upcoming,
      monthlySummary: const MonthlySummary(
        month: 9,
        monthName: 'September',
        year: 2026,
        total: 3,
        upcoming: 2,
        today: 1,
      ),
    );

void main() {
  group('WidgetSnapshot.fromHome', () {
    test('merges today and upcoming, nearest first', () {
      final snapshot = WidgetSnapshot.fromHome(
        home(
          today: [summary(id: 'a', name: 'Sarah Tan', daysUntil: 0)],
          upcoming: [
            summary(id: 'c', name: 'Priya Nair', daysUntil: 30),
            summary(id: 'b', name: 'Alex Lim', daysUntil: 12),
          ],
        ),
        timezone: 'Asia/Kuala_Lumpur',
        syncedAt: DateTime.utc(2026, 9, 25, 14),
      );

      expect(snapshot.birthdays.map((birthday) => birthday.name), [
        'Sarah Tan',
        'Alex Lim',
        'Priya Nair',
      ]);
    });

    test('keeps one entry per person when Home lists them twice', () {
      final snapshot = WidgetSnapshot.fromHome(
        home(
          today: [summary(id: 'a', name: 'Sarah Tan', daysUntil: 0)],
          upcoming: [summary(id: 'a', name: 'Sarah Tan', daysUntil: 0)],
        ),
        timezone: 'Asia/Kuala_Lumpur',
        syncedAt: DateTime.utc(2026, 9, 25, 14),
      );

      expect(snapshot.birthdays, hasLength(1));
    });

    test('caps how many people are published', () {
      final snapshot = WidgetSnapshot.fromHome(
        home(
          upcoming: [
            for (var index = 0; index < 9; index++)
              summary(id: 'id-$index', name: 'Person $index', daysUntil: index + 1),
          ],
        ),
        timezone: 'Asia/Kuala_Lumpur',
        syncedAt: DateTime.utc(2026, 9, 25, 14),
      );

      expect(snapshot.birthdays, hasLength(WidgetSnapshot.maxBirthdays));
      expect(snapshot.birthdays.first.name, 'Person 0');
    });

    test('sends the raw date the widget counts down from', () {
      final snapshot = WidgetSnapshot.fromHome(
        home(upcoming: [summary(id: 'a', name: 'Sarah Tan', month: 2, day: 29, daysUntil: 1)]),
        timezone: 'Asia/Kuala_Lumpur',
        syncedAt: DateTime.utc(2026, 9, 25, 14),
      );

      final json = snapshot.toJson();
      expect(json['version'], 1);
      expect(json['timezone'], 'Asia/Kuala_Lumpur');
      expect(json['syncedAt'], '2026-09-25T14:00:00.000Z');
      expect(json['birthdays'], [
        {'id': 'a', 'name': 'Sarah Tan', 'month': 2, 'day': 29, 'birthYear': 2000},
      ]);
    });

    test('omits a birth year the user never entered', () {
      final snapshot = WidgetSnapshot.fromHome(
        home(upcoming: [summary(id: 'a', name: 'Sarah Tan', birthYear: null)]),
        timezone: 'Asia/Kuala_Lumpur',
        syncedAt: DateTime.utc(2026, 9, 25, 14),
      );

      expect(snapshot.toJson()['birthdays'], [
        {'id': 'a', 'name': 'Sarah Tan', 'month': 9, 'day': 30},
      ]);
    });
  });

  group('widgetRoute', () {
    test('maps the card tap to Home', () {
      expect(widgetRoute(Uri.parse('birthdayreminder://home')), '/home');
    });

    test('maps a person tap to their details screen', () {
      expect(
        widgetRoute(Uri.parse('birthdayreminder://birthdays/birthday-7')),
        '/birthdays/birthday-7',
      );
    });

    test('falls back to the birthday list without an id', () {
      expect(widgetRoute(Uri.parse('birthdayreminder://birthdays')), '/birthdays');
    });

    test('ignores anything that did not come from a widget', () {
      expect(widgetRoute(null), isNull);
      expect(widgetRoute(Uri.parse('https://example.com/home')), isNull);
      expect(widgetRoute(Uri.parse('birthdayreminder://settings')), isNull);
    });
  });
}
