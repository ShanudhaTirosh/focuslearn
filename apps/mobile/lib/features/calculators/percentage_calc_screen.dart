import 'package:flutter/material.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';

enum _PercentMode { of, what, change, increase }

/// Percentage calculator covering four common school and business calculation types.
class PercentageCalcScreen extends StatefulWidget {
  const PercentageCalcScreen({super.key});

  @override
  State<PercentageCalcScreen> createState() => _PercentageCalcScreenState();
}

class _PercentageCalcScreenState extends State<PercentageCalcScreen> {
  _PercentMode _mode = _PercentMode.of;
  final TextEditingController _valA = TextEditingController();
  final TextEditingController _valB = TextEditingController();
  CalcResult? _result;
  String? _error;

  @override
  void dispose() {
    _valA.dispose();
    _valB.dispose();
    super.dispose();
  }

  void _calculate() {
    final a = _valA.text.trim();
    final b = _valB.text.trim();
    if (a.isEmpty || b.isEmpty) {
      return;
    }
    setState(() {
      try {
        switch (_mode) {
          case _PercentMode.of:
            _result = percentOf(a, b);
          case _PercentMode.what:
            _result = percentWhat(a, b);
          case _PercentMode.change:
            _result = percentChange(a, b);
          case _PercentMode.increase:
            _result = percentIncrease(a, b);
        }
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

    final String labelA;
    final String labelB;
    switch (_mode) {
      case _PercentMode.of:
        labelA = l10n.calcInputPercent;
        labelB = l10n.calcInputBase;
      case _PercentMode.what:
        labelA = l10n.calcInputPart;
        labelB = l10n.calcInputWhole;
      case _PercentMode.change:
        labelA = l10n.calcInputA;
        labelB = l10n.calcInputB;
      case _PercentMode.increase:
        labelA = l10n.calcInputBase;
        labelB = l10n.calcInputPercent;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calcPercentage),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SegmentedButton<_PercentMode>(
                  segments: const <ButtonSegment<_PercentMode>>[
                    ButtonSegment<_PercentMode>(value: _PercentMode.of, label: Text('% of')), // l10n-ok
                    ButtonSegment<_PercentMode>(value: _PercentMode.what, label: Text('What %')), // l10n-ok
                    ButtonSegment<_PercentMode>(value: _PercentMode.change, label: Text('Change')), // l10n-ok
                    ButtonSegment<_PercentMode>(value: _PercentMode.increase, label: Text('+ / - %')), // l10n-ok
                  ],
                  selected: <_PercentMode>{_mode},
                  onSelectionChanged: (set) {
                    setState(() {
                      _mode = set.first;
                      _result = null;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: Spacing.lg),
                AppTextField(
                  controller: _valA,
                  label: labelA,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
                const SizedBox(height: Spacing.md),
                AppTextField(
                  controller: _valB,
                  label: labelB,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  errorText: _error != null ? l10n.errorInvalidFormat : null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _calculate(),
                ),
                const SizedBox(height: Spacing.md),
                AppButton(
                  label: l10n.calcCalculate,
                  onPressed: _calculate,
                ),
                const SizedBox(height: Spacing.lg),
                if (_result != null) ...<Widget>[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l10n.calcResult, style: theme.textTheme.titleMedium),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          '${_result!.values.values.first}', // l10n-ok
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
                              child: Text(step, style: theme.textTheme.bodyMedium), // l10n-ok
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

