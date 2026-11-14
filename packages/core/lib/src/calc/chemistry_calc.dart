import 'rational.dart';
import 'scientific_eval.dart';

class ElementContribution {
  const ElementContribution({
    required this.symbol,
    required this.count,
    required this.atomicWeight,
    required this.totalWeight,
    required this.percentage,
  });

  final String symbol;
  final int count;
  final double atomicWeight;
  final double totalWeight;
  final double percentage;
}

class MolarMassResult {
  const MolarMassResult({
    required this.formula,
    required this.molarMass,
    required this.elements,
  });

  final String formula;
  final double molarMass;
  final List<ElementContribution> elements;
}

/// Chemistry calculator for G.C.E. A/L Chemistry (Molar mass, Stoichiometry, Gases, Solutions).
class ChemistryCalc {
  static const Map<String, double> atomicWeights = <String, double>{
    'H': 1.008, 'He': 4.0026, 'Li': 6.94, 'Be': 9.0122, 'B': 10.81,
    'C': 12.011, 'N': 14.007, 'O': 15.999, 'F': 18.998, 'Ne': 20.180,
    'Na': 22.990, 'Mg': 24.305, 'Al': 26.982, 'Si': 28.085, 'P': 30.974,
    'S': 32.06, 'Cl': 35.45, 'Ar': 39.948, 'K': 39.098, 'Ca': 40.078,
    'Sc': 44.956, 'Ti': 47.867, 'V': 50.942, 'Cr': 51.996, 'Mn': 54.938,
    'Fe': 55.845, 'Co': 58.933, 'Ni': 58.693, 'Cu': 63.546, 'Zn': 65.38,
    'Ga': 69.723, 'Ge': 72.630, 'As': 74.922, 'Se': 78.971, 'Br': 79.904,
    'Kr': 83.798, 'Rb': 85.468, 'Sr': 87.62, 'Y': 88.906, 'Zr': 91.224,
    'Nb': 92.906, 'Mo': 95.95, 'Tc': 98.0, 'Ru': 101.07, 'Rh': 102.91,
    'Pd': 106.42, 'Ag': 107.87, 'Cd': 112.41, 'In': 114.82, 'Sn': 118.71,
    'Sb': 121.76, 'Te': 127.60, 'I': 126.90, 'Xe': 131.29, 'Cs': 132.91,
    'Ba': 137.33, 'La': 138.91, 'Ce': 140.12, 'Pr': 140.91, 'Nd': 144.24,
    'Sm': 150.36, 'Eu': 151.96, 'Gd': 157.25, 'Tb': 158.93, 'Dy': 162.50,
    'Ho': 164.93, 'Er': 167.26, 'Tm': 168.93, 'Yb': 173.05, 'Lu': 174.97,
    'Hf': 178.49, 'Ta': 180.95, 'W': 183.84, 'Re': 186.21, 'Os': 190.23,
    'Ir': 192.22, 'Pt': 195.08, 'Au': 196.97, 'Hg': 200.59, 'Tl': 204.38,
    'Pb': 207.2, 'Bi': 208.98, 'Th': 232.04, 'U': 238.03,
  };

  /// Parses a chemical formula and returns molar mass in g/mol with element breakdown.
  static MolarMassResult calculateMolarMass(String formula) {
    final clean = formula.replaceAll(' ', '');
    if (clean.isEmpty) throw const CalcException('syntax_error');

    // Handle hydrates (e.g. CuSO4.5H2O or CuSO4*5H2O)
    final parts = clean.split(RegExp(r'[.*·]'));
    final totalCounts = <String, int>{};

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;

      int multiplier = 1;
      var subFormula = part;

      if (i > 0) {
        // Hydrate coefficient: e.g. 5H2O
        final m = RegExp(r'^(\d+)').firstMatch(part);
        if (m != null) {
          multiplier = int.parse(m.group(1)!);
          subFormula = part.substring(m.end);
        }
      }

      final counts = _parseSubFormula(subFormula);
      for (final entry in counts.entries) {
        totalCounts[entry.key] = (totalCounts[entry.key] ?? 0) + entry.value * multiplier;
      }
    }

