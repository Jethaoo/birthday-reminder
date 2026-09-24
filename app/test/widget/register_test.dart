import 'package:birthday_reminder/core/auth/auth_controller.dart';
import 'package:birthday_reminder/features/auth/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

void main() {
  setUp(() {
    configureTestFonts();
    setUpPrefs();
  });

  testWidgets('requires matching passwords', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(
      wrapWithRouter(const RegisterScreen(), api: api, auth: const AuthState.signedOut()),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'Sarah Tan');
    await tester.enterText(find.byType(TextFormField).at(1), 'sarah@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'Password124');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(api.calls['register'], isNull);
  });

  testWidgets('creates the account and continues to Home', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(
      wrapWithRouter(const RegisterScreen(), api: api, auth: const AuthState.signedOut()),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'Sarah Tan');
    await tester.enterText(find.byType(TextFormField).at(1), 'sarah@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'Password123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(api.calls['register'], 1);
    expect(find.text('STUB /home'), findsOneWidget);
  });
}
