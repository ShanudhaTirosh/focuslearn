import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';
import 'focus_models.dart';
import 'focus_repository.dart';

/// Study forest showcasing planted trees, gentle streaks, and earned achievement badges.
class ForestScreen extends ConsumerWidget {
  const ForestScreen({super.key});

  static String _isoDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;
    final sessionsAsync = ref.watch(focusSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.focusForest),
      ),
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () => LoadingView(label: l10n.loadingProfile),
          error: (err, stack) => ErrorView(
            message: l10n.authUnknown,
            retryLabel: l10n.retry,
            onRetry: () => ref.invalidate(focusSessionsProvider),
          ),
          data: (sessions) {
            final today = _isoDate(DateTime.now());
            // Group validated seconds by local date
            final days = <String, int>{};
            for (final s in sessions) {
              final d = _isoDate(s.startedAt.toLocal());
              days[d] = (days[d] ?? 0) + s.validatedSeconds;
            }
            final focusDays = days.entries.map((e) => FocusDay(e.key, e.value)).toList();
            final streak = focusStreak(focusDays, today);
            final longest = longestFocusStreak(focusDays);

            // Filter today's sessions
            final todaySessions = sessions.where((s) => _isoDate(s.startedAt.toLocal()) == today).toList();
            final treeCounts = <String, int>{'seedling': 0, 'sapling': 0, 'tree': 0, 'grove': 0};
            for (final s in todaySessions) {
              if (treeCounts.containsKey(s.tree)) {
                treeCounts[s.tree] = (treeCounts[s.tree] ?? 0) + 1;
              }
            }

            // Achievements check
            final totalSessionsCount = sessions.where((s) => s.counted).length;
            final totalHours = sessions.fold<int>(0, (acc, s) => acc + s.validatedSeconds) / 3600.0;

            final badges = <BadgeStatus>[
              BadgeStatus(
                kind: 'first_session',
                name: 'First Focus',
                description: 'Complete your first validated focus session.',
                earned: totalSessionsCount >= 1,
              ),
              BadgeStatus(
                kind: 'sessions_25',
                name: 'Quarter Century',
                description: 'Complete 25 study sessions.',
                earned: totalSessionsCount >= 25,
              ),
              BadgeStatus(
                kind: 'hours_10',
                name: 'Deep Study 10h',
                description: 'Focus for a total of 10 hours.',
                earned: totalHours >= 10,
              ),
              BadgeStatus(
                kind: 'hours_50',
                name: 'Scholar 50h',
                description: 'Focus for a total of 50 hours.',
                earned: totalHours >= 50,
              ),
              BadgeStatus(
                kind: 'streak_3',
                name: '3-Day Momentum',
                description: 'Reach a 3-day focus streak.',
                earned: longest >= 3,
              ),
              BadgeStatus(
                kind: 'streak_7',
                name: 'Weekly Master',
                description: 'Maintain a 7-day streak.',
                earned: longest >= 7,
              ),
              BadgeStatus(
                kind: 'streak_30',
                name: 'Unstoppable 30d',
                description: 'Achieve a 30-day consistent streak.',
                earned: longest >= 30,
              ),
            ];

            return SingleChildScrollView(
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l10n.focusCurrentStreak, style: theme.textTheme.titleMedium),
                          const SizedBox(height: Spacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: <Widget>[
                              Text(
                                '${streak.streak}', // l10n-ok
                                style: theme.textTheme.displayMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: Spacing.sm),
                              Text(l10n.focusDaysCount(streak.streak.toString()), style: theme.textTheme.titleSmall),
                            ],
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            l10n.focusLongestStreak(longest.toString()),
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                          ),
                          if (streak.restDays > 0) ...<Widget>[
                            const SizedBox(height: Spacing.sm),
                            StatusBanner(
                              kind: BannerKind.info,
                              message: l10n.focusGentleRestDay,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    Text(l10n.focusForest, style: theme.textTheme.titleLarge),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: <Widget>[
                        _TreeBox(
                          icon: Icons.grass_outlined,
                          count: treeCounts['seedling'] ?? 0,
                          label: l10n.focusTreeSeedling,
                          color: colors.success,
                        ),
                        const SizedBox(width: Spacing.sm),
                        _TreeBox(
                          icon: Icons.nature_outlined,
                          count: treeCounts['sapling'] ?? 0,
                          label: l10n.focusTreeSapling,
                          color: colors.success,
                        ),
                        const SizedBox(width: Spacing.sm),
                        _TreeBox(
                          icon: Icons.park_outlined,
                          count: treeCounts['tree'] ?? 0,
                          label: l10n.focusTreeTree,
                          color: colors.success,
                        ),
                        const SizedBox(width: Spacing.sm),
                        _TreeBox(
                          icon: Icons.forest_outlined,
                          count: treeCounts['grove'] ?? 0,
                          label: l10n.focusTreeGrove,
                          color: colors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xl),
                    Text(l10n.focusAchievements, style: theme.textTheme.titleLarge),
                    const SizedBox(height: Spacing.sm),
                    ...badges.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.sm),
                          child: AppCard(
                            child: Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.all(Spacing.md),
                                  decoration: BoxDecoration(
                                    color: b.earned ? colors.surfaceVariant : colors.surface,
                                    borderRadius: BorderRadius.circular(Radii.md),
                                  ),
                                  child: Icon(
                                    b.earned ? Icons.military_tech : Icons.lock_outline,
                                    color: b.earned ? colors.warning : colors.textMuted,
                                    size: Sizes.iconMd,
                                  ),
                                ),
                                const SizedBox(width: Spacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(b.name, style: theme.textTheme.titleSmall), // l10n-ok
                                      const SizedBox(height: 2),
                                      Text(
                                        b.description, // l10n-ok
                                        style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (b.earned)
                                  Icon(Icons.check_circle, color: colors.success, size: Sizes.iconSm),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: Spacing.xl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TreeBox extends StatelessWidget {
  const _TreeBox({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(Spacing.sm),
        child: Column(
          children: <Widget>[
            Icon(icon, color: count > 0 ? color : colors.textMuted, size: Sizes.iconMd),
            const SizedBox(height: Spacing.xs),
            Text(
              '$count', // l10n-ok
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: count > 0 ? color : colors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: colors.textMuted),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
