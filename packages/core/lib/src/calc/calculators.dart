import 'input.dart';
import 'rational.dart';

/// The outcome of a calculator: named values (text, or a list of text), the formula id, and the steps to show.
class CalcResult {
  const CalcResult(this.values, this.formula, this.steps);

  final Map<String, Object> values;
  final String formula;
  final List<String> steps;
}

Rational _r(int n) => Rational.fromInt(n);
String _f(Rational x, [int scale = 2]) => x.toFixed(scale);
final Rational _hundred = Rational.fromInt(100);

// ---------------------------------------------------------------- percentage
CalcResult percentOf(String percent, String base) {
  final p = parseNumber(percent);
  final b = parseNumber(base);
  final r = b * p / _hundred;
  return CalcResult(<String, Object>{'result': _f(r)}, 'percent_of', <String>['x = base × percent ÷ 100', 'x = $base × $percent ÷ 100', 'x = ${_f(r)}']);
}

CalcResult percentWhat(String part, String whole) {
  final a = parseNumber(part);
  final w = parseNumber(whole);
  if (w.isZero) {
    throw const CalcException('division_by_zero');
  }
  final r = a / w * _hundred;
  return CalcResult(<String, Object>{'percent': _f(r)}, 'percent_what', <String>['percent = part ÷ whole × 100', 'percent = $part ÷ $whole × 100', 'percent = ${_f(r)}']);
}

CalcResult percentChange(String from, String to) {
  final a = parseNumber(from, nonNegative: true);
  final b = parseNumber(to, nonNegative: true);
  if (a.isZero) {
    throw const CalcException('division_by_zero');
  }
  final r = (b - a) / a * _hundred;
  return CalcResult(<String, Object>{'percent': _f(r)}, 'percent_change', <String>['change = (new − old) ÷ old × 100', 'change = ($to − $from) ÷ $from × 100', 'change = ${_f(r)}']);
}

CalcResult percentIncrease(String base, String percent) {
  final b = parseNumber(base);
  final p = parseNumber(percent, nonNegative: true);
  final r = b * (Rational.one + p / _hundred);
  return CalcResult(<String, Object>{'result': _f(r)}, 'percent_increase', <String>['new = base × (1 + percent ÷ 100)', 'new = $base × (1 + $percent ÷ 100)', 'new = ${_f(r)}']);
}

CalcResult percentDecrease(String base, String percent) {
  final b = parseNumber(base);
  final p = parseNumber(percent, nonNegative: true);
  if (p > _hundred) {
    throw const CalcException('percent_over_100');
  }
  final r = b * (Rational.one - p / _hundred);
  return CalcResult(<String, Object>{'result': _f(r)}, 'percent_decrease', <String>['new = base × (1 − percent ÷ 100)', 'new = $base × (1 − $percent ÷ 100)', 'new = ${_f(r)}']);
}

// ---------------------------------------------------------------- ratio
CalcResult ratioSimplify(List<String> parts) {
  if (parts.length < 2) {
    throw const CalcException('need_two_parts');
  }
  if (parts.length > 10) {
    throw const CalcException('too_many_parts');
  }
  final vals = parts.map((p) => parseNumber(p, nonNegative: true)).toList();
  var d = 0;
  for (final p in parts) {
    final dot = p.indexOf('.');
    final decimals = dot == -1 ? 0 : p.length - dot - 1;
    if (decimals > d) {
      d = decimals;
    }
  }
  final scale = Rational(BigInt.from(10).pow(d));
  final ints = vals.map((v) => (v * scale).numerator).toList();
  var g = BigInt.zero;
  for (final i in ints) {
    g = g.gcd(i);
  }
  if (g == BigInt.zero) {
    throw const CalcException('all_zero');
  }
  final out = ints.map((i) => (i ~/ g).toString()).toList();
  return CalcResult(<String, Object>{'parts': out}, 'ratio_simplify', <String>['divide every part by the greatest common divisor', '${parts.join(' : ')} = ${out.join(' : ')}']);
}

