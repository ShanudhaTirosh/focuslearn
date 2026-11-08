import 'package:flutter/material.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';

enum _CommMode { pnl, interest, breakEven }

/// Commercial calculations: Profit & Loss, Interest, and Break-Even Analysis.
class CommercialCalcScreen extends StatefulWidget {
  const CommercialCalcScreen({super.key});

  @override
  State<CommercialCalcScreen> createState() => _CommercialCalcScreenState();
}

class _CommercialCalcScreenState extends State<CommercialCalcScreen> {
  _CommMode _mode = _CommMode.pnl;
  final TextEditingController _input1 = TextEditingController();
  final TextEditingController _input2 = TextEditingController();
  final TextEditingController _input3 = TextEditingController();
  CalcResult? _result;
  String? _error;

  @override
  void dispose() {
    _input1.dispose();
    _input2.dispose();
    _input3.dispose();
    super.dispose();
  }

  void _calculate() {
    final v1 = _input1.text.trim();
    final v2 = _input2.text.trim();
    final v3 = _input3.text.trim();

    setState(() {
      try {
        switch (_mode) {
          case _CommMode.pnl:
            if (v1.isEmpty || v2.isEmpty) return;
            _result = profitLoss(v1, v2);
          case _CommMode.interest:
            if (v1.isEmpty || v2.isEmpty || v3.isEmpty) return;
            _result = compoundInterest(v1, v2, '1', v3);
          case _CommMode.breakEven:
            if (v1.isEmpty || v2.isEmpty || v3.isEmpty) return;
            _result = breakEven(v1, v2, v3);
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

    final String label1;
    final String label2;
    final String? label3;
    switch (_mode) {
      case _CommMode.pnl:
        label1 = l10n.calcInputCost;
        label2 = l10n.calcInputSellingPrice;
        label3 = null;
      case _CommMode.interest:
        label1 = l10n.calcInputPrincipal;
        label2 = l10n.calcInputRate;
        label3 = l10n.calcInputPeriods;
      case _CommMode.breakEven:
        label1 = l10n.calcInputFixedCost;
        label2 = l10n.calcInputUnitPrice;
        label3 = l10n.calcInputVariableCost;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calcCommercial),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SegmentedButton<_CommMode>(
                  segments: const <ButtonSegment<_CommMode>>[
                    ButtonSegment<_CommMode>(value: _CommMode.pnl, label: Text('Profit/Loss')), // l10n-ok
                    ButtonSegment<_CommMode>(value: _CommMode.interest, label: Text('Interest')), // l10n-ok
                    ButtonSegment<_CommMode>(value: _CommMode.breakEven, label: Text('Break-Even')), // l10n-ok
                  ],
                  selected: <_CommMode>{_mode},
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
                  controller: _input1,
                  label: label1,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: Spacing.md),
                AppTextField(
                  controller: _input2,
                  label: label2,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                if (label3 != null) ...<Widget>[
                  const SizedBox(height: Spacing.md),
                  AppTextField(
                    controller: _input3,
                    label: label3,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
                const SizedBox(height: Spacing.md),
                AppButton(
                  label: l10n.calcCalculate,
                  onPressed: _calculate,
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
                        ..._result!.values.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(entry.key, style: theme.textTheme.labelMedium), // l10n-ok
                                Text(
                                  '${entry.value}', // l10n-ok
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
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
