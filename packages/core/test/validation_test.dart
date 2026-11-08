// Runs the shared vectors (test-vectors/validation.json) against the Dart implementation.
// A Python reference reproduces the same vectors (packages/core/tools/test_validation_contract.py).
// Run from packages/core:  dart test
import 'dart:convert';
import 'dart:io';

import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> _loadVectors() {
  final file = File('../../test-vectors/validation.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<Map<String, dynamic>> _cases(Map<String, dynamic> v, String group) =>
    (v[group] as List<dynamic>).map((dynamic e) => e as Map<String, dynamic>).toList();

void main() {
  final vectors = _loadVectors();

  group('displayName', () {
    for (final c in _cases(vectors, 'displayName')) {
      test(c['name'] as String, () {
        final r = validateDisplayName(c['in'] as String);
        expect(r.code ?? 'ok', c['client']);
        if (c.containsKey('normalized')) {
          expect(r.normalized, c['normalized']);
        }
      });
    }
  });

  group('deviceName', () {
    for (final c in _cases(vectors, 'deviceName')) {
      test(c['name'] as String, () {
        final r = validateDeviceName(c['in'] as String);
        expect(r.code ?? 'ok', c['client']);
        if (c.containsKey('normalized')) {
          expect(r.normalized, c['normalized']);
        }
      });
    }
  });

  group('birthYear', () {
    for (final c in _cases(vectors, 'birthYear')) {
      test(c['name'] as String, () {
        final year = c['year'] as int;
        final now = c['now'] as int;
        expect(validateBirthYear(year, now) ?? 'ok', c['client']);
        expect(isPossibleMinor(year, now), c['minor']);
      });
    }
  });

  group('email', () {
    for (final c in _cases(vectors, 'email')) {
      test(c['name'] as String, () {
        final r = validateEmail(c['in'] as String);
        expect(r.code ?? 'ok', c['client']);
        if (c.containsKey('normalized')) {
          expect(r.normalized, c['normalized']);
        }
      });
    }
  });

  group('password', () {
    for (final c in _cases(vectors, 'password')) {
      test(c['name'] as String, () {
        expect(validatePassword(c['in'] as String, c['email'] as String) ?? 'ok', c['client']);
      });
    }
  });

  group('stream', () {
    for (final c in _cases(vectors, 'stream')) {
      test(c['name'] as String, () {
        expect(validateStream(c['in'] as String) ?? 'ok', c['client']);
      });
    }
  });

  group('subjects', () {
    for (final c in _cases(vectors, 'subjects')) {
      test(c['name'] as String, () {
        final items = (c['in'] as List<dynamic>).map((dynamic e) => e as String).toList();
        expect(validateSubjects(items) ?? 'ok', c['client']);
      });
    }
  });

  group('avatarKey', () {
    for (final c in _cases(vectors, 'avatarKey')) {
      test(c['name'] as String, () {
        expect(validateAvatarKey(c['in'] as String, c['user'] as String) ?? 'ok', c['client']);
      });
    }
  });

  group('timeZone', () {
    for (final c in _cases(vectors, 'timeZone')) {
      test(c['name'] as String, () {
        expect(validateTimeZone(c['in'] as String) ?? 'ok', c['client']);
      });
    }
  });

  group('clientKey', () {
    for (final c in _cases(vectors, 'clientKey')) {
      test(c['name'] as String, () {
        expect(validateClientKey(c['in'] as String) ?? 'ok', c['client']);
      });
    }
  });

  group('authError', () {
    for (final c in _cases(vectors, 'authError')) {
      test(c['name'] as String, () {
        expect(
          authErrorKind(code: c['code'] as String?, statusCode: c['status'] as int?, network: c['network'] as bool),
          c['kind'],
        );
      });
    }
  });

  test('the vectors cover every group the implementation validates', () {
    expect(
      vectors.keys.toSet(),
      containsAll(<String>{
        'displayName', 'deviceName', 'birthYear', 'email', 'password', 'stream', 'subjects', 'avatarKey', 'timeZone', 'clientKey', 'authError',
      }),
    );
  });
}