CalcResult ratioSplit(String amount, List<String> parts) {
  final a = parseNumber(amount, nonNegative: true);
  if ((a * _hundred).denominator != BigInt.one) {
    throw const CalcException('too_many_decimals');
  }
  if (parts.length < 2) {
    throw const CalcException('need_two_parts');
  }
  final vals = parts.map(parseInteger).toList();
  if (parts.length > 10) {
    throw const CalcException('too_many_parts');
  }
  final total = vals.fold<int>(0, (s, v) => s + v);
  if (total == 0) {
    throw const CalcException('all_zero');
  }
  final cents = (a * _hundred).numerator;
  final exact = vals.map((v) => Rational(cents * BigInt.from(v), BigInt.from(total))).toList();
  final floors = exact.map((e) => e.floor()).toList();
  var left = (cents - floors.fold<BigInt>(BigInt.zero, (s, f) => s + f)).toInt();
  final order = List<int>.generate(vals.length, (i) => i)
    ..sort((x, y) {
      final rx = exact[x] - Rational(floors[x]);
      final ry = exact[y] - Rational(floors[y]);
      final c = ry.compareTo(rx); // larger remainder first
      return c != 0 ? c : x.compareTo(y); // ties: earlier part first
    });
  for (final i in order) {
    if (left <= 0) {
      break;
    }
    floors[i] += BigInt.one;
    left--;
  }
  final shares = floors.map((c) => Rational(c, BigInt.from(100)).toFixed(2)).toList();
  return CalcResult(<String, Object>{'shares': shares}, 'ratio_split', <String>[
    'share = amount × part ÷ sum of parts, rounded down to cents',
    'the leftover cents go to the largest remainders (ties: earlier part first)',
    '${shares.join(' + ')} = ${_f(a)}',
  ]);
}

CalcResult proportion(String a, String b, String c) {
  final x = parseNumber(a);
  final y = parseNumber(b);
  final z = parseNumber(c);
  if (x.isZero) {
    throw const CalcException('division_by_zero');
  }
  final r = y * z / x;
  return CalcResult(<String, Object>{'x': r.toTrimmed()}, 'proportion', <String>['a : b = c : x, so x = b × c ÷ a', 'x = $b × $c ÷ $a', 'x = ${r.toTrimmed()}']);
}

// ---------------------------------------------------------------- profit and loss
CalcResult profitLoss(String cost, String selling) {
  final c = parseNumber(cost, positive: true);
  final s = parseNumber(selling, nonNegative: true);
  final d = s - c;
  final kind = d > Rational.zero ? 'profit' : (d < Rational.zero ? 'loss' : 'even');
  final onCost = _f(d.abs() / c * _hundred);
  final onSell = s > Rational.zero ? _f(d.abs() / s * _hundred) : 'n/a';
  return CalcResult(
    <String, Object>{'kind': kind, 'amount': _f(d.abs()), 'percent_on_cost': onCost, 'percent_on_selling': onSell},
    'profit_loss',
    <String>[
      'Profit or loss = selling price − cost price',
      '= $selling − $cost = ${_f(d)}',
      'Percent on cost = |difference| ÷ cost × 100 = $onCost',
      'Margin on selling price = |difference| ÷ selling price × 100 = $onSell',
    ],
  );
}

CalcResult sellingFromMarkup(String cost, String markup) {
  final c = parseNumber(cost, positive: true);
  final m = parseNumber(markup, nonNegative: true);
  final r = c * (Rational.one + m / _hundred);
  return CalcResult(<String, Object>{'selling': _f(r)}, 'selling_from_markup', <String>['selling = cost × (1 + markup ÷ 100)', 'selling = $cost × (1 + $markup ÷ 100)', 'selling = ${_f(r)}']);
}

CalcResult sellingFromMargin(String cost, String margin) {
  final c = parseNumber(cost, positive: true);
  final m = parseNumber(margin, nonNegative: true);
  if (m >= _hundred) {
    throw const CalcException('margin_must_be_below_100');
  }
  final r = c / (Rational.one - m / _hundred);
  return CalcResult(<String, Object>{'selling': _f(r)}, 'selling_from_margin', <String>['selling = cost ÷ (1 − margin ÷ 100)', 'selling = $cost ÷ (1 − $margin ÷ 100)', 'selling = ${_f(r)}']);
}