    if (totalCounts.isEmpty) throw const CalcException('syntax_error');

    var totalMass = 0.0;
    final elementList = <ElementContribution>[];

    for (final entry in totalCounts.entries) {
      final sym = entry.key;
      final count = entry.value;
      final weight = atomicWeights[sym];
      if (weight == null) {
        throw const CalcException('unknown_element');
      }
      final weightTotal = weight * count;
      totalMass += weightTotal;
    }

    for (final entry in totalCounts.entries) {
      final sym = entry.key;
      final count = entry.value;
      final weight = atomicWeights[sym]!;
      final weightTotal = weight * count;
      elementList.add(ElementContribution(
        symbol: sym,
        count: count,
        atomicWeight: weight,
        totalWeight: weightTotal,
        percentage: (weightTotal / totalMass) * 100.0,
      ));
    }

    return MolarMassResult(
      formula: formula,
      molarMass: totalMass,
      elements: elementList,
    );
  }

  static Map<String, int> _parseSubFormula(String str) {
    final counts = <String, int>{};
    final stack = <Map<String, int>>[counts];
    var i = 0;

    while (i < str.length) {
      final c = str[i];

      if (c == '(' || c == '[') {
        final newMap = <String, int>{};
        stack.add(newMap);
        i++;
      } else if (c == ')' || c == ']') {
        if (stack.length <= 1) throw const CalcException('syntax_error');
        final currentGroup = stack.removeLast();
        i++;

        // Read multiplier after bracket
        final numStart = i;
        while (i < str.length && _isDigit(str[i])) {
          i++;
        }
        final mult = numStart == i ? 1 : int.parse(str.substring(numStart, i));

        final target = stack.last;
        for (final entry in currentGroup.entries) {
          target[entry.key] = (target[entry.key] ?? 0) + entry.value * mult;
        }
      } else if (_isUpper(c)) {
        // Element symbol: 1 uppercase optionally followed by 1 lowercase
        final symStart = i;
        i++;
        if (i < str.length && _isLower(str[i])) {
          i++;
        }
        final sym = str.substring(symStart, i);

        // Read subscript count
        final numStart = i;
        while (i < str.length && _isDigit(str[i])) {
          i++;
        }
        final count = numStart == i ? 1 : int.parse(str.substring(numStart, i));

        final target = stack.last;
        target[sym] = (target[sym] ?? 0) + count;
      } else {
        throw const CalcException('syntax_error');
      }
    }

    if (stack.length != 1) throw const CalcException('unbalanced_parens');
    return counts;
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  static bool _isUpper(String c) => c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90;
  static bool _isLower(String c) => c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122;

  /// Stoichiometry conversions:
  /// Mass (g) to moles (mol): n = m / M
  static double massToMoles(double massGrams, double molarMassGPerMol) {
    if (molarMassGPerMol <= 0) throw const CalcException('division_by_zero');
    return massGrams / molarMassGPerMol;
  }

  /// Moles to mass (g): m = n * M
  static double molesToMass(double moles, double molarMassGPerMol) {
    return moles * molarMassGPerMol;
  }

  /// Concentration (mol/dm^3 or M): c = n / V (Volume in dm^3 or L)
  static double concentration(double moles, double volumeLiters) {
    if (volumeLiters <= 0) throw const CalcException('division_by_zero');
    return moles / volumeLiters;
  }

  /// Ideal Gas volume V = nRT / P (P in Pa, T in Kelvin, R = 8.314 J/(mol K))
  static double idealGasVolume({
    required double moles,
    required double tempKelvin,
    required double pressurePascals,
  }) {
    if (pressurePascals <= 0) throw const CalcException('division_by_zero');
    return (moles * ScientificConstants.R * tempKelvin) / pressurePascals;
  }
}
