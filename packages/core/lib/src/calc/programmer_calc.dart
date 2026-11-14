import 'rational.dart';

enum NumberBase { bin, oct, dec, hex }

/// Number base conversions and bitwise integer calculator for Computer Science / ICT.
class ProgrammerCalc {
  static BigInt parse(String text, NumberBase base) {
    final clean = text.trim().replaceAll(' ', '');
    if (clean.isEmpty) return BigInt.zero;
    try {
      switch (base) {
        case NumberBase.bin:
          return BigInt.parse(clean, radix: 2);
        case NumberBase.oct:
          return BigInt.parse(clean, radix: 8);
        case NumberBase.dec:
          return BigInt.parse(clean, radix: 10);
        case NumberBase.hex:
          return BigInt.parse(clean, radix: 16);
      }
    } catch (_) {
      throw const CalcException('syntax_error');
    }
  }

  static String format(BigInt value, NumberBase base) {
    switch (base) {
      case NumberBase.bin:
        return value.toRadixString(2).toUpperCase();
      case NumberBase.oct:
        return value.toRadixString(8).toUpperCase();
      case NumberBase.dec:
        return value.toRadixString(10);
      case NumberBase.hex:
        return value.toRadixString(16).toUpperCase();
    }
  }

  static Map<NumberBase, String> convertAll(BigInt value) {
    return {
      NumberBase.bin: format(value, NumberBase.bin),
      NumberBase.oct: format(value, NumberBase.oct),
      NumberBase.dec: format(value, NumberBase.dec),
      NumberBase.hex: format(value, NumberBase.hex),
    };
  }

  static BigInt and(BigInt a, BigInt b) => a & b;
  static BigInt or(BigInt a, BigInt b) => a | b;
  static BigInt xor(BigInt a, BigInt b) => a ^ b;
  static BigInt not(BigInt a, [int bits = 32]) {
    final mask = (BigInt.one << bits) - BigInt.one;
    return (~a) & mask;
  }
  static BigInt shiftLeft(BigInt a, int shift) => a << shift;
  static BigInt shiftRight(BigInt a, int shift) => a >> shift;
}
