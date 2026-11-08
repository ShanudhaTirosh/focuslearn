import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';
import 'note_edit_screen.dart';
import 'notes_repository.dart';

/// Notes listing with instant keyword filtering and subject tags.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime dt) {
    const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notesTitle),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.notesNew,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NoteEditScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: l10n.notesSearch,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                ),
                onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: notesAsync.when(
                loading: () => LoadingView(label: l10n.loadingProfile),
                error: (err, stack) => ErrorView(
                  message: l10n.authUnknown,
                  retryLabel: l10n.retry,
                  onRetry: () => ref.invalidate(notesProvider),
                ),
                data: (notes) {
                  final filtered = _query.isEmpty
                      ? notes
                      : notes.where((n) {
                          return n.title.toLowerCase().contains(_query) || n.body.toLowerCase().contains(_query);
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.xl),
                        child: Text(
                          l10n.notesEmpty,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(Spacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => NoteEditScreen(note: item)),
                        ),
                        borderRadius: BorderRadius.circular(Radii.lg),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    _formatDate(item.updatedAt.toLocal()),
                                    style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                                  ),
                                ],
                              ),
                              if (item.body.isNotEmpty) ...<Widget>[
                                const SizedBox(height: Spacing.xs),
                                Text(
                                  item.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                                ),
                              ],
                            ],
                          ),
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

