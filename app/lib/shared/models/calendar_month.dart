import 'birthday.dart';

class CalendarDay {
  const CalendarDay({required this.date, required this.birthdays});

  final DateTime date;
  final List<BirthdaySummary> birthdays;

  int get count => birthdays.length;

  factory CalendarDay.fromJson(Map<String, dynamic> json) => CalendarDay(
        date: DateTime.parse(json['date'] as String),
        birthdays: (json['birthdays'] as List<dynamic>? ?? const [])
            .map((entry) => BirthdaySummary.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().substring(0, 10),
        'count': count,
        'birthdays': birthdays.map((item) => item.toJson()).toList(),
      };
}

class CalendarMonth {
  const CalendarMonth({required this.month, required this.year, required this.days});

  final int month;
  final int year;
  final List<CalendarDay> days;

  factory CalendarMonth.fromJson(Map<String, dynamic> json) => CalendarMonth(
        month: json['month'] as int,
        year: json['year'] as int,
        days: (json['days'] as List<dynamic>? ?? const [])
            .map((entry) => CalendarDay.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'month': month,
        'year': year,
        'days': days.map((day) => day.toJson()).toList(),
      };

  CalendarDay? dayFor(DateTime date) {
    for (final day in days) {
      if (day.date.year == date.year && day.date.month == date.month && day.date.day == date.day) {
        return day;
      }
    }
    return null;
  }
}
