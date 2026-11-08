import 'package:flutter/material.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';

/// Statistics calculator for descriptive summary measures and step details.
class StatisticsCalcScreen extends StatefulWidget {
  const StatisticsCalcScreen({super.key});

  @override
  State<StatisticsCalcScreen> createState() => _StatisticsCalcScreenState();
}

class _StatisticsCalcScreenState extends State<StatisticsCalcScreen> {
  final TextEditingController _dataController = TextEditingController();
  CalcResult? _result;
  String? _error;

  @override
  void dispose() {
    _dataController.dispose();
    super.dispose();
  }

  void _calculate() {
    final raw = _dataController.text.trim();
    if (raw.isEmpty) {
      return;
    }
    // Split by commas, spaces, or newlines
    final parts = raw.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) {
      return;
    }

    setState(() {
      try {
        _result = statistics(parts);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calcStatistics),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  controller: _dataController,
                  label: l10n.calcStatistics,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: Spacing.xs),
                Text(l10n.calcDataListHint, style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted)),
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
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
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

