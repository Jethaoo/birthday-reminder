import 'package:birthday_reminder/shared/models/birthday.dart';
import 'package:birthday_reminder/shared/models/home_summary.dart';
import 'package:birthday_reminder/shared/models/reminder.dart';
import 'package:birthday_reminder/shared/models/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> birthdayJson({Map<String, dynamic> overrides = const {}}) => {
      'id': 'birthday-1',
      'name': 'Sarah Tan',
      'birthdayMonth': 9,
      'birthdayDay': 30,
      'birthYear': 2000,
      'relationship': 'Friend',
      'phone': null,
      'email': null,
      'photoUrl': null,
      'notes': 'Likes travelling',
      'giftIdeas': ['Perfume'],
      'reminders': [
        {'id': 'reminder-1', 'daysBefore': 7, 'reminderTime': '09:00', 'enabled': true},
      ],
      'nextOccurrence': '2026-09-30',
      'daysUntil': 7,
      'turningAge': 26,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-02T00:00:00.000Z',
      ...overrides,
    };

void main() {
  group('Birthday', () {
    test('parses the API payload', () {
      final birthday = Birthday.fromJson(birthdayJson());
      expect(birthday.name, 'Sarah Tan');
      expect(birthday.birthdayMonth, 9);
      expect(birthday.birthdayDay, 30);
      expect(birthday.giftIdeas, ['Perfume']);
      expect(birthday.reminders.single.daysBefore, 7);
      expect(birthday.nextOccurrence, DateTime(2026, 9, 30));
      expect(birthday.daysUntil, 7);
      expect(birthday.turningAge, 26);
    });

    test('round-trips through JSON', () {
      final birthday = Birthday.fromJson(birthdayJson());
      final restored = Birthday.fromJson(birthday.toJson());
      expect(restored.name, birthday.name);
      expect(restored.notes, birthday.notes);
      expect(restored.daysUntil, birthday.daysUntil);
      expect(restored.nextOccurrence, birthday.nextOccurrence);
    });

    test('builds the request body used by create and update', () {
      final request = Birthday.fromJson(birthdayJson()).toRequest();
      expect(request['name'], 'Sarah Tan');
      expect(request['birthdayMonth'], 9);
      expect(request['birthdayDay'], 30);
      expect(request['giftIdeas'], ['Perfume']);
      expect(request['reminders'], hasLength(1));
    });

    test('derives initials and a stable colour seed', () {
      final birthday = Birthday.fromJson(birthdayJson());
      expect(birthday.initials, 'ST');
      expect(Birthday.fromJson(birthdayJson(overrides: {'name': 'Cher'})).initials, 'C');
      expect(birthday.colorSeed, Birthday.fromJson(birthdayJson()).colorSeed);
    });

    test('converts to a summary for list widgets', () {
      final summary = Birthday.fromJson(birthdayJson()).toSummary();
      expect(summary.id, 'birthday-1');
      expect(summary.daysUntil, 7);
      expect(summary.photoUrl, isNull);
    });
  });

  group('Reminder', () {
    test('labels each supported period', () {
      expect(const Reminder(id: 'a', daysBefore: 0, reminderTime: '09:00', enabled: true).label,
          'On birthday');
      expect(const Reminder(id: 'a', daysBefore: 1, reminderTime: '09:00', enabled: true).label,
          '1 day before');
      expect(const Reminder(id: 'a', daysBefore: 30, reminderTime: '09:00', enabled: true).label,
          '30 days before');
      expect(Reminder.supportedDays, [0, 1, 3, 7, 14, 30]);
    });

    test('copies with a new time or enabled flag', () {
      const reminder = Reminder(id: 'a', daysBefore: 7, reminderTime: '09:00', enabled: true);
      expect(reminder.copyWith(reminderTime: '08:00').reminderTime, '08:00');
      expect(reminder.copyWith(enabled: false).enabled, isFalse);
      expect(reminder.copyWith().id, 'a');
    });
  });

  group('HomeSummary', () {
    test('parses today, upcoming and the monthly summary', () {
      final summary = HomeSummary.fromJson({
        'today': [birthdayJson()],
        'upcoming': [birthdayJson(overrides: {'id': 'b', 'name': 'Alex Lim'})],
        'monthlySummary': {
          'month': 9,
          'monthName': 'September',
          'year': 2026,
          'total': 5,
          'upcoming': 2,
          'today': 1,
        },
      });

      expect(summary.today.single.name, 'Sarah Tan');
      expect(summary.upcoming.single.name, 'Alex Lim');
      expect(summary.monthlySummary.total, 5);
      expect(summary.monthlySummary.monthName, 'September');
    });
  });

  group('UserSettings', () {
    test('defaults match the documented behaviour', () {
      const settings = UserSettings();
      expect(settings.remindersEnabled, isTrue);
      expect(settings.todayEnabled, isTrue);
      expect(settings.tomorrowEnabled, isTrue);
      expect(settings.soundEnabled, isTrue);
      expect(settings.defaultDaysBefore, 7);
      expect(settings.defaultReminderTime, '09:00');
      expect(settings.themeMode, AppThemeMode.system);
    });

    test('parses and serialises theme modes', () {
      final parsed = UserSettings.fromJson(const {'themeMode': 'dark', 'defaultDaysBefore': 1});
      expect(parsed.themeMode, AppThemeMode.dark);
      expect(parsed.defaultDaysBefore, 1);
      expect(parsed.copyWith(themeMode: AppThemeMode.light).toJson()['themeMode'], 'light');
    });
  });
}
