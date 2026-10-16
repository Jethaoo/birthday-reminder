import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../shared/models/app_user.dart';
import '../../shared/models/birthday.dart';
import '../../shared/models/calendar_month.dart';
import '../../shared/models/home_summary.dart';
import '../../shared/models/reminder.dart';
import '../../shared/models/user_settings.dart';
import 'api_exception.dart';

class AuthSession {
  const AuthSession({required this.user, required this.accessToken});

  final AppUser user;
  final String accessToken;
}

/// Outcome of a development test push, so the app can report what really
/// happened instead of assuming success.
class TestNotificationResult {
  const TestNotificationResult({required this.sent, required this.failed, required this.simulated});

  final int sent;
  final int failed;
  final bool simulated;

  factory TestNotificationResult.fromJson(Map<String, dynamic> json) => TestNotificationResult(
        sent: json['sent'] as int? ?? 0,
        failed: json['failed'] as int? ?? 0,
        simulated: json['simulated'] as bool? ?? false,
      );

  /// True when nothing was delivered and no device was even targeted.
  bool get hasNoDevices => sent == 0 && failed == 0;
}

class BirthdayQuery {
  const BirthdayQuery({
    this.search,
    this.filter = 'all',
    this.sort = 'upcoming',
    this.month,
    this.year,
    this.date,
    this.limit = 50,
    this.offset = 0,
  });

  final String? search;
  final String filter;
  final String sort;
  final int? month;
  final int? year;
  final String? date;
  final int limit;
  final int offset;
}

class BirthdayPage {
  const BirthdayPage({required this.items, required this.total, required this.limit, required this.offset});

  final List<Birthday> items;
  final int total;
  final int limit;
  final int offset;

  static const empty = BirthdayPage(items: [], total: 0, limit: 50, offset: 0);
}

/// Everything the app needs from the backend, in one testable surface.
abstract class BirthdayReminderApi {
  String get baseUrl;

  void setAuthToken(String? token);

  /// Called when an authenticated request is rejected with 401, so the session
  /// can be ended instead of the app quietly showing stale data.
  set onUnauthorized(void Function()? callback);

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String confirmation,
    required String timezone,
  });

  Future<AuthSession> login({required String email, required String password, required String timezone});

  Future<void> logout();

  Future<void> forgotPassword(String email);

  Future<void> resetPassword({required String token, required String password, required String confirmation});

  Future<AppUser> me();

  Future<AppUser> updateMe({String? name, String? timezone});

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  });

  Future<void> deleteAccount(String password);

  Future<UserSettings> settings();

  Future<UserSettings> updateSettings(UserSettings settings);

  Future<HomeSummary> home();

  Future<BirthdayPage> birthdays(BirthdayQuery query);

  Future<Birthday> birthday(String id);

  Future<Birthday> createBirthday(Birthday birthday);

  Future<Birthday> updateBirthday(Birthday birthday);

  Future<void> deleteBirthday(String id);

  Future<List<Reminder>> reminders(String birthdayId);

  Future<Reminder> createReminder(String birthdayId, Reminder reminder);

  Future<Reminder> updateReminder(String reminderId, Reminder reminder);

  Future<void> deleteReminder(String reminderId);

  Future<CalendarMonth> calendar({required int month, required int year});

  /// Registers the FCM token and returns the server's device id.
  Future<String?> registerDevice({required String fcmToken, String? deviceName});

  /// Stops notifications to this device, called on sign-out.
  Future<void> unregisterDevice(String deviceId);

  Future<TestNotificationResult> sendTestNotification({String? birthdayId});

  Future<String> uploadPhoto({required Uint8List bytes, required String filename});

  Future<Uint8List> photoBytes(String relativeUrl);

  String absoluteUrl(String relativePath);
}

class HttpBirthdayReminderApi implements BirthdayReminderApi {
  HttpBirthdayReminderApi({required this.baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                validateStatus: (status) => status != null && status < 500,
              ),
            ) {
    _dio.options.baseUrl = baseUrl;
  }

  @override
  final String baseUrl;

  final Dio _dio;

  void Function()? _onUnauthorized;

