import 'package:birthday_reminder/core/api/api_exception.dart';
import 'package:birthday_reminder/core/auth/auth_controller.dart';
import 'package:birthday_reminder/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

void main() {
  setUp(() {
    configureTestFonts();
    setUpPrefs();
  });

  testWidgets('validates empty fields before calling the API', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(
      wrapWithRouter(const LoginScreen(), api: api, auth: const AuthState.signedOut()),
    );
    await tester.pump();

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(api.calls['login'], isNull);
  });

  testWidgets('rejects an invalid email before submitting', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(
      wrapWithRouter(const LoginScreen(), api: api, auth: const AuthState.signedOut()),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(api.calls['login'], isNull);
  });

  testWidgets('signs in and lands on Home', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(
      wrapWithRouter(const LoginScreen(), api: api, auth: const AuthState.signedOut()),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'jordan@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(api.calls['login'], 1);
    expect(find.text('STUB /home'), findsOneWidget);
  });

  testWidgets('shows the server message when credentials are rejected', (tester) async {
    final api = FakeApi()
      ..nextError = ApiException(ApiErrorCode.unauthorized, 'Incorrect email or password.');

    await tester.pumpWidget(
      wrapWithRouter(const LoginScreen(), api: api, auth: const AuthState.signedOut()),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'jordan@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });
}
