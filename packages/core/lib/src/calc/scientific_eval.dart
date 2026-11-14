import 'dart:math' as math;
import 'input.dart';
import 'rational.dart';

enum AngleUnit { radians, degrees, gradians }

/// Scientific mathematical constants for A/L Mathematics, Physics, and Chemistry.
class ScientificConstants {
  static const double pi = 3.14159265358979323846;
  static const double e = 2.71828182845904523536;
  static const double c = 299792458.0; // Speed of light (m/s)
  static const double h = 6.62607015e-34; // Planck constant (J s)
  static const double G = 6.67430e-11; // Gravitational constant (m^3 kg^-1 s^-2)
  static const double k = 1.380649e-23; // Boltzmann constant (J/K)
  static const double NA = 6.02214076e23; // Avogadro constant (mol^-1)
  static const double R = 8.314462618; // Universal gas constant (J/(mol K))
  static const double F = 96485.33212; // Faraday constant (C/mol)
  static const double g = 9.80665; // Standard acceleration due to gravity (m/s^2)
}

/// Evaluator for scientific mathematical expressions.
class ScientificEvaluator {
  ScientificEvaluator({this.angleUnit = AngleUnit.degrees});

  final AngleUnit angleUnit;

  double toRadians(double angle) {
    switch (angleUnit) {
      case AngleUnit.radians:
        return angle;
      case AngleUnit.degrees:
        return angle * math.pi / 180.0;
      case AngleUnit.gradians:
        return angle * math.pi / 200.0;
    }
  }

  double fromRadians(double rad) {
    switch (angleUnit) {
      case AngleUnit.radians:
        return rad;
      case AngleUnit.degrees:
        return rad * 180.0 / math.pi;
      case AngleUnit.gradians:
        return rad * 200.0 / math.pi;
    }
  }

  /// Evaluates an expression string and returns the double result.
  double evaluate(String expression, {Map<String, double>? variables}) {
    final sanitized = _preprocess(expression);
    final tokens = _tokenize(sanitized);
    final parser = _ScientificParser(tokens, this, variables ?? const {});
    final result = parser.parseExpression();
    if (result.isNaN) {
      throw const CalcException('domain_error');
    }
    if (result.isInfinite) {
      throw const CalcException('division_by_zero');
    }
    return result;
  }

  /// Calculates exact BigInt factorial.
  static BigInt factorial(int n) {
    if (n < 0) throw const CalcException('domain_error');
    if (n > 1000) throw const CalcException('overflow');
    var res = BigInt.one;
    for (var i = 2; i <= n; i++) {
      res *= BigInt.from(i);
    }
    return res;
  }

  /// Calculates permutations nPr = n! / (n - r)!
  static BigInt permutations(int n, int r) {
    if (n < 0 || r < 0 || r > n) throw const CalcException('domain_error');
    var res = BigInt.one;
    for (var i = n - r + 1; i <= n; i++) {
      res *= BigInt.from(i);
    }
    return res;
  }

  /// Calculates combinations nCr = n! / (r! * (n - r)!)
  static BigInt combinations(int n, int r) {
    if (n < 0 || r < 0 || r > n) throw const CalcException('domain_error');
    if (r == 0 || r == n) return BigInt.one;
    final k = r > n - r ? n - r : r;
    var res = BigInt.one;
    for (var i = 1; i <= k; i++) {
      res = (res * BigInt.from(n - i + 1)) ~/ BigInt.from(i);
    }
    return res;
  }

  static String _preprocess(String s) {
    var out = s
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('√', 'sqrt');
    return out;
  }

  static List<_Tok> _tokenize(String s) {
    final tokens = <_Tok>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
        i++;
        continue;
      }

      // Numbers with scientific notation (e.g., 1.5e-3)
      if (_isDigit(c) || (c == '.' && i + 1 < s.length && _isDigit(s[i + 1]))) {
        final start = i;
        while (i < s.length && (_isDigit(s[i]) || s[i] == '.')) {
          i++;
        }
        if (i < s.length && (s[i] == 'e' || s[i] == 'E') && i + 1 < s.length && (_isDigit(s[i + 1]) || s[i + 1] == '+' || s[i + 1] == '-')) {
          i++;
          if (s[i] == '+' || s[i] == '-') i++;
          while (i < s.length && _isDigit(s[i])) {
            i++;
          }
        }
        tokens.add(_Tok(_TokType.number, s.substring(start, i)));
        continue;
      }

