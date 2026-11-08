// Runs the shared calculator vectors (test-vectors/calculators.json) against the Dart implementation.
// A Python reference reproduces the same vectors (packages/core/tools/test_calc_contract.py).
// Run from packages/core:  dart test
import 'dart:convert';
import 'dart:io';

import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:test/test.dart';

List<String> _strings(dynamic v) => (v as List<dynamic>).map((dynamic e) => e as String).toList();

CalcResult _run(String fn, List<dynamic> a) {
  String s(int i) => a[i] as String;
  switch (fn) {
    case 'percent_of':
      return percentOf(s(0), s(1));
    case 'percent_what':
      return percentWhat(s(0), s(1));
    case 'percent_change':
      return percentChange(s(0), s(1));
    case 'percent_increase':
      return percentIncrease(s(0), s(1));
    case 'percent_decrease':
      return percentDecrease(s(0), s(1));
    case 'ratio_simplify':
      return ratioSimplify(_strings(a[0]));
    case 'ratio_split':
      return ratioSplit(s(0), _strings(a[1]));
    case 'proportion':
      return proportion(s(0), s(1), s(2));
    case 'profit_loss':
      return profitLoss(s(0), s(1));
    case 'selling_from_markup':
      return sellingFromMarkup(s(0), s(1));
    case 'selling_from_margin':
      return sellingFromMargin(s(0), s(1));
    case 'simple_interest':
      return simpleInterest(s(0), s(1), s(2));
    case 'compound_interest':
      return compoundInterest(s(0), s(1), s(2), s(3));
    case 'break_even':
      return breakEven(s(0), s(1), s(2));
    case 'accounting_equation':
      return accountingEquation(a[0] as String?, a[1] as String?, a[2] as String?);
    case 'statistics':
      return statistics(_strings(a[0]), a[1] as int);
    case 'convert':
      return convertUnits(s(0), s(1), s(2));
    case 'evaluate':
      return evaluate(s(0));
  }
  throw ArgumentError('unknown function $fn');
}

void main() {
  final doc = jsonDecode(File('../../test-vectors/calculators.json').readAsStringSync()) as Map<String, dynamic>;
  final cases = (doc['cases'] as List<dynamic>).map((dynamic e) => e as Map<String, dynamic>).toList();

  group('vectors', () {
    for (final c in cases) {
      final fn = c['fn'] as String;
      final args = c['args'] as List<dynamic>;
      test('$fn: ${c['name']}', () {
        if (c.containsKey('error')) {
          expect(() => _run(fn, args), throwsA(isA<CalcException>().having((e) => e.code, 'code', c['error'])));
          return;
        }
        final r = _run(fn, args);
        (c['out'] as Map<String, dynamic>).forEach((key, dynamic want) {
          expect(r.values[key], want, reason: 'field $key');
        });
        if (c.containsKey('steps')) {
          expect(r.steps, _strings(c['steps']));
        }
        expect(r.steps.length, greaterThanOrEqualTo(2));
        expect(r.formula, isNotEmpty);
      });
    }
  });

  group('Rational (the places where Dart BigInt differs from Python int)', () {
    Rational r(int n, [int d = 1]) => Rational(BigInt.from(n), BigInt.from(d));

    test('0.1 + 0.2 is exactly 0.3 and 1/3 * 3 is exactly 1', () {
      expect(Rational.parse('0.1') + Rational.parse('0.2'), Rational.parse('0.3'));
      expect(r(1, 3) * r(3), Rational.one);
    });
    test('toFixed rounds exact halves away from zero and never prints a negative zero', () {
      expect(Rational.parse('0.125').toFixed(2), '0.13');
      expect(Rational.parse('-0.125').toFixed(2), '-0.13');
      expect(r(5, 2).toFixed(0), '3');
      expect(r(-5, 2).toFixed(0), '-3');
      expect(r(-1, 1000).toFixed(2), '0.00');
      expect(Rational.parse('0.12499999').toFixed(2), '0.12');
    });
    test('toTrimmed has no trailing zeros', () {
      expect(r(5, 2).toTrimmed(), '2.5');
      expect(r(100).toTrimmed(), '100');
      expect(r(1, 8).toTrimmed(), '0.125');
      expect(r(-1, 1000000000000).toTrimmed(), '0');
    });
    test('floor and ceil are correct for negatives (Dart ~/ truncates toward zero)', () {
      expect(r(7, 2).floor(), BigInt.from(3));
      expect(r(7, 2).ceil(), BigInt.from(4));
      expect(r(-7, 2).floor(), BigInt.from(-4));
      expect(r(-7, 2).ceil(), BigInt.from(-3));
      expect(r(-4, 2).floor(), BigInt.from(-2));
      expect(r(-4, 2).ceil(), BigInt.from(-2));
      expect(r(0).floor(), BigInt.zero);
    });
    test('integerSqrt', () {
      expect(<int>[0, 1, 2, 3, 4, 15, 16, 17].map((n) => integerSqrt(BigInt.from(n)).toInt()).toList(), <int>[0, 1, 1, 1, 2, 3, 4, 4]);
      expect(integerSqrt(BigInt.from(10).pow(40)), BigInt.from(10).pow(20));
      expect(integerSqrt(BigInt.two * BigInt.from(10).pow(40)), BigInt.parse('141421356237309504880'));
      final n = BigInt.from(10).pow(18) + BigInt.from(7);
      expect(integerSqrt(n * n - BigInt.one), n - BigInt.one);
      expect(integerSqrt(n * n), n);
    });
    test('sqrtFixed rounds half up', () {
      expect(r(2).sqrtFixed(10), '1.4142135624');
      expect(r(1, 4).sqrtFixed(0), '1');
      expect(r(24).sqrtFixed(2), '4.90');
    });
    test('powers: negative exponents, 0^0 and 0^-1', () {
      expect(r(2).pow(-1), r(1, 2));
      expect(r(-2).pow(3), r(-8));
      expect(r(0).pow(0), Rational.one);
      expect(() => r(0).pow(-1), throwsA(isA<CalcException>()));
    });
    test('isExact', () {
      expect(r(1, 8).isExact(), isTrue);
      expect(r(1, 3).isExact(), isFalse);
      expect(Rational.parse('0.0000000001').isExact(), isTrue);
      expect(Rational.parse('0.00000000001').isExact(), isFalse);
    });
    test('comparison and equality use lowest terms', () {
      expect(r(2, 4), r(1, 2));
      expect(r(1, 3) < r(1, 2), isTrue);
      expect(<Rational, int>{r(2, 4): 1}[r(1, 2)], 1);
    });
  });

  test('the vector file covers every calculator the app exposes', () {
    expect(cases.map((c) => c['fn']).toSet().length, 18);
  });
}
