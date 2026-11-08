import 'calculators.dart';
import 'rational.dart';

const int _maxDigits = 2000;

class _Tok {
  const _Tok(this.type, this.text);

  final String type; // 'n' for a number, otherwise the operator itself
  final String text;
}

bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\r' || c == '\n';

String _trimAscii(String s) {
  var a = 0;
  var b = s.length;
  while (a < b && _isSpace(s[a])) {
    a++;
  }
  while (b > a && _isSpace(s[b - 1])) {
    b--;
  }
  return s.substring(a, b);
}

List<_Tok> _tokenize(String s) {
  final out = <_Tok>[];
  final number = RegExp(r'[0-9]+(\.[0-9]+)?');
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (_isSpace(c)) {
      i++;
      continue;
    }
    final m = number.matchAsPrefix(s, i);
    if (m != null) {
      out.add(_Tok('n', m.group(0)!));
      i = m.end;
      continue;
    }
    if ('+-*/^()%'.contains(c)) {
      out.add(_Tok(c, ''));
      i++;
      continue;
    }
    throw const CalcException('syntax_error');
  }
  return out;
}

bool _tooBig(Rational v) => v.numerator.abs().toString().length > _maxDigits || v.denominator.toString().length > _maxDigits;

class _Parser {
  _Parser(this.t);

  final List<_Tok> t;
  int i = 0;

  String? peek() => i < t.length ? t[i].type : null;

  _Tok take() => t[i++];

  Rational expr() {
    var v = term();
    while (peek() == '+' || peek() == '-') {
      final op = take().type;
      final r = term();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  Rational term() {
    var v = unary();
    while (peek() == '*' || peek() == '/') {
      final op = take().type;
      final r = unary();
      if (op == '*') {
        v = v * r;
      } else {
        if (r.isZero) {
          throw const CalcException('division_by_zero');
        }
        v = v / r;
      }
      if (_tooBig(v)) {
        throw const CalcException('too_large');
      }
    }
    return v;
  }

  Rational unary() {
    if (peek() == '-') {
      take();
      return -unary();
    }
    if (peek() == '+') {
      take();
      return unary();
    }
    return power();
  }

  Rational power() {
    final base = postfix();
    if (peek() == '^') {
      take();
      final ex = unary();
      if (ex.denominator != BigInt.one) {
        throw const CalcException('non_integer_power');
      }
      final e = ex.numerator.toInt();
      if (e.abs() > 1000) {
        throw const CalcException('too_large');
      }
      if (base.isZero && e < 0) {
        throw const CalcException('division_by_zero');
      }
      if (base.numerator.abs() > BigInt.one && e.abs() * base.numerator.abs().toString().length > _maxDigits + 50) {
        throw const CalcException('too_large');
      }
      final r = base.pow(e);
      if (_tooBig(r)) {
        throw const CalcException('too_large');
      }
      return r;
    }
    return base;
  }

  Rational postfix() {
    var v = primary();
    while (peek() == '%') {
      take();
      v = v / Rational.fromInt(100);
    }
    return v;
  }

  Rational primary() {
    if (peek() == 'n') {
      final raw = take().text;
      final dot = raw.indexOf('.');
      final whole = dot == -1 ? raw : raw.substring(0, dot);
      final frac = dot == -1 ? '' : raw.substring(dot + 1);
      if (whole.length > 15 || frac.length > 10) {
        throw const CalcException('invalid_number');
      }
      return Rational.parse(raw);
    }
    if (peek() == '(') {
      take();
      final v = expr();
      if (peek() != ')') {
        throw const CalcException('syntax_error');
      }
      take();
      return v;
    }
    throw const CalcException('syntax_error');
  }
}

/// The standard calculator: + - * / ^ ( ) and a postfix %, over exact rationals (0.1 + 0.2 is exactly 0.3).
/// Powers need an integer exponent. A unary minus binds weaker than a power (-3^2 = -9) and powers associate to the right.
/// `%` is only a division by 100 (100 + 10% is 100.1).
CalcResult evaluate(String expression) {
  if (expression.runes.length > 200) {
    throw const CalcException('too_long');
  }
  if (_trimAscii(expression).isEmpty) {
    throw const CalcException('empty');
  }
  final p = _Parser(_tokenize(expression));
  final v = p.expr();
  if (p.i != p.t.length) {
    throw const CalcException('syntax_error');
  }
  return CalcResult(
    <String, Object>{'result': v.toTrimmed(), 'exact': v.isExact() ? 'true' : 'false'},
    'evaluate',
    <String>[_trimAscii(expression), '= ${v.toTrimmed()}'],
  );
}
