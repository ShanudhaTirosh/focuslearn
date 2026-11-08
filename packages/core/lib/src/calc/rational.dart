/// A calculator input or computation failed. [code] is one of the stable codes in test-vectors/calculators.json.
class CalcException implements Exception {
  const CalcException(this.code);

  final String code;

  @override
  String toString() => 'CalcException($code)';
}

BigInt _pow10(int n) => BigInt.from(10).pow(n);

/// The integer square root (the largest r with r*r <= n) for n >= 0, by Newton's method.
BigInt integerSqrt(BigInt n) {
  if (n.isNegative) {
    throw ArgumentError('negative');
  }
  if (n < BigInt.two) {
    return n;
  }
  var x = BigInt.one << ((n.bitLength + 1) ~/ 2); // at least sqrt(n)
  while (true) {
    final y = (x + n ~/ x) ~/ BigInt.two;
    if (y >= x) {
      return x;
    }
    x = y;
  }
}

/// An exact fraction of two [BigInt]s (denominator always positive, lowest terms). No floating point anywhere.
class Rational implements Comparable<Rational> {
  Rational._(this.numerator, this.denominator);

  factory Rational(BigInt numerator, [BigInt? denominator]) {
    var den = denominator ?? BigInt.one;
    if (den == BigInt.zero) {
      throw const CalcException('division_by_zero');
    }
    var num = numerator;
    if (den.isNegative) {
      num = -num;
      den = -den;
    }
    final g = num.abs().gcd(den);
    if (g > BigInt.one) {
      num = num ~/ g;
      den = den ~/ g;
    }
    return Rational._(num, den);
  }

  factory Rational.fromInt(int n) => Rational._(BigInt.from(n), BigInt.one);

  /// Parses `-?digits(.digits)?` (the caller has already validated the text).
  factory Rational.parse(String s) {
    var text = s;
    var negative = false;
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    }
    final dot = text.indexOf('.');
    final whole = dot == -1 ? text : text.substring(0, dot);
    final frac = dot == -1 ? '' : text.substring(dot + 1);
    var n = BigInt.parse(whole + frac);
    if (negative) {
      n = -n;
    }
    return Rational(n, _pow10(frac.length));
  }

  static final Rational zero = Rational._(BigInt.zero, BigInt.one);
  static final Rational one = Rational._(BigInt.one, BigInt.one);

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;
  bool get isNegative => numerator.isNegative;

  Rational operator +(Rational o) => Rational(numerator * o.denominator + o.numerator * denominator, denominator * o.denominator);
  Rational operator -(Rational o) => Rational(numerator * o.denominator - o.numerator * denominator, denominator * o.denominator);
  Rational operator *(Rational o) => Rational(numerator * o.numerator, denominator * o.denominator);

  Rational operator /(Rational o) {
    if (o.isZero) {
      throw const CalcException('division_by_zero');
    }
    return Rational(numerator * o.denominator, denominator * o.numerator);
  }

  Rational operator -() => Rational._(-numerator, denominator);

  bool operator <(Rational o) => compareTo(o) < 0;
  bool operator <=(Rational o) => compareTo(o) <= 0;
  bool operator >(Rational o) => compareTo(o) > 0;
  bool operator >=(Rational o) => compareTo(o) >= 0;

  Rational abs() => isNegative ? -this : this;

  /// Integer power. A negative exponent of zero is a division by zero; 0^0 is 1.
  Rational pow(int e) {
    if (e >= 0) {
      return Rational._(numerator.pow(e), denominator.pow(e));
    }
    if (isZero) {
      throw const CalcException('division_by_zero');
    }
    return Rational(denominator.pow(-e), numerator.pow(-e));
  }

  /// Largest integer not above this value (Dart's ~/ truncates toward zero, so negatives are handled explicitly).
  BigInt floor() => numerator.isNegative ? -((-numerator + denominator - BigInt.one) ~/ denominator) : numerator ~/ denominator;

  /// Smallest integer not below this value.
  BigInt ceil() => numerator.isNegative ? -((-numerator) ~/ denominator) : (numerator + denominator - BigInt.one) ~/ denominator;

  @override
  int compareTo(Rational other) => (numerator * other.denominator).compareTo(other.numerator * denominator);

  @override
  bool operator ==(Object other) => other is Rational && numerator == other.numerator && denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  /// Exactly [scale] decimals, rounded half AWAY from zero, once. Never prints a negative zero.
  String toFixed(int scale) {
    final negative = numerator.isNegative;
    final a = numerator.abs() * _pow10(scale);
    var q = a ~/ denominator;
    final r = a - q * denominator;
    if (r * BigInt.two >= denominator) {
      q += BigInt.one;
    }
    final s = q.toString().padLeft(scale + 1, '0');
    final out = scale == 0 ? s : '${s.substring(0, s.length - scale)}.${s.substring(s.length - scale)}';
    return (negative && q != BigInt.zero ? '-' : '') + out;
  }

  /// Up to [maxScale] decimals with no trailing zeros and no trailing point.
  String toTrimmed([int maxScale = 10]) {
    var s = toFixed(maxScale);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s == '-0' || s.isEmpty ? '0' : s;
  }

  /// True if the value has at most [maxScale] decimals, so [toTrimmed] shows it without rounding.
  bool isExact([int maxScale = 10]) => (numerator * _pow10(maxScale)) % denominator == BigInt.zero;

  /// The square root of a non-negative value, rounded half up at [scale] decimals, using integer arithmetic only.
  String sqrtFixed(int scale) {
    final n = this * Rational(_pow10(2 * scale));
    var t = integerSqrt(n.floor());
    // round up when sqrt(n) >= t + 1/2, that is n >= t*t + t + 1/4
    if (n >= Rational(t * t + t) + Rational(BigInt.one, BigInt.from(4))) {
      t += BigInt.one;
    }
    return Rational(t, _pow10(scale)).toFixed(scale);
  }
}
