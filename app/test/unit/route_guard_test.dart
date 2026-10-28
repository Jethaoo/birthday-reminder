import 'package:birthday_reminder/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  test('holds every route on the splash screen while the session resolves', () {
    // Regression: the restoring case returned null, and null means "render the
    // requested route" — so the shell built, fetched with no token attached, took
    // a 401 and ended the session it was still restoring. On every launch.
    expect(sessionRedirect(restoringState, '/home'), splashRoute);
    expect(sessionRedirect(restoringState, '/'), splashRoute);
    expect(sessionRedirect(restoringState, '/birthdays'), splashRoute);
    expect(sessionRedirect(restoringState, splashRoute), isNull);
  });

  test('a signed-in user lands on the shell, and leaves the public routes', () {
    expect(sessionRedirect(signedInState, '/home'), isNull);
    expect(sessionRedirect(signedInState, '/birthdays'), isNull);
    expect(sessionRedirect(signedInState, '/'), '/home');
    expect(sessionRedirect(signedInState, '/login'), '/home');
    // Regression: nothing sent a resolved session off the splash screen, so a
    // restored session sat on the spinner until the app was restarted again.
    expect(sessionRedirect(signedInState, splashRoute), '/home');
  });

  test('a signed-in user must set their own birthday once', () {
    expect(
      sessionRedirect(profileIncompleteState, '/home'),
      completeProfileRoute,
    );
    expect(
      sessionRedirect(profileIncompleteState, '/birthdays'),
      completeProfileRoute,
    );
    expect(
      sessionRedirect(profileIncompleteState, completeProfileRoute),
      isNull,
    );
    expect(
      sessionRedirect(profileIncompleteState, splashRoute),
      completeProfileRoute,
    );
    expect(sessionRedirect(signedInState, completeProfileRoute), '/home');
  });

  test('a signed-out user is kept on the public routes', () {
    expect(sessionRedirect(signedOutState, '/'), isNull);
    expect(sessionRedirect(signedOutState, '/login'), isNull);
    expect(sessionRedirect(signedOutState, '/home'), '/');
    expect(sessionRedirect(signedOutState, splashRoute), '/');
  });
}
