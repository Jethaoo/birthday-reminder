import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/models/app_user.dart';

/// Persists the access token in the platform keystore.
class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'birthday_access_token';
  static const _userKey = 'birthday_session_user';
  static const _deviceKey = 'birthday_device_id';

  Future<void> save({required String token, required AppUser user}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<AppUser?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// The server id of this device's push registration, so sign-out can remove it.
  Future<void> saveDeviceId(String deviceId) => _storage.write(key: _deviceKey, value: deviceId);

  Future<String?> readDeviceId() => _storage.read(key: _deviceKey);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _deviceKey);
  }

  /// Removes everything, including entries that can no longer be decrypted (for
  /// example after a backup was restored onto a new device).
  Future<void> wipe() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      // Nothing more can be done; the next save overwrites the entries.
    }
  }
}
