import 'package:flutter/material.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';
import 'commercial_calc_screen.dart';
import 'converter_screen.dart';
import 'formula_library_screen.dart';
import 'percentage_calc_screen.dart';
import 'standard_calc_screen.dart';
import 'statistics_calc_screen.dart';

/// Hub displaying all study calculators with clear categories and direct navigation.
class CalculatorsScreen extends StatelessWidget {
  const CalculatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calculatorsTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CalcCard(
                  icon: Icons.calculate_outlined,
                  title: l10n.calcStandard,
                  description: l10n.calcStandardDesc,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const StandardCalcScreen()),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                _CalcCard(
                  icon: Icons.percent_outlined,
                  title: l10n.calcPercentage,
                  description: l10n.calcPercentageDesc,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const PercentageCalcScreen()),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                _CalcCard(
                  icon: Icons.storefront_outlined,
                  title: l10n.calcCommercial,
                  description: l10n.calcCommercialDesc,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const CommercialCalcScreen()),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                _CalcCard(
                  icon: Icons.bar_chart_outlined,
                  title: l10n.calcStatistics,
                  description: l10n.calcStatisticsDesc,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const StatisticsCalcScreen()),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                _CalcCard(
                  icon: Icons.swap_horiz_outlined,
                  title: l10n.calcConverter,
                  description: l10n.calcConverterDesc,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ConverterScreen()),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                _CalcCard(
                  icon: Icons.menu_book_outlined,
                  title: l10n.calcFormulas,
                  description: l10n.calcFormulasDesc,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const FormulaLibraryScreen()),
                  ),
                ),
                const SizedBox(height: Spacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalcCard extends StatelessWidget {
  const _CalcCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(icon, size: Sizes.iconMd, color: colors.primary),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.xs),
                  Text(description, style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
