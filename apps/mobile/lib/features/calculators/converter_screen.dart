import 'package:flutter/material.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';

/// Accurate physical and metric/imperial unit converter.
class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  static const Map<String, List<String>> _categories = <String, List<String>>{
    'Length': <String>['m', 'km', 'cm', 'mm', 'in', 'ft', 'yd', 'mi'],
    'Mass': <String>['kg', 'g', 'mg', 't', 'lb', 'oz'],
    'Volume': <String>['l', 'ml', 'm3', 'gal', 'qt', 'pt', 'cup', 'floz'],
    'Area': <String>['m2', 'km2', 'ha', 'acre', 'ft2', 'cm2'],
    'Time': <String>['s', 'min', 'h', 'day', 'week'],
    'Speed': <String>['ms', 'kmh', 'mph', 'kn'],
    'Temperature': <String>['c', 'f', 'k'],
  };

  String _category = 'Length';
  late String _fromUnit;
  late String _toUnit;
  final TextEditingController _valController = TextEditingController(text: '1');
  CalcResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fromUnit = _categories[_category]![0];
    _toUnit = _categories[_category]![1];
    _convert();
  }

  @override
  void dispose() {
    _valController.dispose();
    super.dispose();
  }

  void _convert() {
    final v = _valController.text.trim();
    if (v.isEmpty) {
      return;
    }
    setState(() {
      try {
        _result = convertUnits(v, _fromUnit, _toUnit);
        _error = null;
      } on CalcException catch (e) {
        _error = e.code;
        _result = null;
      } on Object {
        _error = 'invalid_format';
        _result = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;

    final units = _categories[_category]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calcConverter),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'), // l10n-ok
                  items: _categories.keys.map((cat) {
                    return DropdownMenuItem<String>(value: cat, child: Text(cat)); // l10n-ok
                  }).toList(),
                  onChanged: (cat) {
                    if (cat != null) {
                      setState(() {
                        _category = cat;
                        _fromUnit = _categories[cat]![0];
                        _toUnit = _categories[cat]![1];
                      });
                      _convert();
                    }
                  },
                ),
                const SizedBox(height: Spacing.md),
                AppTextField(
                  controller: _valController,
                  label: l10n.calcInputBase,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  onChanged: (_) => _convert(),
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _fromUnit,
                        decoration: const InputDecoration(labelText: 'From'), // l10n-ok
                        items: units.map((u) => DropdownMenuItem<String>(value: u, child: Text(u))).toList(), // l10n-ok
                        onChanged: (u) {
                          if (u != null) {
                            setState(() => _fromUnit = u);
                            _convert();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () {
                        setState(() {
                          final tmp = _fromUnit;
                          _fromUnit = _toUnit;
                          _toUnit = tmp;
                        });
                        _convert();
                      },
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _toUnit,
                        decoration: const InputDecoration(labelText: 'To'), // l10n-ok
                        items: units.map((u) => DropdownMenuItem<String>(value: u, child: Text(u))).toList(), // l10n-ok
                        onChanged: (u) {
                          if (u != null) {
                            setState(() => _toUnit = u);
                            _convert();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: Spacing.sm),
                  Text(l10n.errorInvalidFormat, style: theme.textTheme.bodySmall?.copyWith(color: colors.error)),
                ],
                const SizedBox(height: Spacing.lg),
                if (_result != null) ...<Widget>[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l10n.calcResult, style: theme.textTheme.titleMedium),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          '${_result!.values['result']} $_toUnit', // l10n-ok
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: Spacing.md),
                        Text(l10n.calcSteps, style: theme.textTheme.labelMedium),
                        const SizedBox(height: Spacing.xs),
                        ..._result!.steps.map((step) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(step, style: theme.textTheme.bodySmall), // l10n-ok
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