  /// The token the client is currently sending, so a 401 can be traced back to
  /// the request that carried it.
  String? _token;

  @override
  set onUnauthorized(void Function()? callback) => _onUnauthorized = callback;

  @override
  void setAuthToken(String? token) {
    _token = (token == null || token.isEmpty) ? null : token;
    if (_token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }

  @override
  String absoluteUrl(String relativePath) {
    if (relativePath.startsWith('http')) return relativePath;
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return relativePath.startsWith('/') ? '$root$relativePath' : '$root/$relativePath';
  }

  /// True when [url] points at the configured backend, so the bearer token is
  /// never sent to another host.
  bool _isBackendUrl(String url) {
    final target = Uri.tryParse(url);
    final backend = Uri.tryParse(baseUrl);
    if (target == null || backend == null) return false;
    return target.scheme == backend.scheme && target.host == backend.host && target.port == backend.port;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, responseType: ResponseType.json),
      );
      return _unwrap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Map<String, dynamic> _unwrap(Response<Map<String, dynamic>> response) {
    final status = response.statusCode ?? 0;
    final data = response.data;

    if (status >= 200 && status < 300) return data ?? const <String, dynamic>{};

    // A 401 from sign-in itself means wrong credentials, not an expired session.
    // Otherwise it only ends the session when the request actually carried the
    // current token: a request that went out before the token was attached is no
    // evidence that the session expired, and treating it as such signed the user
    // out of a session that was perfectly good.
    final sentWith = response.requestOptions.headers['Authorization'];
    if (status == 401 &&
        !response.requestOptions.path.startsWith('/api/auth/') &&
        _token != null &&
        sentWith == 'Bearer $_token') {
      _onUnauthorized?.call();
    }

    final error = data?['error'] as Map<String, dynamic>?;
    throw ApiException(
      apiErrorCodeFrom(error?['code'] as String?),
      error?['message'] as String? ?? 'Something went wrong.',
      field: (error?['details'] as Map<String, dynamic>?)?['field'] as String?,
      details: error?['details'] as Map<String, dynamic>?,
    );
  }

