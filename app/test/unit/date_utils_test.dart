import 'package:birthday_reminder/core/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countdown labels', () {
    test('describes today, tomorrow and later dates', () {
      expect(countdownLabel(0), 'Today');
      expect(countdownLabel(1), 'Tomorrow');
      expect(countdownLabel(7), '7 days');
      expect(countdownLabel(-3), '3 days ago');
    });
  });

  group('date formatting', () {
    test('uses the documented short and long forms', () {
      final date = DateTime(2026, 9, 30);
      expect(longDate(date), '30 September');
      expect(shortDate(date), '30 Sep');
      expect(monthTitle(9, 2026), 'September 2026');
      expect(isoDate(date), '2026-09-30');
    });

    test('formats 24-hour reminder times as 12-hour labels', () {
      expect(formatReminderTime('09:00'), '9:00 AM');
      expect(formatReminderTime('00:30'), '12:30 AM');
      expect(formatReminderTime('13:45'), '1:45 PM');
      expect(formatReminderTime('not-a-time'), 'not-a-time');
    });

    test('converts picker values back to HH:mm', () {
      expect(toReminderTimeValue(9, 5), '09:05');
      expect(toReminderTimeValue(0, 0), '00:00');
    });
  });

  group('calendar grid', () {
    test('always returns six Monday-first weeks', () {
      final grid = buildCalendarGrid(2026, 9);
      expect(grid, hasLength(42));
      expect(grid.first.weekday, DateTime.monday);
      expect(grid.first, DateTime(2026, 8, 31));
      expect(grid.last, DateTime(2026, 10, 11));
    });

    test('matches weekdays for a month starting on Monday', () {
      final grid = buildCalendarGrid(2026, 6);
      expect(grid.first, DateTime(2026, 6, 1));
    });
  });

  test('isSameDay ignores the time component', () {
    expect(isSameDay(DateTime(2026, 9, 30, 8), DateTime(2026, 9, 30, 22)), isTrue);
    expect(isSameDay(DateTime(2026, 9, 30), DateTime(2026, 10, 1)), isFalse);
  });
}