      // Identifiers: functions, constants, variable names
      if (_isAlpha(c) || c == '_') {
        final start = i;
        while (i < s.length && (_isAlphaNum(s[i]) || s[i] == '_')) {
          i++;
        }
        tokens.add(_Tok(_TokType.identifier, s.substring(start, i)));
        continue;
      }

      // Operators and punctuation
      if ('+-*/^%(),!'.contains(c)) {
        tokens.add(_Tok(_TokType.symbol, c));
        i++;
        continue;
      }

      throw const CalcException('syntax_error');
    }
    return tokens;
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  static bool _isAlpha(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }
  static bool _isAlphaNum(String c) => _isDigit(c) || _isAlpha(c);
}

enum _TokType { number, identifier, symbol }

class _Tok {
  const _Tok(this.type, this.text);
  final _TokType type;
  final String text;
}

class _ScientificParser {
  _ScientificParser(this.tokens, this.evaluator, this.variables);

  final List<_Tok> tokens;
  final ScientificEvaluator evaluator;
  final Map<String, double> variables;
  int _pos = 0;

  _Tok? get _current => _pos < tokens.length ? tokens[_pos] : null;

  _Tok _consume() {
    final t = _current;
    if (t == null) throw const CalcException('syntax_error');
    _pos++;
    return t;
  }

  bool _match(String text) {
    if (_current != null && _current!.text == text) {
      _pos++;
      return true;
    }
    return false;
  }

  double parseExpression() {
    var result = _parseTerm();
    while (_pos < tokens.length) {
      if (_match('+')) {
        result += _parseTerm();
      } else if (_match('-')) {
        result -= _parseTerm();
      } else {
        break;
      }
    }
    return result;
  }

  double _parseTerm() {
    var result = _parseFactor();
    while (_pos < tokens.length) {
      if (_match('*')) {
        result *= _parseFactor();
      } else if (_match('/')) {
        final divisor = _parseFactor();
        if (divisor == 0.0) throw const CalcException('division_by_zero');
        result /= divisor;
      } else if (_match('%')) {
        final divisor = _parseFactor();
        if (divisor == 0.0) throw const CalcException('division_by_zero');
        result %= divisor;
      } else if (_isImplicitMultiplication()) {
        // e.g. 2pi or (2)(3) or 2sin(x)
        result *= _parseFactor();
      } else {
        break;
      }
    }
    return result;
  }

  bool _isImplicitMultiplication() {
    final t = _current;
    if (t == null) return false;
    if (t.type == _TokType.number || t.type == _TokType.identifier || t.text == '(') {
      return true;
    }
    return false;
  }

  double _parseFactor() {
    final base = _parseUnary();
    if (_match('^')) {
      final exponent = _parseFactor(); // Right-associative
      return math.pow(base, exponent).toDouble();
    }
    return base;
  }

  double _parseUnary() {
    if (_match('-')) {
      return -_parseUnary();
    }
    if (_match('+')) {
      return _parseUnary();
    }
    return _parsePostfix();
  }

  double _parsePostfix() {
    var val = _parsePrimary();
    while (_match('!')) {
      final intVal = val.round();
      if ((val - intVal).abs() > 1e-9 || intVal < 0) {
        throw const CalcException('domain_error');
      }
      val = ScientificEvaluator.factorial(intVal).toDouble();
    }
    return val;
  }

  double _parsePrimary() {
    final t = _current;
    if (t == null) throw const CalcException('syntax_error');

    if (t.type == _TokType.number) {
      _consume();
      final v = double.tryParse(t.text);
      if (v == null) throw const CalcException('syntax_error');
      return v;
    }

    if (t.type == _TokType.identifier) {
      _consume();
      final name = t.text;

      // Check if followed by parentheses -> function call
      if (_match('(')) {
        final args = <double>[];
        if (!_match(')')) {
          while (true) {
            args.add(parseExpression());
            if (_match(',')) continue;
            if (_match(')')) break;
            throw const CalcException('syntax_error');
          }
        }
        return _evalFunction(name, args);
      }

      // Check variables or constants
      return _evalIdentifier(name);
    }

    if (_match('(')) {
      final v = parseExpression();
      if (!_match(')')) throw const CalcException('syntax_error');
      return v;
    }

    throw const CalcException('syntax_error');
  }