// ---------------------------------------------------------------- interest
CalcResult simpleInterest(String principal, String rate, String years) {
  final p = parseNumber(principal, nonNegative: true);
  final r = parseNumber(rate, nonNegative: true);
  final t = parseNumber(years, nonNegative: true);
  final i = p * r * t / _hundred;
  final a = p + i;
  return CalcResult(<String, Object>{'interest': _f(i), 'amount': _f(a)}, 'simple_interest', <String>[
    'I = P × r × t ÷ 100',
    'I = $principal × $rate × $years ÷ 100',
    'I = ${_f(i)}',
    'A = P + I = $principal + ${_f(i)} = ${_f(a)}',
  ]);
}

CalcResult compoundInterest(String principal, String rate, String perYear, String years) {
  final p = parseNumber(principal, nonNegative: true);
  final r = parseNumber(rate, nonNegative: true);
  final t = parseNumber(years, nonNegative: true);
  final n = parseInteger(perYear, positive: true);
  if (n > 365) {
    throw const CalcException('invalid_frequency');
  }
  final periods = _r(n) * t;
  if (periods.denominator != BigInt.one) {
    throw const CalcException('periods_not_integer');
  }
  if (periods > _r(1200)) {
    throw const CalcException('too_many_periods');
  }
  final a = p * (Rational.one + r / (_hundred * _r(n))).pow(periods.numerator.toInt());
  return CalcResult(<String, Object>{'amount': _f(a), 'interest': _f(a - p)}, 'compound_interest', <String>[
    'A = P × (1 + r ÷ (100 × n)) ^ (n × t)',
    'A = $principal × (1 + $rate ÷ (100 × $perYear)) ^ ($perYear × $years)',
    'A = ${_f(a)}',
    'I = A − P = ${_f(a)} − $principal = ${_f(a - p)}',
  ]);
}

// ---------------------------------------------------------------- break-even and accounting equation
CalcResult breakEven(String fixedCosts, String price, String variable) {
  final f = parseNumber(fixedCosts, nonNegative: true);
  final p = parseNumber(price, nonNegative: true);
  final v = parseNumber(variable, nonNegative: true);
  if (p <= v) {
    throw const CalcException('no_break_even');
  }
  final cm = p - v;
  final units = f / cm;
  final up = units.ceil();
  final rev = units * p;
  return CalcResult(
    <String, Object>{'contribution_margin': _f(cm), 'units': units.toTrimmed(), 'units_rounded_up': up.toString(), 'revenue': _f(rev)},
    'break_even',
    <String>[
      'Contribution margin = price − variable cost',
      '= $price − $variable = ${_f(cm)}',
      'Break-even units = fixed costs ÷ contribution margin',
      '= $fixedCosts ÷ ${_f(cm)} = ${units.toTrimmed()}',
      'Whole units needed = $up',
      'Break-even revenue = $fixedCosts ÷ ${_f(cm)} × $price = ${_f(rev)}',
    ],
  );
}

/// Exactly one of the three values must be null: that one is calculated.
CalcResult accountingEquation(String? assets, String? liabilities, String? equity) {
  final missing = <String>[if (assets == null) 'assets', if (liabilities == null) 'liabilities', if (equity == null) 'equity'];
  if (missing.length != 1) {
    throw const CalcException('need_exactly_one_missing');
  }
  final a = assets == null ? null : parseNumber(assets, nonNegative: true);
  final l = liabilities == null ? null : parseNumber(liabilities, nonNegative: true);
  final e = equity == null ? null : parseNumber(equity);
  final m = missing.first;
  final Rational v;
  final String formula;
  if (m == 'assets') {
    v = l! + e!;
    formula = 'Assets = Liabilities + Equity';
  } else if (m == 'liabilities') {
    v = a! - e!;
    formula = 'Liabilities = Assets − Equity';
  } else {
    v = a! - l!;
    formula = 'Equity = Assets − Liabilities';
  }
  if (m != 'equity' && v.isNegative) {
    throw const CalcException('negative_result');
  }
  return CalcResult(<String, Object>{'missing': m, 'value': _f(v)}, 'accounting_equation', <String>['Assets = Liabilities + Equity', formula, '$m = ${_f(v)}']);
}
