import 'package:flutter/material.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';

/// Full-featured G.C.E. A/L Scientific Calculator with offline Dart evaluation,
/// equation solvers, complex/vector/matrix tools, chemistry, and 2D function plotting.
class ScientificCalcScreen extends StatefulWidget {
  const ScientificCalcScreen({super.key});

  @override
  State<ScientificCalcScreen> createState() => _ScientificCalcScreenState();
}

class _ScientificCalcScreenState extends State<ScientificCalcScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _exprController = TextEditingController();
  AngleUnit _angleUnit = AngleUnit.degrees;

  String _result = '';
  String? _errorMessage;
  final List<String> _history = <String>[];

  // Equation solver controllers
  final TextEditingController _eqA = TextEditingController(text: '1');
  final TextEditingController _eqB = TextEditingController(text: '-5');
  final TextEditingController _eqC = TextEditingController(text: '6');
  final TextEditingController _eqD = TextEditingController(text: '0');
  List<String> _solverSteps = <String>[];

  // Chemistry controllers
  final TextEditingController _chemFormula = TextEditingController(text: 'H2SO4');
  MolarMassResult? _chemResult;

  // Graph plotter controllers
  final TextEditingController _graphExpr = TextEditingController(text: 'sin(x)');
  final double _xMin = -10.0;
  final double _xMax = 10.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _exprController.dispose();
    _eqA.dispose();
    _eqB.dispose();
    _eqC.dispose();
    _eqD.dispose();
    _chemFormula.dispose();
    _graphExpr.dispose();
    super.dispose();
  }

  void _insert(String text) {
    final cur = _exprController.text;
    final sel = _exprController.selection;
    if (sel.isValid && sel.start >= 0) {
      final newText = cur.replaceRange(sel.start, sel.end, text);
      _exprController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + text.length),
      );
    } else {
      _exprController.text = cur + text;
      _exprController.selection = TextSelection.collapsed(offset: _exprController.text.length);
    }
  }

  void _delete() {
    final cur = _exprController.text;
    if (cur.isEmpty) return;
    final sel = _exprController.selection;
    if (sel.isValid && sel.start > 0) {
      final newText = cur.replaceRange(sel.start - 1, sel.end, '');
      _exprController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start - 1),
      );
    } else {
      _exprController.text = cur.substring(0, cur.length - 1);
      _exprController.selection = TextSelection.collapsed(offset: _exprController.text.length);
    }
  }

  void _calculate() {
    final expr = _exprController.text.trim();
    if (expr.isEmpty) return;

    final evaluator = ScientificEvaluator(angleUnit: _angleUnit);
    try {
      final val = evaluator.evaluate(expr);
      setState(() {
        _errorMessage = null;
        if (val == val.roundToDouble() && val.abs() < 1e12) {
          _result = val.round().toString();
        } else {
          _result = val.toStringAsPrecision(8).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
        }
        _history.insert(0, '$expr = $_result');
      });
    } on CalcException catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.code.replaceAll('_', ' ')}';
        _result = '';
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Syntax Error';
        _result = '';
      });
    }
  }

  void _solveQuadratic() {
    final a = double.tryParse(_eqA.text) ?? 1.0;
    final b = double.tryParse(_eqB.text) ?? 0.0;
    final c = double.tryParse(_eqC.text) ?? 0.0;

    try {
      final res = EquationSolver.solveQuadratic(a, b, c);
      setState(() {
        _solverSteps = res.steps;
      });
    } catch (e) {
      setState(() {
        _solverSteps = <String>['Invalid equation coefficients'];
      });
    }
  }

  void _solveCubic() {
    final a = double.tryParse(_eqA.text) ?? 1.0;
    final b = double.tryParse(_eqB.text) ?? 0.0;
    final c = double.tryParse(_eqC.text) ?? 0.0;
    final d = double.tryParse(_eqD.text) ?? 0.0;

    try {
      final res = EquationSolver.solveCubic(a, b, c, d);
      setState(() {
        _solverSteps = res.steps;
      });
    } catch (e) {
      setState(() {
        _solverSteps = <String>['Invalid cubic coefficients'];
      });
    }
  }

  void _calculateChemistry() {
    final f = _chemFormula.text.trim();
    if (f.isEmpty) return;
    try {
      final res = ChemistryCalc.calculateMolarMass(f);
      setState(() {
        _chemResult = res;
      });
    } catch (_) {
      setState(() {
        _chemResult = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calcScientific),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const <Widget>[
            Tab(text: 'Expression & Trig', icon: Icon(Icons.calculate_outlined)),
            Tab(text: 'Equation Solver', icon: Icon(Icons.functions_outlined)),
            Tab(text: 'Chemistry Mass', icon: Icon(Icons.science_outlined)),
            Tab(text: '2D Graph', icon: Icon(Icons.show_chart_outlined)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: <Widget>[
            _buildExpressionTab(theme, colors),
            _buildEquationTab(theme, colors),
            _buildChemistryTab(theme, colors),
            _buildGraphTab(theme, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildExpressionTab(ThemeData theme, AppColors colors) {
    return Column(
      children: <Widget>[
        // Angle unit toggle & Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
          color: colors.surfaceVariant.withValues(alpha: 0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              SegmentedButton<AngleUnit>(
                segments: const <ButtonSegment<AngleUnit>>[
                  ButtonSegment<AngleUnit>(value: AngleUnit.degrees, label: Text('DEG')),
                  ButtonSegment<AngleUnit>(value: AngleUnit.radians, label: Text('RAD')),
                  ButtonSegment<AngleUnit>(value: AngleUnit.gradians, label: Text('GRAD')),
                ],
                selected: <AngleUnit>{_angleUnit},
                onSelectionChanged: (set) => setState(() => _angleUnit = set.first),
              ),
              IconButton(
                icon: const Icon(Icons.history_outlined),
                tooltip: 'History',
                onPressed: _showHistoryDialog,
              ),
            ],
          ),
        ),

        // Formula / Result Display Card
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _exprController,
                  style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter expression, e.g. sin(30) + sqrt(16)',
                  ),
                ),
                const Divider(),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.titleMedium?.copyWith(color: colors.error),
                  )
                else
                  Text(
                    _result.isEmpty ? '0' : _result,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Scientific Keypad
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: GridView.count(
              crossAxisCount: 5,
              childAspectRatio: 1.5,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                _btn('sin', () => _insert('sin('), isFunc: true),
                _btn('cos', () => _insert('cos('), isFunc: true),
                _btn('tan', () => _insert('tan('), isFunc: true),
                _btn('ln', () => _insert('ln('), isFunc: true),
                _btn('log', () => _insert('log('), isFunc: true),

                _btn('asin', () => _insert('asin('), isFunc: true),
                _btn('acos', () => _insert('acos('), isFunc: true),
                _btn('atan', () => _insert('atan('), isFunc: true),
                _btn('e^x', () => _insert('e^'), isFunc: true),
                _btn('x^y', () => _insert('^'), isFunc: true),

                _btn('(', () => _insert('(')),
                _btn(')', () => _insert(')')),
                _btn('√', () => _insert('sqrt(')),
                _btn('n!', () => _insert('!')),
                _btn('DEL', _delete, isAction: true),

                _btn('7', () => _insert('7')),
                _btn('8', () => _insert('8')),
                _btn('9', () => _insert('9')),
                _btn('÷', () => _insert('/'), isOp: true),
                _btn('AC', () {
                  setState(() {
                    _exprController.clear();
                    _result = '';
                    _errorMessage = null;
                  });
                }, isAction: true),

                _btn('4', () => _insert('4')),
                _btn('5', () => _insert('5')),
                _btn('6', () => _insert('6')),
                _btn('×', () => _insert('*'), isOp: true),
                _btn('π', () => _insert('pi'), isFunc: true),

                _btn('1', () => _insert('1')),
                _btn('2', () => _insert('2')),
                _btn('3', () => _insert('3')),
                _btn('−', () => _insert('-'), isOp: true),
                _btn('e', () => _insert('e'), isFunc: true),

                _btn('0', () => _insert('0')),
                _btn('.', () => _insert('.')),
                _btn('%', () => _insert('%'), isOp: true),
                _btn('+', () => _insert('+'), isOp: true),
                _btn('=', _calculate, isPrimary: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _btn(String label, VoidCallback onTap, {bool isOp = false, bool isFunc = false, bool isAction = false, bool isPrimary = false}) {
    final colors = context.colors;
    Color bg = colors.surfaceVariant;
    Color fg = colors.text;

    if (isPrimary) {
      bg = colors.primary;
      fg = colors.onPrimary;
    } else if (isAction) {
      bg = colors.error.withValues(alpha: 0.15);
      fg = colors.error;
    } else if (isOp) {
      bg = colors.primary.withValues(alpha: 0.15);
      fg = colors.primary;
    } else if (isFunc) {
      bg = colors.surface;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isPrimary || isOp ? FontWeight.bold : FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Calculation History'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: _history.isEmpty
                ? const Center(child: Text('No previous calculations.'))
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(_history[i]),
                      onTap: () {
                        final expr = _history[i].split('=').first.trim();
                        _exprController.text = expr;
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _buildEquationTab(ThemeData theme, AppColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Polynomial Equation Solver', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Row(
            children: <Widget>[
              Expanded(child: AppTextField(controller: _eqA, label: 'a (x² or x³)')),
              const SizedBox(width: Spacing.sm),
              Expanded(child: AppTextField(controller: _eqB, label: 'b (x or x²)')),
              const SizedBox(width: Spacing.sm),
              Expanded(child: AppTextField(controller: _eqC, label: 'c (const or x)')),
              const SizedBox(width: Spacing.sm),
              Expanded(child: AppTextField(controller: _eqD, label: 'd (cubic const)')),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _solveQuadratic,
                  child: const Text('Solve Quadratic (ax²+bx+c=0)'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _solveCubic,
                  child: const Text('Solve Cubic (ax³+bx²+cx+d=0)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          if (_solverSteps.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Analytical Solution', style: theme.textTheme.titleMedium?.copyWith(color: colors.primary)),
                  const Divider(),
                  for (final step in _solverSteps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(step, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChemistryTab(ThemeData theme, AppColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Chemical Formula & Molar Mass', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          AppTextField(
            controller: _chemFormula,
            label: 'Formula (e.g. H2SO4, Ca(OH)2, CuSO4.5H2O)',
          ),
          const SizedBox(height: Spacing.md),
          FilledButton(
            onPressed: _calculateChemistry,
            child: const Text('Calculate Molar Mass & Stoichiometry'),
          ),
          const SizedBox(height: Spacing.lg),
          if (_chemResult != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Molar Mass: ${_chemResult!.molarMass.toStringAsFixed(3)} g/mol',
                    style: theme.textTheme.titleLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Text('Elemental Composition:', style: theme.textTheme.titleSmall),
                  const SizedBox(height: Spacing.xs),
                  for (final el in _chemResult!.elements)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text('${el.symbol} (×${el.count})', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${el.percentage.toStringAsFixed(2)}% (${el.totalWeight.toStringAsFixed(3)} g/mol)'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGraphTab(ThemeData theme, AppColors colors) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _graphExpr,
                  label: 'f(x) Function (e.g. sin(x), x^2 - 4)',
                ),
              ),
              const SizedBox(width: Spacing.sm),
              FilledButton(
                onPressed: () => setState(() {}),
                child: const Text('Plot'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.lg),
              child: Container(
                color: colors.surfaceVariant.withValues(alpha: 0.2),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _FunctionGraphPainter(
                    expression: _graphExpr.text,
                    xMin: _xMin,
                    xMax: _xMax,
                    colors: colors,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FunctionGraphPainter extends CustomPainter {
  _FunctionGraphPainter({
    required this.expression,
    required this.xMin,
    required this.xMax,
    required this.colors,
  });

  final String expression;
  final double xMin;
  final double xMax;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = colors.textMuted.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;

    final gridPaint = Paint()
      ..color = colors.textMuted.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    final curvePaint = Paint()
      ..color = colors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final midX = size.width / 2.0;
    final midY = size.height / 2.0;

    // Draw grid
    final gridSpacing = size.width / 10.0;
    for (var x = 0.0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw Axes
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), axisPaint);
    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), axisPaint);

    final evaluator = ScientificEvaluator(angleUnit: AngleUnit.radians);
    final path = Path();
    var firstPoint = true;

    const steps = 300;
    final dx = (xMax - xMin) / steps;
    final scaleX = size.width / (xMax - xMin);
    final scaleY = size.height / (xMax - xMin);

    for (var i = 0; i <= steps; i++) {
      final xVal = xMin + i * dx;
      try {
        final yVal = evaluator.evaluate(expression, variables: {'x': xVal});
        if (yVal.isNaN || yVal.isInfinite || yVal.abs() > 1e4) {
          firstPoint = true;
          continue;
        }

        final screenX = (xVal - xMin) * scaleX;
        final screenY = midY - yVal * scaleY;

        if (screenY < -100 || screenY > size.height + 100) {
          firstPoint = true;
          continue;
        }

        if (firstPoint) {
          path.moveTo(screenX, screenY);
          firstPoint = false;
        } else {
          path.lineTo(screenX, screenY);
        }
      } catch (_) {
        firstPoint = true;
      }
    }

    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(covariant _FunctionGraphPainter oldDelegate) {
    return oldDelegate.expression != expression || oldDelegate.xMin != xMin || oldDelegate.xMax != xMax;
  }
}
