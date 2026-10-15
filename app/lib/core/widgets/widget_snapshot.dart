import '../../shared/models/birthday.dart';
import '../../shared/models/home_summary.dart';

/// One person as the home screen widget needs them.
///
/// The widget gets the raw month/day rather than a precomputed countdown so it
/// can work out the days left against the device's own date. That keeps the
/// numbers right at midnight, in a different timezone, and while offline.
class WidgetBirthday {
  const WidgetBirthday({
    required this.id,
    required this.name,
    required this.month,
    required this.day,
    this.birthYear,
  });

  final String id;
  final String name;
  final int month;
  final int day;
  final int? birthYear;

  factory WidgetBirthday.fromSummary(BirthdaySummary summary) => WidgetBirthday(
        id: summary.id,
        name: summary.name,
        month: summary.birthdayMonth,
        day: summary.birthdayDay,
        birthYear: summary.birthYear,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'month': month,
        'day': day,
        if (birthYear != null) 'birthYear': birthYear,
      };
}

/// The payload the native widgets parse.
///
/// The contract is deliberately small and versioned: the Android side treats
/// anything it cannot read as "no data", so an old widget can never render half
/// a newer payload. See `docs/widgets.md`.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.birthdays,
    required this.syncedAt,
    required this.timezone,
  });

  /// Shared-preferences key the native side reads.
  static const storageKey = 'birthday_widget_snapshot';

  static const version = 1;

  /// How many people the widget keeps. Home returns at most 5 upcoming, and the
  /// nearest few are all any of the three layouts draw.
  static const maxBirthdays = 6;

  final List<WidgetBirthday> birthdays;
  final DateTime syncedAt;
  final String timezone;

  /// The widget's copy of Home: today's birthdays plus what is coming up,
  /// nearest first and deduplicated.
  factory WidgetSnapshot.fromHome(
    HomeSummary summary, {
    required String timezone,
    required DateTime syncedAt,
    int limit = maxBirthdays,
  }) {
    final seen = <String>{};
    final people = <BirthdaySummary>[];
    for (final birthday in [...summary.today, ...summary.upcoming]) {
      if (seen.add(birthday.id)) people.add(birthday);
    }
    people.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));

    return WidgetSnapshot(
      birthdays: people.take(limit).map(WidgetBirthday.fromSummary).toList(growable: false),
      syncedAt: syncedAt.toUtc(),
      timezone: timezone,
    );
  }

  /// The payload shape the native widget parses.
  Map<String, dynamic> toJson() => {
        'version': version,
        'syncedAt': syncedAt.toIso8601String(),
        'timezone': timezone,
        'birthdays': birthdays.map((birthday) => birthday.toJson()).toList(growable: false),
      };
}
