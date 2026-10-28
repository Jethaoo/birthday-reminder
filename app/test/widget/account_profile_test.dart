import 'package:birthday_reminder/core/auth/auth_controller.dart';
import 'package:birthday_reminder/features/settings/presentation/account_screen.dart';
import 'package:birthday_reminder/shared/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/harness.dart';

const _userWithPhoto = AppUser(
  id: 'user-1',
  name: 'Jordan Davis',
  email: 'jordan@example.com',
  timezone: 'Asia/Kuala_Lumpur',
  photoUrl: '/api/photos/photos/user-1/profile.png',
  birthdayMonth: 1,
  birthdayDay: 15,
  birthYear: 1990,
);

void main() {
  setUp(setUpPrefs);

  testWidgets('shows the account birthday as read-only', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi();

    await tester.pumpWidget(
      wrapWithRouter(const AccountScreen(), api: api, auth: signedInState),
    );
    await tester.pump();

    expect(find.text('15 January · Born 1990'), findsOneWidget);
    expect(find.text('Set once and cannot be changed.'), findsOneWidget);
  });

  testWidgets('removes an existing profile photo', (tester) async {
    await useTallSurface(tester);
    final api = FakeApi(user: _userWithPhoto);
    const auth = AuthState(status: AuthStatus.signedIn, user: _userWithPhoto);

    await tester.pumpWidget(
      wrapWithRouter(const AccountScreen(), api: api, auth: auth),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove profile photo?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(api.calls['updateProfilePhoto'], 1);
    expect(api.user.photoUrl, isNull);
    expect(find.text('Profile photo removed'), findsOneWidget);
  });
}
