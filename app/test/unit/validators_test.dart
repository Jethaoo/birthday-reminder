import 'package:birthday_reminder/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('name', () {
    test('requires a value and caps the length', () {
      expect(Validators.name('Sarah Tan'), isNull);
      expect(Validators.name('   '), 'Name is required.');
      expect(Validators.name(null), 'Name is required.');
      expect(Validators.name('x' * 121), isNotNull);
    });
  });

  group('email', () {
    test('accepts valid addresses and rejects malformed ones', () {
      expect(Validators.email('sarah@example.com'), isNull);
      expect(Validators.email('sarah@example'), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email(''), 'Email is required.');
    });

    test('is optional where allowed', () {
      expect(Validators.email('', required: false), isNull);
      expect(Validators.email('broken', required: false), isNotNull);
    });
  });

  group('password', () {
    test('enforces length and character mix', () {
      expect(Validators.password('Password123'), isNull);
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('allletters'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password(''), 'Password is required.');
    });

    test('requires a matching confirmation', () {
      expect(Validators.confirmPassword('Password123', 'Password123'), isNull);
      expect(Validators.confirmPassword('Password124', 'Password123'), isNotNull);
      expect(Validators.confirmPassword('', 'Password123'), 'Confirm your password.');
    });
  });

  group('birth year', () {
    test('is optional but bounded when present', () {
      expect(Validators.birthYear(''), isNull);
      expect(Validators.birthYear('2000'), isNull);
      expect(Validators.birthYear('1899'), isNotNull);
      expect(Validators.birthYear('ab'), isNotNull);
      expect(Validators.birthYear('${DateTime.now().year + 1}'), isNotNull);
    });
  });

  test('phone is optional with a length cap', () {
    expect(Validators.phone(''), isNull);
    expect(Validators.phone('+60 12-345 6789'), isNull);
    expect(Validators.phone('9' * 41), isNotNull);
  });
}
