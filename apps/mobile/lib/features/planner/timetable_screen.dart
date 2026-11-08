import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import 'assignments_screen.dart';
import 'event_edit_screen.dart';
import 'meeting_launcher.dart';
import 'planner_models.dart';
import 'planner_repository.dart';
import 'subjects_screen.dart';

/// Interactive Timetable and study schedule with recurrence expansion and conflict alerts.
class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  DateTime _selectedDate = DateTime.now();

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final min = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM'; // l10n-ok
    return '$hour:$min $period';
  }

  static String _formatDate(DateTime dt) {
    const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  void _changeDay(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
    });
  }

  void _jumpToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;

    final eventsAsync = ref.watch(timetableEventsProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plannerTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.doneMessage,
            icon: const Icon(Icons.alarm_on_outlined),
            onPressed: () async {
              final platform = ref.read(nativePlatformServiceProvider);
              await platform.checkUsagePermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.doneMessage)));
              }
            },
          ),
          IconButton(
            tooltip: l10n.plannerSubjects,
            icon: const Icon(Icons.book_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SubjectsScreen()),
            ),
          ),
          IconButton(
            tooltip: l10n.plannerAssignments,
            icon: const Icon(Icons.assignment_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AssignmentsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.plannerAddEvent,
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EventEditScreen(initialDate: _selectedDate),
            ),
          );
          ref.invalidate(timetableEventsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Date navigation bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _changeDay(-1),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _formatDate(_selectedDate),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _changeDay(1),
                  ),
                  TextButton(
                    onPressed: _jumpToToday,
                    child: Text(l10n.plannerToday),
                  ),
                ],
              ),
            ),
            Expanded(
              child: eventsAsync.when(
                loading: () => LoadingView(label: l10n.loadingProfile),
                error: (err, stack) => ErrorView(
                  message: l10n.authUnknown,
                  retryLabel: l10n.retry,
                  onRetry: () => ref.invalidate(timetableEventsProvider),
                ),
                data: (allEvents) {
                  final subjects = subjectsAsync.valueOrNull ?? <Subject>[];
                  final subjectMap = <String, Subject>{for (final s in subjects) s.id: s};

                  final repo = ref.read(plannerRepositoryProvider);
                  final expanded = repo.expandForDay(allEvents, _selectedDate);
                  final conflicts = repo.findConflictIndices(expanded);

                  return SingleChildScrollView(
                    child: ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (conflicts.isNotEmpty) ...<Widget>[
                            Padding(
                              padding: const EdgeInsets.all(Spacing.md),
                              child: StatusBanner(
                                kind: BannerKind.warning,
                                message: l10n.plannerConflictWarning,
                              ),
                            ),
                          ],
                          if (expanded.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(Spacing.xxl),
                              child: Center(
                                child: Text(
                                  'No scheduled classes for this date.', // l10n-ok
                                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(Spacing.md),
                              itemCount: expanded.length,
                              separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                              itemBuilder: (context, index) {
                                final occ = expanded[index];
                                final hasConflict = conflicts.contains(index);
                                final subj = occ.event.subjectId != null ? subjectMap[occ.event.subjectId] : null;

                                return AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              occ.event.title,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                color: hasConflict ? colors.error : colors.text,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (subj != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: colors.surfaceVariant,
                                                borderRadius: BorderRadius.circular(Radii.sm),
                                              ),
                                              child: Text(
                                                subj.name,
                                                style: theme.textTheme.labelSmall?.copyWith(color: colors.primary),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: Spacing.xs),
                                      Row(
                                        children: <Widget>[
                                          Icon(Icons.access_time, size: Sizes.iconSm, color: colors.textMuted),
                                          const SizedBox(width: Spacing.xs),
                                          Text(
                                            '${_formatTime(occ.start)} - ${_formatTime(occ.end)}',
                                            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                                          ),
                                        ],
                                      ),
                                      if (occ.event.location != null && occ.event.location!.isNotEmpty) ...<Widget>[
                                        const SizedBox(height: Spacing.xs),
                                        Row(
                                          children: <Widget>[
                                            Icon(Icons.location_on_outlined, size: Sizes.iconSm, color: colors.textMuted),
                                            const SizedBox(width: Spacing.xs),
                                            Expanded(
                                              child: Text(
                                                occ.event.location!,
                                                style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (occ.event.meetingUrl != null && occ.event.meetingUrl!.isNotEmpty) ...<Widget>[
                                        const SizedBox(height: Spacing.md),
                                        FilledButton.icon(
                                          icon: const Icon(Icons.video_camera_front_outlined, size: 18),
                                          label: Text(l10n.plannerJoinClass),
                                          onPressed: () => MeetingLauncher.launch(context, occ.event.meetingUrl!),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: Spacing.xxl),
                        ],
                      ),
                    ),
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
