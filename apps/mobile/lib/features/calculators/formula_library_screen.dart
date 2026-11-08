import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';

class _FormulaItem {
  const _FormulaItem({required this.stream, required this.title, required this.formula, required this.description});

  final String stream;
  final String title;
  final String formula;
  final String description;
}

/// Curated study formula reference for Sri Lankan G.C.E. A/L streams.
class FormulaLibraryScreen extends ConsumerStatefulWidget {
  const FormulaLibraryScreen({super.key});

  @override
  ConsumerState<FormulaLibraryScreen> createState() => _FormulaLibraryScreenState();
}

class _FormulaLibraryScreenState extends ConsumerState<FormulaLibraryScreen> {
  final List<_FormulaItem> _items = <_FormulaItem>[
    const _FormulaItem(
      stream: 'Commerce',
      title: 'Accounting Equation',
      formula: 'Assets = Liabilities + Owner\'s Equity',
      description: 'The foundation of double-entry bookkeeping.',
    ),
    const _FormulaItem(
      stream: 'Commerce',
      title: 'Break-Even Point (Units)',
      formula: 'BEP = Fixed Costs / (Price - Variable Cost)',
      description: 'The volume where total revenue equals total costs.',
    ),
    const _FormulaItem(
      stream: 'Commerce',
      title: 'Compound Interest',
      formula: 'A = P(1 + r/n)^(nt)',
      description: 'Total accumulated amount with periodic compounding.',
    ),
    const _FormulaItem(
      stream: 'Science / Maths',
      title: 'Newton\'s Second Law',
      formula: 'F = m * a',
      description: 'Force is equal to mass multiplied by acceleration.',
    ),
    const _FormulaItem(
      stream: 'Science / Maths',
      title: 'Kinetic Energy',
      formula: 'Ek = 1/2 * m * v^2',
      description: 'Work needed to accelerate a body of mass m to velocity v.',
    ),
    const _FormulaItem(
      stream: 'Science / Maths',
      title: 'Ideal Gas Law',
      formula: 'P * V = n * R * T',
      description: 'Equation of state of a hypothetical ideal gas.',
    ),
    const _FormulaItem(
      stream: 'Technology',
      title: 'Ohm\'s Law',
      formula: 'V = I * R',
      description: 'Voltage equals current times resistance in an electrical circuit.',
    ),
    const _FormulaItem(
      stream: 'Technology',
      title: 'Electrical Power',
      formula: 'P = V * I = I^2 * R',
      description: 'The rate at which electrical energy is transferred.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final client = ref.read(supabaseClientProvider);
        final res = await client
            .from('formula_entries')
            .select('stream, title, latex, description')
            .eq('status', 'published');

        if (mounted && (res as List<dynamic>).isNotEmpty) {
          final fetched = (res as List<dynamic>).map((row) {
            return _FormulaItem(
              stream: (row['stream'] as String?)?.toUpperCase() ?? 'GENERAL',
              title: (row['title'] as String?) ?? 'Formula',
              formula: (row['latex'] as String?) ?? '',
              description: (row['description'] as String?) ?? '',
            );
          }).toList();

          setState(() {
            _items.insertAll(0, fetched);
          });
        }
      } catch (_) {
        // Offline resilience fallback
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
        title: Text(l10n.calcFormulas),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _items.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(child: Text(f.title, style: theme.textTheme.titleMedium)), // l10n-ok
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: colors.surfaceVariant,
                                borderRadius: BorderRadius.circular(Radii.sm),
                              ),
                              child: Text(
                                f.stream, // l10n-ok
                                style: theme.textTheme.labelSmall?.copyWith(color: colors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Spacing.md),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          child: Text(
                            f.formula, // l10n-ok
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace', // l10n-ok
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          f.description, // l10n-ok
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

