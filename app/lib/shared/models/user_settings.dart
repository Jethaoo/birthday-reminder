enum AppThemeMode { system, light, dark }

AppThemeMode themeModeFrom(String? value) => switch (value) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };

class UserSettings {
  const UserSettings({
    this.remindersEnabled = true,
    this.todayEnabled = true,
    this.tomorrowEnabled = true,
    this.soundEnabled = true,
    this.defaultDaysBefore = 7,
    this.defaultReminderTime = '09:00',
    this.themeMode = AppThemeMode.system,
  });

  final bool remindersEnabled;
  final bool todayEnabled;
  final bool tomorrowEnabled;
  final bool soundEnabled;
  final int defaultDaysBefore;
  final String defaultReminderTime;
  final AppThemeMode themeMode;

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        remindersEnabled: json['remindersEnabled'] as bool? ?? true,
        todayEnabled: json['todayEnabled'] as bool? ?? true,
        tomorrowEnabled: json['tomorrowEnabled'] as bool? ?? true,
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        defaultDaysBefore: json['defaultDaysBefore'] as int? ?? 7,
        defaultReminderTime: json['defaultReminderTime'] as String? ?? '09:00',
        themeMode: themeModeFrom(json['themeMode'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'remindersEnabled': remindersEnabled,
        'todayEnabled': todayEnabled,
        'tomorrowEnabled': tomorrowEnabled,
        'soundEnabled': soundEnabled,
        'defaultDaysBefore': defaultDaysBefore,
        'defaultReminderTime': defaultReminderTime,
        'themeMode': themeMode.name,
      };

  UserSettings copyWith({
    bool? remindersEnabled,
    bool? todayEnabled,
    bool? tomorrowEnabled,
    bool? soundEnabled,
    int? defaultDaysBefore,
    String? defaultReminderTime,
    AppThemeMode? themeMode,
  }) =>
      UserSettings(
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        todayEnabled: todayEnabled ?? this.todayEnabled,
        tomorrowEnabled: tomorrowEnabled ?? this.tomorrowEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        defaultDaysBefore: defaultDaysBefore ?? this.defaultDaysBefore,
        defaultReminderTime: defaultReminderTime ?? this.defaultReminderTime,
        themeMode: themeMode ?? this.themeMode,
      );
}
