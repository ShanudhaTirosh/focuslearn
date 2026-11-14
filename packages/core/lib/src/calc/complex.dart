import 'dart:math' as math;
import 'rational.dart';

/// Representation of a complex number z = a + bi.
class Complex {
  const Complex(this.real, [this.imag = 0.0]);

  final double real;
  final double imag;

  static const Complex zero = Complex(0.0, 0.0);
  static const Complex one = Complex(1.0, 0.0);
  static const Complex i = Complex(0.0, 1.0);

  /// Magnitude (modulus) |z| = sqrt(a^2 + b^2).
  double get modulus => math.sqrt(real * real + imag * imag);

  /// Argument (phase) in radians in range (-pi, pi].
  double get argument => math.atan2(imag, real);

  /// Argument in degrees (-180, 180].
  double get argumentDegrees => argument * 180.0 / math.pi;

  /// Complex conjugate a - bi.
  Complex get conjugate => Complex(real, -imag);

  Complex operator +(Complex other) => Complex(real + other.real, imag + other.imag);
  Complex operator -(Complex other) => Complex(real - other.real, imag - other.imag);
  Complex operator -() => Complex(-real, -imag);

  Complex operator *(Complex other) {
    return Complex(
      real * other.real - imag * other.imag,
      real * other.imag + imag * other.real,
    );
  }

  Complex operator /(Complex other) {
    final denom = other.real * other.real + other.imag * other.imag;
    if (denom == 0.0) throw const CalcException('division_by_zero');
    return Complex(
      (real * other.real + imag * other.imag) / denom,
      (imag * other.real - real * other.imag) / denom,
    );
  }

  /// Complex integer power z^n via polar form and De Moivre's theorem.
  Complex pow(int n) {
    if (n == 0) return Complex.one;
    if (real == 0.0 && imag == 0.0) {
      if (n < 0) throw const CalcException('division_by_zero');
      return Complex.zero;
    }
    final r = math.pow(modulus, n).toDouble();
    final theta = argument * n;
    return Complex(r * math.cos(theta), r * math.sin(theta));
  }

  /// String formatting: e.g. "3 + 4i", "5 - 2i", "3", "-4i".
  @override
  String toString([int decimals = 4]) {
    String formatDouble(double v) {
      final s = v.toStringAsFixed(decimals);
      return s.contains('.') ? s.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '') : s;
    }

    if (imag.abs() < 1e-9) return formatDouble(real);
    if (real.abs() < 1e-9) {
      if ((imag - 1.0).abs() < 1e-9) return 'i';
      if ((imag + 1.0).abs() < 1e-9) return '-i';
      return '${formatDouble(imag)}i';
    }

    final sign = imag >= 0 ? '+' : '-';
    final absImag = imag.abs();
    final imagStr = (absImag - 1.0).abs() < 1e-9 ? 'i' : '${formatDouble(absImag)}i';
    return '${formatDouble(real)} $sign $imagStr';
  }

  /// Polar representation: r ∠ θ°.
  String toPolarString([int decimals = 4]) {
    String formatDouble(double v) {
      final s = v.toStringAsFixed(decimals);
      return s.contains('.') ? s.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '') : s;
    }
    return '${formatDouble(modulus)} ∠ ${formatDouble(argumentDegrees)}°';
  }
}
