/// Client mirrors of the server rules so users see errors immediately.
class Validators {
  static String? name(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Name is required.';
    if (trimmed.length > 120) return 'Name must be 120 characters or fewer.';
    return null;
  }

  static String? email(String? value, {bool required = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? 'Email is required.' : null;
    final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
    if (!pattern.hasMatch(trimmed)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required.';
    if (password.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password)) {
      return 'Password must include at least one letter and one number.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) return 'Confirm your password.';
    if (value != password) return 'Passwords do not match.';
    return null;
  }

  static String? birthYear(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final year = int.tryParse(trimmed);
    if (year == null) return 'Birth year must be a number.';
    final currentYear = DateTime.now().year;
    if (year < 1900 || year > currentYear) return 'Enter a year between 1900 and $currentYear.';
    return null;
  }

  static String? phone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 40) return 'Phone must be 40 characters or fewer.';
    return null;
  }
}
