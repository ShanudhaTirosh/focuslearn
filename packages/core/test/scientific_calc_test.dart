import 'dart:math' as math;
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:test/test.dart';

void main() {
  group('ScientificEvaluator - Arithmetic & Precedence', () {
    final eval = ScientificEvaluator(angleUnit: AngleUnit.degrees);

    test('basic arithmetic and precedence', () {
      expect(eval.evaluate('2 + 3 * 4'), equals(14.0));
      expect(eval.evaluate('(2 + 3) * 4'), equals(20.0));
      expect(eval.evaluate('10 - 2^3'), equals(2.0));
      expect(eval.evaluate('2^3^2'), equals(512.0)); // 2^(3^2) = 2^9
      expect(eval.evaluate('100 / 4 / 5'), closeTo(5.0, 1e-9));
    });

    test('implicit multiplication', () {
      expect(eval.evaluate('2(3 + 4)'), equals(14.0));
      expect(eval.evaluate('(2)(3)'), equals(6.0));
      expect(eval.evaluate('2pi'), closeTo(2.0 * math.pi, 1e-9));
    });

    test('constants', () {
      expect(eval.evaluate('pi'), closeTo(math.pi, 1e-9));
      expect(eval.evaluate('e'), closeTo(math.e, 1e-9));
      expect(eval.evaluate('c'), equals(299792458.0));
    });

    test('factorial postfix and function', () {
      expect(eval.evaluate('5!'), equals(120.0));
      expect(eval.evaluate('0!'), equals(1.0));
      expect(eval.evaluate('fact(6)'), equals(720.0));
      expect(eval.evaluate('3! + 4!'), equals(30.0));
    });

    test('permutations and combinations', () {
      expect(eval.evaluate('nPr(5, 2)'), equals(20.0));
      expect(eval.evaluate('nCr(5, 2)'), equals(10.0));
      expect(eval.evaluate('nCr(10, 3)'), equals(120.0));
    });

    test('division by zero throws CalcException', () {
      expect(() => eval.evaluate('5 / 0'), throwsA(isA<CalcException>()));
    });
  });

  group('ScientificEvaluator - Trigonometry & Angles', () {
    test('degrees mode', () {
      final deg = ScientificEvaluator(angleUnit: AngleUnit.degrees);
      expect(deg.evaluate('sin(30)'), closeTo(0.5, 1e-9));
      expect(deg.evaluate('cos(60)'), closeTo(0.5, 1e-9));
      expect(deg.evaluate('tan(45)'), closeTo(1.0, 1e-9));
      expect(deg.evaluate('asin(0.5)'), closeTo(30.0, 1e-9));
      expect(deg.evaluate('acos(0.5)'), closeTo(60.0, 1e-9));
      expect(deg.evaluate('atan(1)'), closeTo(45.0, 1e-9));
    });

    test('radians mode', () {
      final rad = ScientificEvaluator(angleUnit: AngleUnit.radians);
      expect(rad.evaluate('sin(pi / 6)'), closeTo(0.5, 1e-9));
      expect(rad.evaluate('cos(pi / 3)'), closeTo(0.5, 1e-9));
      expect(rad.evaluate('tan(pi / 4)'), closeTo(1.0, 1e-9));
    });

    test('hyperbolic functions', () {
      final eval = ScientificEvaluator();
      expect(eval.evaluate('sinh(0)'), equals(0.0));
      expect(eval.evaluate('cosh(0)'), equals(1.0));
      expect(eval.evaluate('tanh(0)'), equals(0.0));
      expect(eval.evaluate('asinh(0)'), equals(0.0));
    });

    test('logarithms and roots', () {
      final eval = ScientificEvaluator();
      expect(eval.evaluate('ln(e)'), closeTo(1.0, 1e-9));
      expect(eval.evaluate('log(1000)'), closeTo(3.0, 1e-9));
      expect(eval.evaluate('log2(16)'), closeTo(4.0, 1e-9));
      expect(eval.evaluate('logb(81, 3)'), closeTo(4.0, 1e-9));
      expect(eval.evaluate('sqrt(144)'), equals(12.0));
      expect(eval.evaluate('cbrt(27)'), closeTo(3.0, 1e-9));
      expect(eval.evaluate('cbrt(-27)'), closeTo(-3.0, 1e-9));
      expect(eval.evaluate('root(32, 5)'), closeTo(2.0, 1e-9));
    });
  });

  group('Complex Numbers', () {
    test('addition, subtraction, multiplication, division', () {
      const z1 = Complex(3.0, 4.0);
      const z2 = Complex(1.0, -2.0);

      final sum = z1 + z2;
      expect(sum.real, equals(4.0));
      expect(sum.imag, equals(2.0));

      final diff = z1 - z2;
      expect(diff.real, equals(2.0));
      expect(diff.imag, equals(6.0));

      final prod = z1 * z2; // (3*1 - 4*(-2)) + (3*(-2) + 4*1)i = 11 - 2i
      expect(prod.real, equals(11.0));
      expect(prod.imag, equals(-2.0));

      final div = z1 / z2;
      // (3+4i)/(1-2i) = (3+4i)(1+2i)/5 = (-5 + 10i)/5 = -1 + 2i
      expect(div.real, closeTo(-1.0, 1e-9));
      expect(div.imag, closeTo(2.0, 1e-9));
    });

    test('modulus and argument', () {
      const z = Complex(3.0, 4.0);
      expect(z.modulus, equals(5.0));
      expect(z.argumentDegrees, closeTo(53.13, 0.01));
      expect(z.conjugate.imag, equals(-4.0));
    });

    test('powers via De Moivre', () {
      const i = Complex.i;
      expect(i.pow(2).real, closeTo(-1.0, 1e-9));
      expect(i.pow(2).imag, closeTo(0.0, 1e-9));
      expect(i.pow(4).real, closeTo(1.0, 1e-9));
    });
  });

  group('EquationSolver', () {
    test('linear equation ax + b = 0', () {
      expect(EquationSolver.solveLinear(2, -8), equals(4.0));
      expect(EquationSolver.solveLinear(5, 15), equals(-3.0));
      expect(() => EquationSolver.solveLinear(0, 5), throwsA(isA<CalcException>()));
    });

    test('quadratic equation with two real roots', () {
      // x^2 - 5x + 6 = 0 => x = 2, 3
      final res = EquationSolver.solveQuadratic(1, -5, 6);
      expect(res.discriminant, equals(1.0));
      expect(res.root1.real, equals(3.0));
      expect(res.root2.real, equals(2.0));
    });

    test('quadratic equation with complex roots', () {
      // x^2 + 1 = 0 => x = ±i
      final res = EquationSolver.solveQuadratic(1, 0, 1);
      expect(res.discriminant, equals(-4.0));
      expect(res.root1.real, equals(0.0));
      expect(res.root1.imag, equals(1.0));
      expect(res.root2.real, equals(0.0));
      expect(res.root2.imag, equals(-1.0));
    });

    test('cubic equation with three real roots', () {
      // (x-1)(x-2)(x-3) = x^3 - 6x^2 + 11x - 6 = 0
      final res = EquationSolver.solveCubic(1, -6, 11, -6);
      final roots = [res.root1.real, res.root2.real, res.root3.real]..sort();
      expect(roots[0], closeTo(1.0, 1e-6));
      expect(roots[1], closeTo(2.0, 1e-6));
      expect(roots[2], closeTo(3.0, 1e-6));
    });

    test('simultaneous 2x2 linear system', () {
      // 2x + 3y = 8
      // 5x - y = 3 => x = 1, y = 2
      final res = EquationSolver.solveSimultaneous2x2(2, 3, 8, 5, -1, 3);
      expect(res.x, closeTo(1.0, 1e-9));
      expect(res.y, closeTo(2.0, 1e-9));
    });

    test('simultaneous 3x3 linear system', () {
      // x + y + z = 6
      // 2y + 5z = -4
      // 2x + 5y - z = 27 => x = 5, y = 3, z = -2
      final res = EquationSolver.solveSimultaneous3x3(
        [1, 1, 1, 6],
        [0, 2, 5, -4],
        [2, 5, -1, 27],
      );
      expect(res.x, closeTo(5.0, 1e-6));
      expect(res.y, closeTo(3.0, 1e-6));
      expect(res.z, closeTo(-2.0, 1e-6));
    });
  });

  group('Matrix and Vector', () {
    test('3D vectors dot, cross, magnitude, angle', () {
      const u = Vector3D(1, 0, 0);
      const v = Vector3D(0, 1, 0);

      expect(u.magnitude, equals(1.0));
      expect(u.dot(v), equals(0.0));
      final cross = u.cross(v);
      expect(cross.z, equals(1.0));
      expect(u.angleWithDegrees(v), closeTo(90.0, 1e-9));
    });

    test('2x2 matrix determinant and inverse', () {
      final m = Matrix([
        [4, 7],
        [2, 6],
      ]);
      expect(m.determinant, equals(10.0));
      final inv = m.inverse;
      final identity = m * inv;
      expect(identity.rows[0][0], closeTo(1.0, 1e-9));
      expect(identity.rows[0][1], closeTo(0.0, 1e-9));
      expect(identity.rows[1][0], closeTo(0.0, 1e-9));
      expect(identity.rows[1][1], closeTo(1.0, 1e-9));
    });

    test('3x3 matrix determinant', () {
      final m = Matrix([
        [1, 2, 3],
        [0, 1, 4],
        [5, 6, 0],
      ]);
      expect(m.determinant, equals(1.0));
    });
  });

  group('Programmer Calculator', () {
    test('base conversions and bitwise operations', () {
      final decVal = ProgrammerCalc.parse('255', NumberBase.dec);
      expect(ProgrammerCalc.format(decVal, NumberBase.hex), equals('FF'));
      expect(ProgrammerCalc.format(decVal, NumberBase.bin), equals('11111111'));
      expect(ProgrammerCalc.format(decVal, NumberBase.oct), equals('377'));

      final a = ProgrammerCalc.parse('1100', NumberBase.bin);
      final b = ProgrammerCalc.parse('1010', NumberBase.bin);
      expect(ProgrammerCalc.format(ProgrammerCalc.and(a, b), NumberBase.bin), equals('1000'));
      expect(ProgrammerCalc.format(ProgrammerCalc.or(a, b), NumberBase.bin), equals('1110'));
      expect(ProgrammerCalc.format(ProgrammerCalc.xor(a, b), NumberBase.bin), equals('110'));
    });
  });

  group('Sequences and Series', () {
    test('Arithmetic Progression (AP)', () {
      // a = 2, d = 3, n = 10 => T10 = 2 + 9*3 = 29, S10 = 5 * (4 + 27) = 155
      final ap = SequencesCalculator.calculateAP(a: 2, d: 3, n: 10);
      expect(ap.nthTerm, equals(29.0));
      expect(ap.sumToN, equals(155.0));
    });

    test('Geometric Progression (GP)', () {
      // a = 3, r = 2, n = 4 => T4 = 3*8 = 24, S4 = 3*(15) = 45
      final gp = SequencesCalculator.calculateGP(a: 3, r: 2, n: 4);
      expect(gp.nthTerm, equals(24.0));
      expect(gp.sumToN, equals(45.0));
      expect(gp.sumToInfinity, isNull);

      // Convergent GP: a = 1, r = 0.5 => S_inf = 1 / (1 - 0.5) = 2.0
      final infGP = SequencesCalculator.calculateGP(a: 1, r: 0.5, n: 10);
      expect(infGP.sumToInfinity, equals(2.0));
    });
  });

  group('Numerical Calculus', () {
    test('derivative of x^2 at x = 3 is 6', () {
      final d = NumericalCalculus.derivative((x) => x * x, 3.0);
      expect(d, closeTo(6.0, 1e-4));
    });

    test('definite integral of x^2 from 0 to 3 is 9', () {
      final area = NumericalCalculus.definiteIntegral((x) => x * x, 0.0, 3.0);
      expect(area, closeTo(9.0, 1e-4));
    });

    test('definite integral of sin(x) from 0 to pi is 2', () {
      final area = NumericalCalculus.definiteIntegral((x) => math.sin(x), 0.0, math.pi);
      expect(area, closeTo(2.0, 1e-4));
    });
  });

  group('Chemistry Calculator', () {
    test('molar mass of water H2O', () {
      final res = ChemistryCalc.calculateMolarMass('H2O');
      expect(res.molarMass, closeTo(18.015, 0.01));
    });

    test('molar mass of sulfuric acid H2SO4', () {
      final res = ChemistryCalc.calculateMolarMass('H2SO4');
      expect(res.molarMass, closeTo(98.076, 0.1));
    });

    test('molar mass of calcium hydroxide Ca(OH)2', () {
      final res = ChemistryCalc.calculateMolarMass('Ca(OH)2');
      expect(res.molarMass, closeTo(74.093, 0.1));
    });

    test('molar mass of copper sulfate pentahydrate CuSO4.5H2O', () {
      final res = ChemistryCalc.calculateMolarMass('CuSO4.5H2O');
      expect(res.molarMass, closeTo(249.68, 0.5));
    });

    test('stoichiometry conversions', () {
      // 18.015 g of water is 1.0 mol
      final moles = ChemistryCalc.massToMoles(18.015, 18.015);
      expect(moles, closeTo(1.0, 1e-6));
      final mass = ChemistryCalc.molesToMass(2.0, 18.015);
      expect(mass, closeTo(36.03, 1e-2));
    });
  });
}
