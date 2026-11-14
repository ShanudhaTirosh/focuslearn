import 'rational.dart';
import 'scientific_eval.dart';

typedef RealFunction = double Function(double x);

/// Numerical differentiation and integration for A/L Calculus.
class NumericalCalculus {
  /// Evaluates numerical derivative f'(x0) using central difference formula with Richardson extrapolation.
  static double derivative(RealFunction f, double x0, {double h = 1e-5}) {
    final d1 = (f(x0 + h) - f(x0 - h)) / (2.0 * h);
    final d2 = (f(x0 + h / 2.0) - f(x0 - h / 2.0)) / h;
    // Richardson extrapolation: (4*D(h/2) - D(h)) / 3
    final res = (4.0 * d2 - d1) / 3.0;
    if (res.isNaN) throw const CalcException('domain_error');
    return res;
  }

  /// Numerical derivative of an expression string at x = x0.
  static double derivativeExpression(String expr, double x0, {ScientificEvaluator? evaluator}) {
    final eval = evaluator ?? ScientificEvaluator();
    return derivative((x) => eval.evaluate(expr, variables: {'x': x}), x0);
  }

  /// Evaluates definite integral ∫_a^b f(x) dx using Composite Simpson's 1/3 Rule.
  static double definiteIntegral(RealFunction f, double a, double b, {int n = 1000}) {
    if (n % 2 != 0) n++; // Must be even
    if (a == b) return 0.0;
    final h = (b - a) / n;

    var sum = f(a) + f(b);

    for (var i = 1; i < n; i++) {
      final x = a + i * h;
      final y = f(x);
      if (y.isNaN) throw const CalcException('domain_error');
      if (y.isInfinite) throw const CalcException('division_by_zero');
      sum += (i % 2 == 0 ? 2.0 : 4.0) * y;
    }

    return (h / 3.0) * sum;
  }

  /// Numerical definite integral of an expression string from a to b.
  static double definiteIntegralExpression(String expr, double a, double b, {int n = 1000, ScientificEvaluator? evaluator}) {
    final eval = evaluator ?? ScientificEvaluator();
    return definiteIntegral((x) => eval.evaluate(expr, variables: {'x': x}), a, b, n: n);
  }
}
