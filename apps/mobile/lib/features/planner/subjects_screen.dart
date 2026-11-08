import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';
import 'planner_models.dart';
import 'planner_repository.dart';

/// Manage academic subjects and stream groupings.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  void _showAddSubjectDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    String stream = 'science';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.plannerSubjects),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppTextField(
                    controller: controller,
                    label: l10n.displayNameLabel,
                  ),
                  const SizedBox(height: Spacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: stream,
                    decoration: InputDecoration(labelText: l10n.streamLabel),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'technology', child: Text(l10n.streamTechnology)),
                      DropdownMenuItem<String>(value: 'commerce', child: Text(l10n.streamCommerce)),
                      DropdownMenuItem<String>(value: 'science', child: Text(l10n.streamScience)),
                      DropdownMenuItem<String>(value: 'mathematics', child: Text(l10n.streamMathematics)),
                      DropdownMenuItem<String>(value: 'arts', child: Text(l10n.streamArts)),
                      DropdownMenuItem<String>(value: 'other', child: Text(l10n.streamOther)),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => stream = val);
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      final subject = Subject(
                        id: generateUuidV4(Random.secure()),
                        name: name,
                        stream: stream,
                      );
                      await ref.read(plannerRepositoryProvider).saveSubject(subject);
                      ref.invalidate(subjectsProvider);
                      if (context.mounted) Navigator.of(ctx).pop();
                    }
                  },
                  child: Text(l10n.plannerSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plannerSubjects),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSubjectDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: subjectsAsync.when(
          loading: () => LoadingView(label: l10n.loadingProfile),
          error: (err, stack) => ErrorView(
            message: l10n.authUnknown,
            retryLabel: l10n.retry,
            onRetry: () => ref.invalidate(subjectsProvider),
          ),
          data: (subjects) {
            if (subjects.isEmpty) {
              return Center(
                child: Text(
                  'No subjects added yet. Tap + to add one.', // l10n-ok
                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                ),
              );
            }
            return SingleChildScrollView(
              child: ContentWidth(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(Spacing.md),
                  itemCount: subjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                  itemBuilder: (context, index) {
                    final s = subjects[index];
                    return AppCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(s.name, style: theme.textTheme.titleMedium),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(Radii.sm),
                            ),
                            child: Text(
                              s.stream.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(color: colors.primary),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
