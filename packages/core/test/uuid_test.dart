import 'dart:math';

import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:test/test.dart';

void main() {
  final pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  test('has the version 4 UUID shape', () {
    expect(generateUuidV4(Random(1)), matches(pattern));
  });

  test('sets the version and variant bits for many random values', () {
    final random = Random(42);
    for (var i = 0; i < 500; i++) {
      expect(generateUuidV4(random), matches(pattern));
    }
  });

  test('is repeatable with the same seed and different with another', () {
    expect(generateUuidV4(Random(7)), generateUuidV4(Random(7)));
    expect(generateUuidV4(Random(7)), isNot(generateUuidV4(Random(8))));
  });

  test('is accepted by the database column shape (36 characters, lower-case hex)', () {
    final id = generateUuidV4(Random.secure());
    expect(id.length, 36);
    expect(id, id.toLowerCase());
  });
}
