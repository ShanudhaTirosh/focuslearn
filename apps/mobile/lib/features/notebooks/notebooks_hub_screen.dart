import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';
import 'notebook_detail_screen.dart';
import 'notebook_repository.dart';

/// Research Notebooks Hub where students manage NotebookLM-style study notebooks.
class NotebooksHubScreen extends ConsumerStatefulWidget {
  const NotebooksHubScreen({super.key});

  @override
  ConsumerState<NotebooksHubScreen> createState() => _NotebooksHubScreenState();
}

class _NotebooksHubScreenState extends ConsumerState<NotebooksHubScreen> {
  void _showCreateNotebookDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedColor = '#4F46E5';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Research Notebook'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppTextField(
                      controller: titleController,
                      label: 'Notebook Title',
                    ),
                    const SizedBox(height: Spacing.md),
                    AppTextField(
                      controller: descController,
                      label: 'Description / Subject (e.g. Combined Maths A/L)',
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <String>[
                        '#4F46E5', '#059669', '#DC2626', '#D97706', '#7C3AED'
                      ].map((hex) {
                        final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                        final isSelected = selectedColor == hex;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = hex),
                          child: CircleAvatar(
                            backgroundColor: color,
                            radius: isSelected ? 16 : 12,
                            child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final t = titleController.text.trim();
                    if (t.isNotEmpty) {
                      await ref.read(notebookRepositoryProvider).createNotebook(
                        title: t,
                        description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                        color: selectedColor,
                      );
                      ref.invalidate(myNotebooksProvider);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Create'),
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

    final notebooksAsync = ref.watch(myNotebooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notebooksTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateNotebookDialog,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('New Notebook'),
      ),
      body: SafeArea(
        child: notebooksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text('Error loading notebooks: $err', style: TextStyle(color: colors.error)),
          ),
          data: (notebooks) {
            if (notebooks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.menu_book_outlined, size: 64, color: colors.textMuted),
                      const SizedBox(height: Spacing.md),
                      Text(
                        'No Research Notebooks Yet',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        l10n.notebooksDesc,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                      ),
                      const SizedBox(height: Spacing.lg),
                      FilledButton.icon(
                        onPressed: _showCreateNotebookDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Notebook'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(Spacing.md),
              itemCount: notebooks.length,
              separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
              itemBuilder: (context, index) {
                final nb = notebooks[index];
                final color = Color(int.tryParse(nb.color.replaceFirst('#', '0xFF')) ?? 0xFF4F46E5);

                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NotebookDetailScreen(notebook: nb),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 56,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(Radii.sm),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(nb.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              if (nb.description != null) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  nb.description!,
                                  style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  Icon(Icons.auto_stories_outlined, size: 14, color: colors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Grounded Research Notebook',
                                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: colors.textMuted),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
