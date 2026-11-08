// Client-side validation. Mirrors packages/core/spec/validation.json and the database constraints in
// backend/supabase/migrations. The client may be STRICTER than the database, never looser: the database is the authority.
// The behaviour is fixed by test-vectors/validation.json, which a Python reference also reproduces.
import 'dart:convert';

/// Result of validating a text field. [code] is null when the value is valid; [normalized] is the cleaned value.
class ValidationResult {
  const ValidationResult(this.code, this.normalized);

  final String? code;
  final String normalized;

  bool get ok => code == null;
}

/// Numbers and lists shared with the database. Keep in sync with the spec (a test checks the SQL side).
abstract final class ValidationRules {
  static const int displayNameMin = 1;
  static const int displayNameMax = 40;
  static const int deviceNameMin = 1;
  static const int deviceNameMax = 60;
  static const int birthYearDbMin = 1950;
  static const int birthYearDbMax = 2100;
  static const int clientMinAge = 13;
  static const int clientMaxAge = 80;
  static const int possibleMinorYearDifference = 19;
  static const int subjectsMaxCount = 12;
  static const int subjectsMaxJoinedLength = 720;
  static const int subjectMaxLength = 60;
  static const int emailMaxLength = 254;
  static const int passwordMinLength = 10;
  static const int passwordMaxBytes = 72;
  static const int emailLocalPartCheckMinLength = 4;
  static const List<String> streams = <String>[
    'technology',
    'commerce',
    'science',
    'mathematics',
    'arts',
    'other',
  ];
  static const List<String> commonPasswords = <String>[
    'password',
    'password1',
    'password12',
    'password123',
    '1234567890',
    '12345678910',
    '0123456789',
    'qwertyuiop',
    '1q2w3e4r5t',
    'iloveyou12',
    'srilanka123',
    'colombo123',
    'welcome123',
    'abc1234567',
    'letmein123',
    'admin12345',
    'focuslearn',
    'focuslearn1',
    'focuslearn123',
  ];
}

// Unicode White_Space, spelled out so that Dart and Python agree exactly (Dart's trim() also strips U+FEFF).
const Set<int> _whitespace = <int>{
  0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680, //
  0x2028, 0x2029, 0x202F, 0x205F, 0x3000,
};

bool _isWhitespace(int r) => _whitespace.contains(r) || (r >= 0x2000 && r <= 0x200A);

/// Control characters: C0 (below U+0020), DEL, and C1 (U+0080 to U+009F). Zero-width joiners are NOT control characters
/// (Sinhala and Tamil need them).
bool _isControl(int r) => r < 0x20 || (r >= 0x7F && r <= 0x9F);

/// Removes only U+0020 at both ends, like PostgreSQL's btrim().
String _trimSpaces(String s) {
  var start = 0;
  var end = s.length;
  while (start < end && s.codeUnitAt(start) == 0x20) {
    start++;
  }
  while (end > start && s.codeUnitAt(end - 1) == 0x20) {
    end--;
  }
  return s.substring(start, end);
}

/// Removes the explicit White_Space set at both ends.
String _trimWhitespace(String s) {
  final runes = s.runes.toList();
  var start = 0;
  var end = runes.length;
  while (start < end && _isWhitespace(runes[start])) {
    start++;
  }
  while (end > start && _isWhitespace(runes[end - 1])) {
    end--;
  }
  return String.fromCharCodes(runes.sublist(start, end));
}

/// Trims the explicit Unicode White_Space set (the same set the Python reference uses).
String trimUnicodeWhitespace(String s) => _trimWhitespace(s);

/// Characters, not UTF-16 units: one emoji is one character, like PostgreSQL's char_length().
int _length(String s) => s.runes.length;

ValidationResult _validateName(String s, int min, int max) {
  for (final r in s.runes) {
    if (_isControl(r)) {
      return ValidationResult('control_char', s);
    }
  }
  final t = _trimSpaces(s);
  if (_length(t) < min || t.runes.every(_isWhitespace)) {
    return ValidationResult('blank', t);
  }
  if (_length(t) > max) {
    return ValidationResult('too_long', t);
  }
  return ValidationResult(null, t);
}

ValidationResult validateDisplayName(String s) =>
    _validateName(s, ValidationRules.displayNameMin, ValidationRules.displayNameMax);

ValidationResult validateDeviceName(String s) =>
    _validateName(s, ValidationRules.deviceNameMin, ValidationRules.deviceNameMax);

/// True for anyone who could still be under 18 this calendar year (a year of birth cannot tell exactly).
bool isPossibleMinor(int birthYear, int currentYear) =>
    currentYear - birthYear < ValidationRules.possibleMinorYearDifference;

/// Returns null when valid, otherwise an error code.
String? validateBirthYear(int year, int currentYear) {
  if (year > currentYear || year < ValidationRules.birthYearDbMin || year > ValidationRules.birthYearDbMax) {
    return 'out_of_range';
  }
  final age = currentYear - year;
  if (age < ValidationRules.clientMinAge) {
    return 'too_young';
  }
  if (age > ValidationRules.clientMaxAge) {
    return 'out_of_range';
  }
  return null;
}

