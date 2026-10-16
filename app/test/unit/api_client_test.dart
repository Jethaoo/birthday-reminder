import 'dart:convert';
import 'dart:typed_data';

import 'package:birthday_reminder/core/api/api_exception.dart';
import 'package:birthday_reminder/core/api/birthday_reminder_api.dart';
import 'package:birthday_reminder/shared/models/birthday.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a fixed status, body and content type.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body, {this.contentType = 'application/json'});

  final int status;
  final String body;
  final String contentType;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [contentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

HttpBirthdayReminderApi _api(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(validateStatus: (status) => status != null && status < 500))
    ..httpClientAdapter = adapter;
  return HttpBirthdayReminderApi(baseUrl: 'https://api.example.com', dio: dio);
}

String _error(String code, String message) => jsonEncode({
      'error': {'code': code, 'message': message},
    });

void main() {
  test('a 401 on a request sent before the token is attached does not end the session', () async {
    final adapter = _StubAdapter(401, _error('unauthorized', 'Authentication required.'));
    final api = _api(adapter);
    var sessionEnded = 0;
    api.onUnauthorized = () => sessionEnded++;

    // What a screen does when it builds before the session has been restored.
    await expectLater(api.home(), throwsA(isA<ApiException>()));

    expect(sessionEnded, 0);
  });

  test('a non-JSON 5xx page is a server error, not "no internet"', () async {
    final api = _api(_StubAdapter(502, '<html>Bad gateway</html>', contentType: 'text/html'));

    await expectLater(
      api.home(),
      throwsA(isA<ApiException>().having((error) => error.code, 'code', ApiErrorCode.server)),
    );
  });

  test('a 401 on an authenticated route reports the ended session', () async {
    // Attached, because that is what makes it an authenticated request: a 401 on
    // one that carried no token is not evidence that the session ended.
    final api = _api(_StubAdapter(401, _error('UNAUTHORIZED', 'Sign in again.')))
      ..setAuthToken('token-1');
    var notified = 0;
    api.onUnauthorized = () => notified++;

    await expectLater(api.home(), throwsA(isA<ApiException>()));
    expect(notified, 1);
  });

  test('a 401 from sign-in is a wrong password, not an ended session', () async {
    final api = _api(_StubAdapter(401, _error('UNAUTHORIZED', 'Incorrect email or password.')));
    var notified = 0;
    api.onUnauthorized = () => notified++;

    await expectLater(
      api.login(email: 'a@example.com', password: 'wrong', timezone: 'UTC'),
      throwsA(isA<ApiException>()),
    );
    expect(notified, 0);
  });

  test('registerDevice returns the server device id', () async {
    final api = _api(_StubAdapter(201, jsonEncode({'id': 'device-42', 'platform': 'android'})));
    expect(await api.registerDevice(fcmToken: 'token'), 'device-42');
  });

  test('never sends the bearer token to another host', () async {
    final adapter = _StubAdapter(200, '');
    final api = _api(adapter)..setAuthToken('secret');

    await expectLater(
      api.photoBytes('https://elsewhere.example.net/photo.png'),
      throwsA(isA<ApiException>().having((error) => error.code, 'code', ApiErrorCode.forbidden)),
    );
    expect(adapter.requests, isEmpty);
  });

  group('merging a duplicate into the saved birthday', () {
    final saved = Birthday(
      id: 'birthday-1',
      name: 'Sarah Tan',
      birthdayMonth: 9,
      birthdayDay: 30,
      birthYear: 2000,
      relationship: 'Friend',
      phone: '+60123456789',
      notes: 'Allergic to nuts',
      giftIdeas: const ['Perfume'],
      nextOccurrence: DateTime(2026, 9, 30),
      daysUntil: 7,
    );

    test('keeps saved values the new entry leaves empty', () {
      final merged = saved.mergedWith(
        Birthday(
          id: '',
          name: 'Sarah Tan',
          birthdayMonth: 9,
          birthdayDay: 30,
          giftIdeas: const ['Book', 'Perfume'],
          nextOccurrence: DateTime(2026, 9, 30),
          daysUntil: 0,
        ),
      );

      expect(merged.id, 'birthday-1');
      expect(merged.birthYear, 2000);
      expect(merged.phone, '+60123456789');
      expect(merged.notes, 'Allergic to nuts');
      expect(merged.giftIdeas, ['Perfume', 'Book']);
    });

    test('takes values the new entry does provide', () {
      final merged = saved.mergedWith(
        Birthday(
          id: '',
          name: 'Sarah Tan-Lim',
          birthdayMonth: 9,
          birthdayDay: 30,
          relationship: 'Family',
          nextOccurrence: DateTime(2026, 9, 30),
          daysUntil: 0,
        ),
      );

      expect(merged.name, 'Sarah Tan-Lim');
      expect(merged.relationship, 'Family');
    });
  });
}
