import 'dart:math' as math;
import 'complex.dart';
import 'rational.dart';

class QuadraticResult {
  const QuadraticResult({
    required this.discriminant,
    required this.root1,
    required this.root2,
    required this.steps,
  });

  final double discriminant;
  final Complex root1;
  final Complex root2;
  final List<String> steps;
}

class CubicResult {
  const CubicResult({
    required this.root1,
    required this.root2,
    required this.root3,
    required this.steps,
  });

  final Complex root1;
  final Complex root2;
  final Complex root3;
  final List<String> steps;
}

class Linear2x2Result {
  const Linear2x2Result({
    required this.x,
    required this.y,
    required this.determinant,
    required this.steps,
  });

  final double x;
  final double y;
  final double determinant;
  final List<String> steps;
}

class Linear3x3Result {
  const Linear3x3Result({
    required this.x,
    required this.y,
    required this.z,
    required this.steps,
  });

  final double x;
  final double y;
  final double z;
  final List<String> steps;
}

/// Solves polynomial and simultaneous algebraic equations for G.C.E. A/L Mathematics.
class EquationSolver {
  /// Solves linear equation ax + b = 0.
  static double solveLinear(double a, double b) {
    if (a == 0.0) {
      if (b == 0.0) throw const CalcException('infinite_solutions');
      throw const CalcException('no_solution');
    }
    return -b / a;
  }

  /// Solves quadratic equation ax^2 + bx + c = 0.
  static QuadraticResult solveQuadratic(double a, double b, double c) {
    if (a == 0.0) throw const CalcException('domain_error');

    final d = b * b - 4 * a * c;
    final steps = <String>[
      'Standard Form: $a·x² + $b·x + $c = 0',
      'Discriminant Δ = b² − 4ac = ($b)² − 4($a)($c) = $d',
    ];

    if (d > 0) {
      final sqrtD = math.sqrt(d);
      final r1 = (-b + sqrtD) / (2 * a);
      final r2 = (-b - sqrtD) / (2 * a);
      steps.add('Δ > 0: Two distinct real roots');
      steps.add('x₁ = (−$b + √$d) ÷ (2·$a) = $r1');
      steps.add('x₂ = (−$b − √$d) ÷ (2·$a) = $r2');
      return QuadraticResult(
        discriminant: d,
        root1: Complex(r1),
        root2: Complex(r2),
        steps: steps,
      );
    } else if (d.abs() < 1e-12) {
      final r = -b / (2 * a);
      steps.add('Δ = 0: One repeated real root');
      steps.add('x = −$b ÷ (2·$a) = $r');
      return QuadraticResult(
        discriminant: 0.0,
        root1: Complex(r),
        root2: Complex(r),
        steps: steps,
      );
    } else {
      final sqrtD = math.sqrt(-d);
      final realPart = -b / (2 * a);
      final imagPart = (sqrtD / (2 * a)).abs();
      steps.add('Δ < 0: Two complex conjugate roots');
      steps.add('x₁ = $realPart + ${imagPart}i');
      steps.add('x₂ = $realPart − ${imagPart}i');
      return QuadraticResult(
        discriminant: d,
        root1: Complex(realPart, imagPart),
        root2: Complex(realPart, -imagPart),
        steps: steps,
      );
    }
  }

