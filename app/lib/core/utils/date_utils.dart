import 'package:intl/intl.dart';

const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String monthName(int month) => _monthNames[(month - 1).clamp(0, 11)];

/// `30 September`
String longDate(DateTime date) => '${date.day} ${monthName(date.month)}';

/// `30 Sep`
String shortDate(DateTime date) => '${date.day} ${monthName(date.month).substring(0, 3)}';

/// `Tuesday, 23 September`
String weekdayDate(DateTime date) => '${DateFormat('EEEE').format(date)}, ${longDate(date)}';

/// `2026-09-30`, matching the API date format.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// `Today`, `Tomorrow`, `7 days`.
String countdownLabel(int daysUntil) {
  if (daysUntil == 0) return 'Today';
  if (daysUntil == 1) return 'Tomorrow';
  if (daysUntil > 1) return '$daysUntil days';
  return '${daysUntil.abs()} days ago';
}

/// `09:00` rendered as `9:00 AM`.
String formatReminderTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final hour = int.tryParse(parts[0]);
  if (hour == null) return hhmm;
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${parts[1]} $period';
}

/// Converts an hour/minute pair into the API's `HH:mm` value.
String toReminderTimeValue(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// 42 cells covering the given month, starting on Monday.
List<DateTime> buildCalendarGrid(int year, int month) {
  final firstOfMonth = DateTime(year, month, 1);
  final leadingDays = firstOfMonth.weekday - DateTime.monday;
  final start = firstOfMonth.subtract(Duration(days: leadingDays));
  return List.generate(42, (index) => DateTime(start.year, start.month, start.day + index));
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// `September 2026`
String monthTitle(int month, int year) => '${monthName(month)} $year';
