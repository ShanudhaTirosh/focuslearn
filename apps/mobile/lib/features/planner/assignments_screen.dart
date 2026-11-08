import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';
import 'planner_models.dart';
import 'planner_repository.dart';

/// Homework and assignment deadline manager.
class AssignmentsScreen extends ConsumerStatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  ConsumerState<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends ConsumerState<AssignmentsScreen> {
  int _tabIndex = 0; // 0 = pending, 1 = completed

  static String _formatDate(DateTime dt) {
    const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  void _showAddAssignmentDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController();
    final detailsController = TextEditingController();
    DateTime due = DateTime.now().add(const Duration(days: 3));

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.plannerAssignments),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppTextField(
                    controller: titleController,
                    label: l10n.displayNameLabel,
                  ),
                  const SizedBox(height: Spacing.md),
                  AppTextField(
                    controller: detailsController,
                    label: 'Description / Notes', // l10n-ok
                  ),
                  const SizedBox(height: Spacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(l10n.plannerDue(_formatDate(due))),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: due,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => due = picked);
                          }
                        },
                        child: const Text('Change Date'), // l10n-ok
                      ),
                    ],
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
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      final assignment = Assignment(
                        id: generateUuidV4(Random.secure()),
                        title: title,
                        details: detailsController.text.trim().isNotEmpty ? detailsController.text.trim() : null,
                        dueUtc: due.toUtc(),
                        status: 'pending',
                      );
                      await ref.read(plannerRepositoryProvider).saveAssignment(assignment);
                      ref.invalidate(assignmentsProvider);
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;
    final assignmentsAsync = ref.watch(assignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plannerAssignments),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAssignmentDialog(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: SegmentedButton<int>(
                segments: <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 0, label: Text(l10n.plannerAssignmentPending)),
                  ButtonSegment<int>(value: 1, label: Text(l10n.plannerAssignmentCompleted)),
                ],
                selected: <int>{_tabIndex},
                onSelectionChanged: (set) => setState(() => _tabIndex = set.first),
              ),
            ),
            Expanded(
              child: assignmentsAsync.when(
                loading: () => LoadingView(label: l10n.loadingProfile),
                error: (err, stack) => ErrorView(
                  message: l10n.authUnknown,
                  retryLabel: l10n.retry,
                  onRetry: () => ref.invalidate(assignmentsProvider),
                ),
                data: (all) {
                  final filtered = all.where((a) => _tabIndex == 0 ? !a.isCompleted : a.isCompleted).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _tabIndex == 0 ? 'No pending assignments.' : 'No completed assignments yet.', // l10n-ok
                        style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(Spacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Checkbox(
                              value: item.isCompleted,
                              onChanged: (val) async {
                                final updated = item.copyWith(status: val == true ? 'completed' : 'pending');
                                await ref.read(plannerRepositoryProvider).saveAssignment(updated);
                                ref.invalidate(assignmentsProvider);
                              },
                            ),
                            const SizedBox(width: Spacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                      color: item.isCompleted ? colors.textMuted : colors.text,
                                    ),
                                  ),
                                  if (item.details != null && item.details!.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: Spacing.xs),
                                    Text(
                                      item.details!,
                                      style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                                    ),
                                  ],
                                  const SizedBox(height: Spacing.xs),
                                  Text(
                                    l10n.plannerDue(_formatDate(item.dueUtc.toLocal())),
                                    style: theme.textTheme.bodySmall?.copyWith(color: colors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
