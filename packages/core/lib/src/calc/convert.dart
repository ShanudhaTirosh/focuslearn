import 'calculators.dart';
import 'input.dart';
import 'rational.dart';

Rational _d(String s) => Rational.parse(s);

// Every factor is an exact decimal (international definitions: 1 in = 25.4 mm, 1 lb = 0.45359237 kg, 1 US gal = 3.785411784 L, ...).
final Map<String, Map<String, Rational>> _units = <String, Map<String, Rational>>{
  'length': <String, Rational>{'mm': _d('0.001'), 'cm': _d('0.01'), 'm': _d('1'), 'km': _d('1000'), 'in': _d('0.0254'), 'ft': _d('0.3048'), 'yd': _d('0.9144'), 'mi': _d('1609.344')},
  'mass': <String, Rational>{'mg': _d('0.000001'), 'g': _d('0.001'), 'kg': _d('1'), 't': _d('1000'), 'oz': _d('0.028349523125'), 'lb': _d('0.45359237')},
  'volume': <String, Rational>{'ml': _d('0.001'), 'l': _d('1'), 'm3': _d('1000'), 'gal': _d('3.785411784'), 'qt': _d('0.946352946'), 'pt': _d('0.473176473'), 'cup': _d('0.2365882365'), 'floz': _d('0.0295735295625')},
  'area': <String, Rational>{'cm2': _d('0.0001'), 'm2': _d('1'), 'km2': _d('1000000'), 'ha': _d('10000'), 'acre': _d('4046.8564224'), 'ft2': _d('0.09290304')},
  'time': <String, Rational>{'s': _d('1'), 'min': _d('60'), 'h': _d('3600'), 'day': _d('86400'), 'week': _d('604800')},
  'speed': <String, Rational>{'ms': _d('1'), 'kmh': Rational(BigInt.from(5), BigInt.from(18)), 'mph': _d('0.44704'), 'kn': Rational(BigInt.from(463), BigInt.from(900))},
};
const Set<String> _temperature = <String>{'c', 'f', 'k'};

final Rational _k0 = Rational.parse('273.15');
final Rational _fiveNinths = Rational(BigInt.from(5), BigInt.from(9));
final Rational _nineFifths = Rational(BigInt.from(9), BigInt.from(5));

Rational _toKelvin(Rational v, String u) => u == 'c' ? v + _k0 : (u == 'f' ? (v - Rational.fromInt(32)) * _fiveNinths + _k0 : v);
Rational _fromKelvin(Rational k, String u) => u == 'c' ? k - _k0 : (u == 'f' ? (k - _k0) * _nineFifths + Rational.fromInt(32) : k);

String? _categoryOf(String unit) {
  for (final e in _units.entries) {
    if (e.value.containsKey(unit)) {
      return e.key;
    }
  }
  return null;
}

/// Converts [value] between units of one kind (length, mass, volume, area, time, speed) or between c, f and k.
/// The result shows up to 10 decimals; `exact` says whether nothing was rounded.
CalcResult convertUnits(String value, String from, String to) {
  final v = parseNumber(value);
  final Rational r;
  if (_temperature.contains(from) || _temperature.contains(to)) {
    if (!_temperature.contains(from) || !_temperature.contains(to)) {
      final fromUnknown = !_temperature.contains(from) && _categoryOf(from) == null;
      final toUnknown = !_temperature.contains(to) && _categoryOf(to) == null;
      throw CalcException(fromUnknown || toUnknown ? 'unknown_unit' : 'incompatible_units');
    }
    final k = _toKelvin(v, from);
    if (k.isNegative) {
      throw const CalcException('below_absolute_zero');
    }
    r = _fromKelvin(k, to);
  } else {
    final catFrom = _categoryOf(from);
    final catTo = _categoryOf(to);
    if (catFrom == null || catTo == null) {
      throw const CalcException('unknown_unit');
    }
    if (catFrom != catTo) {
      throw const CalcException('incompatible_units');
    }
    r = v * _units[catFrom]![from]! / _units[catFrom]![to]!;
  }
  return CalcResult(
    <String, Object>{'result': r.toTrimmed(), 'exact': r.isExact() ? 'true' : 'false'},
    'convert',
    <String>['$from → $to', '$value $from = ${r.toTrimmed()} $to'],
  );
}
