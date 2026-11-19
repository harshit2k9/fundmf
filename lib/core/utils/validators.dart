/// Form validation shared by the auth screens and the admin provisioning form.
abstract final class Validators {
  /// Indian PAN: five letters, four digits, one letter (e.g. ABCDE1234F).
  static final RegExp panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$',
  );

  static final RegExp _phonePattern = RegExp(r'^[6-9][0-9]{9}$');

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String normalizePan(String value) => value.trim().toUpperCase();

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email address is required';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? pan(String? value) {
    final v = normalizePan(value ?? '');
    if (v.isEmpty) return 'PAN number is required';
    if (!panPattern.hasMatch(v)) return 'PAN must look like ABCDE1234F';
    return null;
  }

  static String? phone(String? value) {
    final v = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (v.isEmpty) return 'Phone number is required';
    if (!_phonePattern.hasMatch(v)) return 'Enter a 10-digit Indian mobile number';
    return null;
  }

  static String? required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  static bool isValidPan(String value) => panPattern.hasMatch(normalizePan(value));
}
