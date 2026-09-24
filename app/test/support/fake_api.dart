import 'dart:typed_data';

import 'package:birthday_reminder/core/api/api_exception.dart';
import 'package:birthday_reminder/core/api/birthday_reminder_api.dart';
import 'package:birthday_reminder/shared/models/app_user.dart';
import 'package:birthday_reminder/shared/models/birthday.dart';
import 'package:birthday_reminder/shared/models/calendar_month.dart';
import 'package:birthday_reminder/shared/models/home_summary.dart';
import 'package:birthday_reminder/shared/models/reminder.dart';
import 'package:birthday_reminder/shared/models/user_settings.dart';

/// In-memory API used by widget tests. Records calls so tests can assert on them.
class FakeApi implements BirthdayReminderApi {
  FakeApi({
    List<Birthday>? birthdays,
    HomeSummary? home,
    this.settingsValue = const UserSettings(),
    this.user = const AppUser(
      id: 'user-1',
      name: 'Jordan Davis',
      email: 'jordan@example.com',
      timezone: 'Asia/Kuala_Lumpur',
    ),
  })  : birthdaysValue = birthdays ?? [],
        homeValue = home ?? HomeSummary.empty;

  final List<Birthday> birthdaysValue;
  HomeSummary homeValue;
  UserSettings settingsValue;
  AppUser user;
  CalendarMonth? calendarValue;

  final Map<String, int> calls = {};
  final List<Birthday> created = [];
  final List<Birthday> updated = [];
  final List<String> deleted = [];
  final List<BirthdayQuery> queries = [];
  final List<Uint8List> uploads = [];
  ApiException? nextError;
  TestNotificationResult testNotificationResult =
      const TestNotificationResult(sent: 1, failed: 0, simulated: false);

  void _record(String name) => calls[name] = (calls[name] ?? 0) + 1;

  void _maybeThrow() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  @override
  String get baseUrl => 'https://api.test';

  @override
  void setAuthToken(String? token) {}

  @override
  String absoluteUrl(String relativePath) => '$baseUrl$relativePath';

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String confirmation,
    required String timezone,
  }) async {
    _record('register');
    _maybeThrow();
    user = AppUser(id: user.id, name: name, email: email, timezone: timezone);
    return AuthSession(user: user, accessToken: 'token');
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    required String timezone,
  }) async {
    _record('login');
    _maybeThrow();
    return AuthSession(user: user, accessToken: 'token');
  }

  @override
  Future<void> logout() async => _record('logout');

  @override
  Future<void> forgotPassword(String email) async {
    _record('forgotPassword');
    _maybeThrow();
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmation,
  }) async {
    _record('resetPassword');
    _maybeThrow();
  }

  @override
  Future<AppUser> me() async {
    _record('me');
    _maybeThrow();
    return user;
  }

  @override
  Future<AppUser> updateMe({String? name, String? timezone}) async {
    _record('updateMe');
    _maybeThrow();
    user = user.copyWith(name: name, timezone: timezone);
    return user;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    _record('changePassword');
    _maybeThrow();
  }

  @override
  Future<void> deleteAccount(String password) async {
    _record('deleteAccount');
    _maybeThrow();
  }

  @override
  Future<UserSettings> settings() async {
    _record('settings');
    _maybeThrow();
    return settingsValue;
  }

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    _record('updateSettings');
    _maybeThrow();
    settingsValue = settings;
    return settings;
  }

  @override
  Future<HomeSummary> home() async {
    _record('home');
    _maybeThrow();
    return homeValue;
  }

  @override
  Future<BirthdayPage> birthdays(BirthdayQuery query) async {
    _record('birthdays');
    queries.add(query);
    _maybeThrow();

    var items = birthdaysValue;
    if (query.search != null && query.search!.isNotEmpty) {
      final term = query.search!.toLowerCase();
      items = items
          .where((birthday) =>
              birthday.name.toLowerCase().contains(term) ||
              (birthday.notes ?? '').toLowerCase().contains(term))
          .toList();
    }
    if (query.filter == 'today') {
      items = items.where((birthday) => birthday.daysUntil == 0).toList();
    }

    return BirthdayPage(
      items: items.skip(query.offset).take(query.limit).toList(),
      total: items.length,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<Birthday> birthday(String id) async {
    _record('birthday');
    _maybeThrow();
    return birthdaysValue.firstWhere((birthday) => birthday.id == id);
  }

  @override
  Future<Birthday> createBirthday(Birthday birthday) async {
    _record('createBirthday');
    _maybeThrow();
    final saved = birthday.copyWith().copyWithId('birthday-${created.length + 1}');
    created.add(saved);
    birthdaysValue.add(saved);
    return saved;
  }

  @override
  Future<Birthday> updateBirthday(Birthday birthday) async {
    _record('updateBirthday');
    _maybeThrow();
    updated.add(birthday);
    final index = birthdaysValue.indexWhere((entry) => entry.id == birthday.id);
    if (index >= 0) birthdaysValue[index] = birthday;
    return birthday;
  }

  @override
  Future<void> deleteBirthday(String id) async {
    _record('deleteBirthday');
    _maybeThrow();
    deleted.add(id);
    birthdaysValue.removeWhere((birthday) => birthday.id == id);
  }

  @override
  Future<List<Reminder>> reminders(String birthdayId) async {
    _record('reminders');
    _maybeThrow();
    return birthdaysValue.firstWhere((birthday) => birthday.id == birthdayId).reminders;
  }

  @override
  Future<Reminder> createReminder(String birthdayId, Reminder reminder) async {
    _record('createReminder');
    _maybeThrow();
    return reminder;
  }

  @override
  Future<Reminder> updateReminder(String reminderId, Reminder reminder) async {
    _record('updateReminder');
    _maybeThrow();
    return reminder;
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    _record('deleteReminder');
    _maybeThrow();
  }

  @override
  Future<CalendarMonth> calendar({required int month, required int year}) async {
    _record('calendar');
    _maybeThrow();
    return calendarValue ?? CalendarMonth(month: month, year: year, days: const []);
  }

  @override
  Future<void> registerDevice({required String fcmToken, String? deviceName}) async {
    _record('registerDevice');
  }

  @override
  Future<TestNotificationResult> sendTestNotification({String? birthdayId}) async {
    _record('sendTestNotification');
    _maybeThrow();
    return testNotificationResult;
  }

  @override
  Future<String> uploadPhoto({required Uint8List bytes, required String filename}) async {
    _record('uploadPhoto');
    uploads.add(bytes);
    _maybeThrow();
    return '/api/photos/photos/${user.id}/photo.png';
  }

  @override
  Future<Uint8List> photoBytes(String relativeUrl) async => Uint8List(0);
}

extension on Birthday {
  Birthday copyWithId(String newId) => Birthday(
        id: newId,
        name: name,
        birthdayMonth: birthdayMonth,
        birthdayDay: birthdayDay,
        birthYear: birthYear,
        relationship: relationship,
        phone: phone,
        email: email,
        photoUrl: photoUrl,
        notes: notes,
        giftIdeas: giftIdeas,
        reminders: reminders,
        nextOccurrence: nextOccurrence,
        daysUntil: daysUntil,
        turningAge: turningAge,
      );
}
