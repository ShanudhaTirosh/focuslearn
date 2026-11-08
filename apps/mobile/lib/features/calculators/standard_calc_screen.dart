import 'package:flutter/material.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';

/// Standard study calculator with exact rational evaluation and step-by-step display.
class StandardCalcScreen extends StatefulWidget {
  const StandardCalcScreen({super.key});

  @override
  State<StandardCalcScreen> createState() => _StandardCalcScreenState();
}

class _StandardCalcScreenState extends State<StandardCalcScreen> {
  final TextEditingController _controller = TextEditingController();
  CalcResult? _result;
  String? _error;
  final List<String> _history = <String>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _append(String char) {
    setState(() {
      _controller.text = _controller.text + char;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    });
  }

  void _clear() {
    setState(() {
      _controller.clear();
      _result = null;
      _error = null;
    });
  }

  void _calculate() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      try {
        final res = evaluate(text);
        _result = res;
        _error = null;
        final summary = '$text = ${res.values['result']}';
        if (!_history.contains(summary)) {
          _history.insert(0, summary);
          if (_history.length > 10) {
            _history.removeLast();
          }
        }
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
        title: Text(l10n.calcStandard),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  controller: _controller,
                  label: l10n.calcStandard,
                  errorText: _error != null ? l10n.errorInvalidFormat : null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _calculate(),
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton(
                        label: l10n.calcCalculate,
                        onPressed: _calculate,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    AppButton(
                      label: l10n.calcClear,
                      kind: AppButtonKind.secondary,
                      onPressed: _clear,
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: <String>['+', '-', '*', '/', '^', '%', '(', ')', '.', '100'].map((op) {
                    return ActionChip(
                      label: Text(op), // l10n-ok
                      onPressed: () => _append(op),
                    );
                  }).toList(),
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
                          '${_result!.values['result']}', // l10n-ok
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
                  const SizedBox(height: Spacing.lg),
                ],
                if (_history.isNotEmpty) ...<Widget>[
                  Text(l10n.calcHistory, style: theme.textTheme.titleSmall),
                  const SizedBox(height: Spacing.sm),
                  ..._history.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(item, style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted)), // l10n-ok
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

