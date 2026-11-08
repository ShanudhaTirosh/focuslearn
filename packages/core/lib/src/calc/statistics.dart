import 'calculators.dart';
import 'input.dart';
import 'rational.dart';

/// Count, sum, mean, median, mode(s), range, population and sample variance and standard deviation, all exact until the final rounding
/// at [scale] decimals (0 to 8, half away from zero). A sample statistic needs at least two values (otherwise it is "n/a").
CalcResult statistics(List<String> values, [int scale = 2]) {
  if (scale < 0 || scale > 8) {
    throw const CalcException('invalid_scale');
  }
  if (values.isEmpty) {
    throw const CalcException('empty_data');
  }
  if (values.length > 1000) {
    throw const CalcException('too_many_values');
  }
  final xs = values.map((v) => parseNumber(v)).toList();
  final n = xs.length;
  final nR = Rational.fromInt(n);
  var total = Rational.zero;
  for (final x in xs) {
    total += x;
  }
  final mean = total / nR;
  final sorted = List<Rational>.of(xs)..sort();
  final median = n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / Rational.fromInt(2);
  final counts = <Rational, int>{};
  for (final x in xs) {
    counts[x] = (counts[x] ?? 0) + 1;
  }
  var top = 0;
  for (final c in counts.values) {
    if (c > top) {
      top = c;
    }
  }
  final modes = top > 1 ? (counts.entries.where((e) => e.value == top).map((e) => e.key).toList()..sort()) : <Rational>[];
  var ss = Rational.zero;
  for (final x in xs) {
    final d = x - mean;
    ss += d * d;
  }
  final popVar = ss / nR;
  final out = <String, Object>{
    'count': n.toString(),
    'sum': total.toFixed(scale),
    'mean': mean.toFixed(scale),
    'median': median.toFixed(scale),
    'modes': modes.map((m) => m.toTrimmed()).toList(),
    'min': sorted.first.toFixed(scale),
    'max': sorted.last.toFixed(scale),
    'range': (sorted.last - sorted.first).toFixed(scale),
    'pop_variance': popVar.toFixed(scale),
    'pop_stdev': popVar.sqrtFixed(scale),
  };
  if (n >= 2) {
    final sv = ss / Rational.fromInt(n - 1);
    out['sample_variance'] = sv.toFixed(scale);
    out['sample_stdev'] = sv.sqrtFixed(scale);
  } else {
    out['sample_variance'] = 'n/a';
    out['sample_stdev'] = 'n/a';
  }
  return CalcResult(out, 'statistics', <String>[
    'mean = sum ÷ count',
    'mean = ${total.toFixed(scale)} ÷ $n = ${mean.toFixed(scale)}',
    'variance = sum of (value − mean)² ÷ count (population) or ÷ (count − 1) (sample)',
    'standard deviation = √variance',
  ]);
}