  double _evalIdentifier(String name) {
    if (variables.containsKey(name)) {
      return variables[name]!;
    }
    switch (name.toLowerCase()) {
      case 'pi':
        return ScientificConstants.pi;
      case 'e':
        return ScientificConstants.e;
      case 'c':
        return ScientificConstants.c;
      case 'h':
        return ScientificConstants.h;
      case 'g':
        return ScientificConstants.g;
      case 'na':
        return ScientificConstants.NA;
      case 'r':
        return ScientificConstants.R;
      case 'f':
        return ScientificConstants.F;
      case 'k':
        return ScientificConstants.k;
      default:
        throw const CalcException('syntax_error');
    }
  }

  double _evalFunction(String fn, List<double> args) {
    final name = fn.toLowerCase();
    if (args.isEmpty) throw const CalcException('syntax_error');

    final x = args[0];

    switch (name) {
      // Trigonometric
      case 'sin':
        final rad = evaluator.toRadians(x);
        return math.sin(rad);
      case 'cos':
        final rad = evaluator.toRadians(x);
        return math.cos(rad);
      case 'tan':
        final rad = evaluator.toRadians(x);
        final c = math.cos(rad);
        if (c.abs() < 1e-15) throw const CalcException('division_by_zero');
        return math.tan(rad);
      case 'asin':
        if (x < -1.0 || x > 1.0) throw const CalcException('domain_error');
        return evaluator.fromRadians(math.asin(x));
      case 'acos':
        if (x < -1.0 || x > 1.0) throw const CalcException('domain_error');
        return evaluator.fromRadians(math.acos(x));
      case 'atan':
        return evaluator.fromRadians(math.atan(x));
      case 'atan2':
        if (args.length < 2) throw const CalcException('syntax_error');
        return evaluator.fromRadians(math.atan2(args[0], args[1]));

      // Hyperbolic
      case 'sinh':
        return (math.exp(x) - math.exp(-x)) / 2.0;
      case 'cosh':
        return (math.exp(x) + math.exp(-x)) / 2.0;
      case 'tanh':
        final e1 = math.exp(x);
        final e2 = math.exp(-x);
        return (e1 - e2) / (e1 + e2);
      case 'asinh':
        return math.log(x + math.sqrt(x * x + 1.0));
      case 'acosh':
        if (x < 1.0) throw const CalcException('domain_error');
        return math.log(x + math.sqrt(x * x - 1.0));
      case 'atanh':
        if (x <= -1.0 || x >= 1.0) throw const CalcException('domain_error');
        return 0.5 * math.log((1.0 + x) / (1.0 - x));

      // Logarithms & Roots
      case 'ln':
        if (x <= 0.0) throw const CalcException('domain_error');
        return math.log(x);
      case 'log':
      case 'log10':
        if (x <= 0.0) throw const CalcException('domain_error');
        return math.log(x) / math.ln10;
      case 'log2':
        if (x <= 0.0) throw const CalcException('domain_error');
        return math.log(x) / math.ln2;
      case 'logb':
        if (args.length < 2 || x <= 0.0 || args[1] <= 0.0 || args[1] == 1.0) {
          throw const CalcException('domain_error');
        }
        return math.log(x) / math.log(args[1]);
      case 'sqrt':
        if (x < 0.0) throw const CalcException('domain_error');
        return math.sqrt(x);
      case 'cbrt':
        return x >= 0 ? math.pow(x, 1.0 / 3.0).toDouble() : -math.pow(-x, 1.0 / 3.0).toDouble();
      case 'root':
        if (args.length < 2) throw const CalcException('syntax_error');
        final n = args[1];
        if (n == 0.0) throw const CalcException('domain_error');
        return math.pow(x, 1.0 / n).toDouble();
      case 'pow':
        if (args.length < 2) throw const CalcException('syntax_error');
        return math.pow(args[0], args[1]).toDouble();

      // Number Theory & Rounding
      case 'abs':
        return x.abs();
      case 'floor':
        return x.floorToDouble();
      case 'ceil':
        return x.ceilToDouble();
      case 'round':
        return x.roundToDouble();
      case 'fact':
        final n = x.round();
        if ((x - n).abs() > 1e-9 || n < 0) throw const CalcException('domain_error');
        return ScientificEvaluator.factorial(n).toDouble();
      case 'npr':
        if (args.length < 2) throw const CalcException('syntax_error');
        return ScientificEvaluator.permutations(args[0].round(), args[1].round()).toDouble();
      case 'ncr':
        if (args.length < 2) throw const CalcException('syntax_error');
        return ScientificEvaluator.combinations(args[0].round(), args[1].round()).toDouble();
      case 'mod':
        if (args.length < 2 || args[1] == 0.0) throw const CalcException('division_by_zero');
        return args[0] % args[1];

      default:
        throw const CalcException('syntax_error');
    }
  }
}