  /// Solves cubic equation ax^3 + bx^2 + cx + d = 0 using Cardano's analytical method.
  static CubicResult solveCubic(double a, double b, double c, double d) {
    if (a == 0.0) throw const CalcException('domain_error');

    // Normalize to x^3 + Ax^2 + Bx + C = 0
    final A = b / a;
    final B = c / a;
    final C = d / a;

    // Depressed cubic t^3 + pt + q = 0 with x = t - A/3
    final p = B - (A * A) / 3.0;
    final q = (2.0 * A * A * A) / 27.0 - (A * B) / 3.0 + C;
    final delta = (q * q) / 4.0 + (p * p * p) / 27.0;

    final steps = <String>[
      'Cubic Form: $a·x³ + $b·x² + $c·x + $d = 0',
      'Depressed cubic: t³ + pt + q = 0 (p = $p, q = $q)',
    ];

    final shift = -A / 3.0;

    if (delta > 1e-12) {
      // 1 real root, 2 complex conjugate roots
      final sqrtDelta = math.sqrt(delta);
      final uTerm = -q / 2.0 + sqrtDelta;
      final vTerm = -q / 2.0 - sqrtDelta;
      final u = uTerm >= 0 ? math.pow(uTerm, 1.0 / 3.0).toDouble() : -math.pow(-uTerm, 1.0 / 3.0).toDouble();
      final v = vTerm >= 0 ? math.pow(vTerm, 1.0 / 3.0).toDouble() : -math.pow(-vTerm, 1.0 / 3.0).toDouble();

      final r1Real = u + v + shift;
      final r2Real = -0.5 * (u + v) + shift;
      final rImag = (math.sqrt(3.0) / 2.0) * (u - v).abs();

      steps.add('Discriminant > 0: One real root and two complex conjugate roots');
      return CubicResult(
        root1: Complex(r1Real),
        root2: Complex(r2Real, rImag),
        root3: Complex(r2Real, -rImag),
        steps: steps,
      );
    } else if (delta < -1e-12) {
      // 3 distinct real roots (Casus irreducibilis via trigonometric method)
      final r = math.sqrt(-math.pow(p / 3.0, 3));
      final phi = math.acos((-q / (2.0 * r)).clamp(-1.0, 1.0));
      final m = 2.0 * math.pow(r, 1.0 / 3.0);

      final r1 = m * math.cos(phi / 3.0) + shift;
      final r2 = m * math.cos((phi + 2.0 * math.pi) / 3.0) + shift;
      final r3 = m * math.cos((phi + 4.0 * math.pi) / 3.0) + shift;

      steps.add('Discriminant < 0: Three distinct real roots');
      return CubicResult(
        root1: Complex(r1),
        root2: Complex(r2),
        root3: Complex(r3),
        steps: steps,
      );
    } else {
      // Multiple real roots (delta == 0)
      final u = q >= 0 ? -math.pow(q / 2.0, 1.0 / 3.0).toDouble() : math.pow(-q / 2.0, 1.0 / 3.0).toDouble();
      final r1 = 2.0 * u + shift;
      final r2 = -u + shift;

      steps.add('Discriminant = 0: Real roots with at least one repeated');
      return CubicResult(
        root1: Complex(r1),
        root2: Complex(r2),
        root3: Complex(r2),
        steps: steps,
      );
    }
  }

  /// Solves 2x2 linear system via Cramer's Rule:
  /// a1·x + b1·y = c1
  /// a2·x + b2·y = c2
  static Linear2x2Result solveSimultaneous2x2(
    double a1, double b1, double c1,
    double a2, double b2, double c2,
  ) {
    final det = a1 * b2 - a2 * b1;
    if (det.abs() < 1e-12) {
      throw const CalcException('no_unique_solution');
    }
    final detX = c1 * b2 - c2 * b1;
    final detY = a1 * c2 - a2 * c1;
    final x = detX / det;
    final y = detY / det;

    final steps = <String>[
      'System: ($a1)x + ($b1)y = $c1 and ($a2)x + ($b2)y = $c2',
      'Determinant D = ($a1)($b2) − ($a2)($b1) = $det',
      'Dx = ($c1)($b2) − ($c2)($b1) = $detX',
      'Dy = ($a1)($c2) − ($a2)($c1) = $detY',
      'x = Dx ÷ D = $x',
      'y = Dy ÷ D = $y',
    ];

    return Linear2x2Result(
      x: x,
      y: y,
      determinant: det,
      steps: steps,
    );
  }

  /// Solves 3x3 linear system via Gaussian Elimination with partial pivoting:
  /// A · [x, y, z]^T = B
  static Linear3x3Result solveSimultaneous3x3(
    List<double> row1,
    List<double> row2,
    List<double> row3,
  ) {
    // Each row has 4 elements: [a, b, c, const]
    if (row1.length != 4 || row2.length != 4 || row3.length != 4) {
      throw const CalcException('syntax_error');
    }

    final m = [
      List<double>.from(row1),
      List<double>.from(row2),
      List<double>.from(row3),
    ];

    // Forward elimination with partial pivoting
    for (var col = 0; col < 3; col++) {
      var maxRow = col;
      var maxVal = m[col][col].abs();
      for (var r = col + 1; r < 3; r++) {
        if (m[r][col].abs() > maxVal) {
          maxVal = m[r][col].abs();
          maxRow = r;
        }
      }
      if (maxVal < 1e-12) {
        throw const CalcException('no_unique_solution');
      }

      // Swap rows
      if (maxRow != col) {
        final tmp = m[col];
        m[col] = m[maxRow];
        m[maxRow] = tmp;
      }

      for (var r = col + 1; r < 3; r++) {
        final factor = m[r][col] / m[col][col];
        for (var c = col; c < 4; c++) {
          m[r][c] -= factor * m[col][c];
        }
      }
    }

    // Back substitution
    final z = m[2][3] / m[2][2];
    final y = (m[1][3] - m[1][2] * z) / m[1][1];
    final x = (m[0][3] - m[0][1] * y - m[0][2] * z) / m[0][0];

    final steps = <String>[
      '3×3 System solved via Gaussian Elimination with partial pivoting',
      'Row 3 reduced: ${m[2][2]}·z = ${m[2][3]} => z = $z',
      'Row 2 back-substitution: y = $y',
      'Row 1 back-substitution: x = $x',
    ];

    return Linear3x3Result(
      x: x,
      y: y,
      z: z,
      steps: steps,
    );
  }
}