final RegExp _emailPattern = RegExp(r'^[^@ \t\r\n]+@[^@ \t\r\n]+\.[^@ \t\r\n]+$');

ValidationResult validateEmail(String s) {
  final t = _trimWhitespace(s);
  if (t.isEmpty) {
    return ValidationResult('blank', t);
  }
  if (_length(t) > ValidationRules.emailMaxLength) {
    return ValidationResult('too_long', t);
  }
  if (!_emailPattern.hasMatch(t)) {
    return ValidationResult('invalid_format', t);
  }
  return ValidationResult(null, t);
}

/// Returns null when acceptable. Length counts characters; the maximum counts UTF-8 bytes (bcrypt-based auth limit).
/// No composition rules (NIST 800-63B). The blocklist is a tiny convenience, not a leaked-password check.
String? validatePassword(String password, String email) {
  if (_length(password) < ValidationRules.passwordMinLength) {
    return 'too_short';
  }
  if (utf8.encode(password).length > ValidationRules.passwordMaxBytes) {
    return 'too_long';
  }
  final lower = password.toLowerCase();
  if (ValidationRules.commonPasswords.contains(lower)) {
    return 'common_password';
  }
  final at = email.indexOf('@');
  final local = at >= 0 ? email.substring(0, at).toLowerCase() : '';
  if (_length(local) >= ValidationRules.emailLocalPartCheckMinLength && lower.contains(local)) {
    return 'contains_email';
  }
  return null;
}

String? validateStream(String s) => ValidationRules.streams.contains(s) ? null : 'unknown_value';

String? validateSubjects(List<String> items) {
  if (items.length > ValidationRules.subjectsMaxCount) {
    return 'too_many';
  }
  for (final x in items) {
    if (_trimSpaces(x).isEmpty || x.runes.every(_isWhitespace)) {
      return 'blank';
    }
    if (_length(x) > ValidationRules.subjectMaxLength) {
      return 'too_long';
    }
  }
  if (_length(items.join(',')) > ValidationRules.subjectsMaxJoinedLength) {
    return 'too_long';
  }
  return null;
}

final RegExp _avatarKeyPattern = RegExp(r'^objects/[0-9a-f-]{36}/[0-9a-f-]{36}$');

/// An avatar key must live in the user's own folder: `objects/<user id>/<file id>`.
String? validateAvatarKey(String key, String userId) {
  if (!_avatarKeyPattern.hasMatch(key)) {
    return 'invalid_format';
  }
  if (key.split('/')[1] != userId) {
    return 'wrong_owner';
  }
  return null;
}

final RegExp _timeZonePattern = RegExp(r'^[A-Za-z_]+(/[A-Za-z0-9_+-]+)*$');

/// Format only. The database checks the name against pg_timezone_names.
String? validateTimeZone(String s) => _timeZonePattern.hasMatch(s) ? null : 'invalid_format';

const List<String> _secretKeyPrefixes = <String>['sb_secret_'];
const List<String> _forbiddenJwtRoles = <String>['service_role'];

/// The role claim of a JWT-shaped token, or null if the text does not decode as one.
String? _jwtRole(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final data = jsonDecode(payload);
    if (data is Map<String, dynamic>) {
      final role = data['role'];
      return role is String ? role : null;
    }
    return null;
  } on FormatException {
    return null;
  }
}

/// Refuses a key that must never ship inside an app (a secret key or a legacy service_role JWT).
/// Returns null for a publishable key or an anon JWT.
String? validateClientKey(String key) {
  final k = _trimWhitespace(key);
  if (k.isEmpty) {
    return 'blank';
  }
  for (final prefix in _secretKeyPrefixes) {
    if (k.startsWith(prefix)) {
      return 'secret_key';
    }
  }
  final role = _jwtRole(k);
  if (role != null && _forbiddenJwtRoles.contains(role)) {
    return 'secret_key';
  }
  return null;
}

const Map<String, String> _authErrorKinds = <String, String>{
  'invalid_credentials': 'invalid_credentials',
  'email_not_confirmed': 'email_not_confirmed',
  'over_request_rate_limit': 'rate_limited',
  'over_email_send_rate_limit': 'rate_limited',
  'captcha_failed': 'captcha_failed',
  'weak_password': 'weak_password',
  'user_already_exists': 'email_taken',
  'email_exists': 'email_taken',
  'same_password': 'same_password',
};

/// Maps an Auth failure to a coarse kind for the UI. Codes are GoTrue error codes (verify against the Auth server).
/// The UI must never reveal whether an account exists.
String authErrorKind({String? code, int? statusCode, bool network = false}) {
  if (network) {
    return 'network';
  }
  if (code != null && _authErrorKinds.containsKey(code)) {
    return _authErrorKinds[code]!;
  }
  if (statusCode == 429) {
    return 'rate_limited';
  }
  if (statusCode != null && statusCode >= 500) {
    return 'server';
  }
  return 'unknown';
}
