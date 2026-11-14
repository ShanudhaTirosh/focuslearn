import 'dart:math' as math;
import 'rational.dart';

class APResult {
  const APResult({
    required this.a,
    required this.d,
    required this.n,
    required this.nthTerm,
    required this.sumToN,
    required this.steps,
  });

  final double a;
  final double d;
  final int n;
  final double nthTerm;
  final double sumToN;
  final List<String> steps;
}

class GPResult {
  const GPResult({
    required this.a,
    required this.r,
    required this.n,
    required this.nthTerm,
    required this.sumToN,
    this.sumToInfinity,
    required this.steps,
  });

  final double a;
  final double r;
  final int n;
  final double nthTerm;
  final double sumToN;
  final double? sumToInfinity;
  final List<String> steps;
}

/// Sequences and series calculations for G.C.E. A/L Combined Mathematics.
class SequencesCalculator {
  static APResult calculateAP({required double a, required double d, required int n}) {
    if (n < 1) throw const CalcException('domain_error');
    final tn = a + (n - 1) * d;
    final sn = (n / 2.0) * (2 * a + (n - 1) * d);

    final steps = <String>[
      'Arithmetic Progression (AP): First term a = $a, Common difference d = $d, Terms n = $n',
      'n-th term formula: Tn = a + (n − 1)d',
      'T$n = $a + ($n − 1)($d) = $tn',
      'Sum formula: Sn = (n ÷ 2) · [2a + (n − 1)d]',
      'S$n = ($n ÷ 2) · [2($a) + ($n − 1)($d)] = $sn',
    ];

    return APResult(
      a: a,
      d: d,
      n: n,
      nthTerm: tn,
      sumToN: sn,
      steps: steps,
    );
  }

  static GPResult calculateGP({required double a, required double r, required int n}) {
    if (n < 1) throw const CalcException('domain_error');
    final tn = a * math.pow(r, n - 1);
    final double sn;
    if ((r - 1.0).abs() < 1e-12) {
      sn = n * a;
    } else {
      sn = a * (1.0 - math.pow(r, n)) / (1.0 - r);
    }

    double? sInf;
    if (r.abs() < 1.0) {
      sInf = a / (1.0 - r);
    }

    final steps = <String>[
      'Geometric Progression (GP): First term a = $a, Common ratio r = $r, Terms n = $n',
      'n-th term formula: Tn = a · r^(n − 1)',
      'T$n = $a · ($r)^($n − 1) = $tn',
      'Sum formula: Sn = a(1 − r^n) ÷ (1 − r)',
      'S$n = $sn',
    ];

    if (sInf != null) {
      steps.add('|r| < 1: Convergent infinite series sum S∞ = a ÷ (1 − r) = $sInf');
    } else {
      steps.add('|r| ≥ 1: Series does not converge to a finite sum as n → ∞');
    }

    return GPResult(
      a: a,
      r: r,
      n: n,
      nthTerm: tn,
      sumToN: sn,
      sumToInfinity: sInf,
      steps: steps,
    );
  }
}