  ApiException _mapError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ApiException.network();
      default:
        final response = error.response;
        final data = response?.data;
        if (data is Map<String, dynamic>) {
          final payload = data['error'] as Map<String, dynamic>?;
          if (payload != null) {
            return ApiException(
              apiErrorCodeFrom(payload['code'] as String?),
              payload['message'] as String? ?? 'Something went wrong.',
              field: (payload['details'] as Map<String, dynamic>?)?['field'] as String?,
              details: payload['details'] as Map<String, dynamic>?,
            );
          }
        }
        // The server answered, just not with our JSON (for example a Cloudflare
        // 502 page). That is a server problem, not a missing connection.
        if (response != null) return ApiException.server();
        return ApiException.network();
    }
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String confirmation,
    required String timezone,
  }) async {
    final json = await _request('POST', '/api/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'confirmPassword': confirmation,
      'timezone': timezone,
    });
    return _session(json);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    required String timezone,
  }) async {
    final json = await _request('POST', '/api/auth/login', body: {
      'email': email,
      'password': password,
      'timezone': timezone,
    });
    return _session(json);
  }

  AuthSession _session(Map<String, dynamic> json) => AuthSession(
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['accessToken'] as String,
      );

  @override
  Future<void> logout() async {
    await _request('POST', '/api/auth/logout');
  }

  @override
  Future<void> forgotPassword(String email) async {
    // The endpoint returns 202 for every input, so nothing to unwrap.
    await _request('POST', '/api/auth/forgot-password', body: {'email': email});
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmation,
  }) async {
    await _request('POST', '/api/auth/reset-password', body: {
      'token': token,
      'password': password,
      'confirmPassword': confirmation,
    });
  }

  @override
  Future<AppUser> me() async {
    final json = await _request('GET', '/api/me');
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<AppUser> updateMe({String? name, String? timezone}) async {
    final json = await _request('PATCH', '/api/me', body: {
      'name': ?name,
      'timezone': ?timezone,
    });
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    await _request('POST', '/api/me/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmation,
    });
  }

  @override
  Future<void> deleteAccount(String password) async {
    await _request('DELETE', '/api/me', body: {'password': password});
  }

  @override
  Future<UserSettings> settings() async {
    return UserSettings.fromJson(await _request('GET', '/api/settings'));
  }

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    return UserSettings.fromJson(
      await _request('PATCH', '/api/settings', body: settings.toJson()),
    );
  }

  @override
  Future<HomeSummary> home() async {
    return HomeSummary.fromJson(await _request('GET', '/api/home'));
  }

  @override
  Future<BirthdayPage> birthdays(BirthdayQuery query) async {
    final json = await _request('GET', '/api/birthdays', query: {
      if (query.search != null && query.search!.isNotEmpty) 'search': query.search,
      if (query.filter != 'all') 'filter': query.filter,
      'sort': query.sort,
      if (query.month != null) 'month': query.month,
      if (query.year != null) 'year': query.year,
      if (query.date != null) 'date': query.date,
      'limit': query.limit,
      'offset': query.offset,
    });

    return BirthdayPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((entry) => Birthday.fromJson(entry as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? query.limit,
      offset: json['offset'] as int? ?? query.offset,
    );
  }

  @override
  Future<Birthday> birthday(String id) async {
    return Birthday.fromJson(await _request('GET', '/api/birthdays/$id'));
  }

  @override
  Future<Birthday> createBirthday(Birthday birthday) async {
    return Birthday.fromJson(
      await _request('POST', '/api/birthdays', body: birthday.toRequest()),
    );
  }

  @override
  Future<Birthday> updateBirthday(Birthday birthday) async {
    return Birthday.fromJson(
      await _request('PUT', '/api/birthdays/${birthday.id}', body: birthday.toRequest()),
    );
  }

  @override
  Future<void> deleteBirthday(String id) async {
    await _request('DELETE', '/api/birthdays/$id');
  }

  @override
  Future<List<Reminder>> reminders(String birthdayId) async {
    final json = await _request('GET', '/api/birthdays/$birthdayId/reminders');
    return (json['items'] as List<dynamic>? ?? const [])
        .map((entry) => Reminder.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Reminder> createReminder(String birthdayId, Reminder reminder) async {
    return Reminder.fromJson(
      await _request('POST', '/api/birthdays/$birthdayId/reminders', body: reminder.toRequest()),
    );
  }

  @override
  Future<Reminder> updateReminder(String reminderId, Reminder reminder) async {
    return Reminder.fromJson(
      await _request('PATCH', '/api/reminders/$reminderId', body: reminder.toRequest()),
    );
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    await _request('DELETE', '/api/reminders/$reminderId');
  }

  @override
  Future<CalendarMonth> calendar({required int month, required int year}) async {
    return CalendarMonth.fromJson(
      await _request('GET', '/api/calendar', query: {'month': month, 'year': year}),
    );
  }

  @override
  Future<String?> registerDevice({required String fcmToken, String? deviceName}) async {
    final json = await _request('POST', '/api/devices', body: {
      'fcmToken': fcmToken,
      'platform': 'android',
      'deviceName': ?deviceName,
    });
    return json['id'] as String?;
  }

  @override
  Future<void> unregisterDevice(String deviceId) async {
    await _request('DELETE', '/api/devices/$deviceId');
  }

  @override
  Future<TestNotificationResult> sendTestNotification({String? birthdayId}) async {
    final json = await _request('POST', '/api/dev/test-notification', body: {
      'birthdayId': ?birthdayId,
    });
    return TestNotificationResult.fromJson(json);
  }

  @override
  Future<String> uploadPhoto({required Uint8List bytes, required String filename}) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    try {
      final response = await _dio.post<Map<String, dynamic>>('/api/photos', data: form);
      final json = _unwrap(response);
      return json['url'] as String;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<Uint8List> photoBytes(String relativeUrl) async {
    final url = absoluteUrl(relativeUrl);
    if (!_isBackendUrl(url)) {
      throw ApiException(ApiErrorCode.forbidden, 'Photos can only be loaded from your server.');
    }
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return Uint8List.fromList(response.data ?? const []);
      }
      throw ApiException(ApiErrorCode.server, 'Could not load the photo.');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }
}
