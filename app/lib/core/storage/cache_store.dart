import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/birthday.dart';
import '../../shared/models/calendar_month.dart';
import '../../shared/models/home_summary.dart';
import '../../shared/models/user_settings.dart';

/// Last-known-good snapshots so the app can render something while offline.
///
/// The backend stays the source of truth: cached data is only ever read when a
/// request fails, and mutations are never queued.
class CacheStore {
  static const _homeKey = 'cache_home';
  static const _birthdaysKey = 'cache_birthdays';
  static const _settingsKey = 'cache_settings';
  static const _themeKey = 'pref_theme_mode';
  static const _syncedAtKey = 'cache_synced_at';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveHome(HomeSummary summary) async {
    final prefs = await _prefs;
    await prefs.setString(_homeKey, jsonEncode(summary.toJson()));
    await prefs.setString(_syncedAtKey, DateTime.now().toIso8601String());
  }

  Future<HomeSummary?> readHome() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_homeKey);
    if (raw == null) return null;
    try {
      return HomeSummary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBirthdays(List<Birthday> birthdays) async {
    final prefs = await _prefs;
    await prefs.setString(
      _birthdaysKey,
      jsonEncode(birthdays.map((birthday) => birthday.toJson()).toList()),
    );
    await prefs.setString(_syncedAtKey, DateTime.now().toIso8601String());
  }

  Future<List<Birthday>?> readBirthdays() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_birthdaysKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((entry) => Birthday.fromJson(entry as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCalendar(CalendarMonth month) async {
    final prefs = await _prefs;
    await prefs.setString('cache_calendar_${month.year}_${month.month}', jsonEncode(month.toJson()));
  }

  Future<CalendarMonth?> readCalendar(int year, int month) async {
    final prefs = await _prefs;
    final raw = prefs.getString('cache_calendar_${year}_$month');
    if (raw == null) return null;
    try {
      return CalendarMonth.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSettings(UserSettings settings) async {
    final prefs = await _prefs;
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    await prefs.setString(_themeKey, settings.themeMode.name);
  }

  Future<UserSettings?> readSettings() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return null;
    try {
      return UserSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveThemeMode(AppThemeMode mode) async {
    final prefs = await _prefs;
    await prefs.setString(_themeKey, mode.name);
  }

  Future<AppThemeMode> readThemeMode() async {
    final prefs = await _prefs;
    return themeModeFrom(prefs.getString(_themeKey));
  }

  Future<DateTime?> lastSyncedAt() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_syncedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    for (final key in prefs.getKeys().where((key) => key.startsWith('cache_')).toList()) {
      await prefs.remove(key);
    }
  }
}
