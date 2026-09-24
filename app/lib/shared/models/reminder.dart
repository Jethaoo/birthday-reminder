/// One reminder configured for a birthday, stored with a local wall-clock time.
class Reminder {
  const Reminder({
    required this.id,
    required this.daysBefore,
    required this.reminderTime,
    required this.enabled,
  });

  final String id;
  final int daysBefore;

  /// 24-hour `HH:mm` value interpreted in the user's timezone.
  final String reminderTime;
  final bool enabled;

  static const supportedDays = <int>[0, 1, 3, 7, 14, 30];

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        daysBefore: json['daysBefore'] as int,
        reminderTime: json['reminderTime'] as String,
        enabled: json['enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'daysBefore': daysBefore,
        'reminderTime': reminderTime,
        'enabled': enabled,
      };

  Map<String, dynamic> toRequest() => {
        'daysBefore': daysBefore,
        'reminderTime': reminderTime,
        'enabled': enabled,
      };

  Reminder copyWith({int? daysBefore, String? reminderTime, bool? enabled}) => Reminder(
        id: id,
        daysBefore: daysBefore ?? this.daysBefore,
        reminderTime: reminderTime ?? this.reminderTime,
        enabled: enabled ?? this.enabled,
      );

  /// Human label such as `On birthday`, `1 day before`, `7 days before`.
  String get label {
    if (daysBefore == 0) return 'On birthday';
    if (daysBefore == 1) return '1 day before';
    return '$daysBefore days before';
  }
}
