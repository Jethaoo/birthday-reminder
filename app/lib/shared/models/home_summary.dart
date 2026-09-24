import 'birthday.dart';

class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.monthName,
    required this.year,
    required this.total,
    required this.upcoming,
    required this.today,
  });

  final int month;
  final String monthName;
  final int year;
  final int total;
  final int upcoming;
  final int today;

  factory MonthlySummary.fromJson(Map<String, dynamic> json) => MonthlySummary(
        month: json['month'] as int? ?? 1,
        monthName: json['monthName'] as String? ?? 'January',
        year: json['year'] as int? ?? DateTime.now().year,
        total: json['total'] as int? ?? 0,
        upcoming: json['upcoming'] as int? ?? 0,
        today: json['today'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'month': month,
        'monthName': monthName,
        'year': year,
        'total': total,
        'upcoming': upcoming,
        'today': today,
      };
}

class HomeSummary {
  const HomeSummary({
    required this.today,
    required this.upcoming,
    required this.monthlySummary,
  });

  final List<BirthdaySummary> today;
  final List<BirthdaySummary> upcoming;
  final MonthlySummary monthlySummary;

  factory HomeSummary.fromJson(Map<String, dynamic> json) => HomeSummary(
        today: (json['today'] as List<dynamic>? ?? const [])
            .map((entry) => BirthdaySummary.fromJson(entry as Map<String, dynamic>))
            .toList(),
        upcoming: (json['upcoming'] as List<dynamic>? ?? const [])
            .map((entry) => BirthdaySummary.fromJson(entry as Map<String, dynamic>))
            .toList(),
        monthlySummary: MonthlySummary.fromJson(
          (json['monthlySummary'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
        ),
      );

  Map<String, dynamic> toJson() => {
        'today': today.map((item) => item.toJson()).toList(),
        'upcoming': upcoming.map((item) => item.toJson()).toList(),
        'monthlySummary': monthlySummary.toJson(),
      };

  static const empty = HomeSummary(
    today: [],
    upcoming: [],
    monthlySummary: MonthlySummary(
      month: 1,
      monthName: 'January',
      year: 2026,
      total: 0,
      upcoming: 0,
      today: 0,
    ),
  );
}
