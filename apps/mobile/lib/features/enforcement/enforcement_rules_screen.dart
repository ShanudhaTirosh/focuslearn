import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import 'enforcement_repository.dart';

class EnforcementRulesScreen extends ConsumerStatefulWidget {
  const EnforcementRulesScreen({super.key});

  @override
  ConsumerState<EnforcementRulesScreen> createState() => _EnforcementRulesScreenState();
}

class _EnforcementRulesScreenState extends ConsumerState<EnforcementRulesScreen> {
  bool _usageGranted = false;
  bool _overlayGranted = false;
  bool _loading = false;
  final TextEditingController _customAppController = TextEditingController();

  static const List<String> _commonDistractions = <String>[
    'com.instagram.android',
    'com.zhiliaoapp.musically', // TikTok
    'com.google.android.youtube',
    'com.facebook.katana',
    'com.twitter.android',
    'com.snapchat.android',
    'com.reddit.frontpage',
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _customAppController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final platform = ref.read(nativePlatformServiceProvider);
    final usage = await platform.checkUsagePermission();
    final overlay = await platform.checkOverlayPermission();
    if (mounted) {
      setState(() {
        _usageGranted = usage;
        _overlayGranted = overlay;
      });
    }
  }

  Future<void> _addPolicy(List<String> packages) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      await ref.read(enforcementRepositoryProvider).createPolicy(
        title: l10n.enforcementBlockedApps,
        mode: 'focus_session_lock',
        blockedPackages: packages,
      );
      ref.invalidate(activePoliciesProvider);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;

    final policiesAsync = ref.watch(activePoliciesProvider);
    final violationsAsync = ref.watch(violationsHistoryProvider);
    final overridesAsync = ref.watch(overridesHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.enforcementTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retry,
            onPressed: () {
              _checkPermissions();
              ref.invalidate(activePoliciesProvider);
              ref.invalidate(violationsHistoryProvider);
              ref.invalidate(overridesHistoryProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Permission status section
                  Text(l10n.enforcementPermissionsTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.sm),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _usageGranted ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: _usageGranted ? colors.primary : colors.error,
                          ),
                          title: const Text('Usage Access'),
                          subtitle: Text(l10n.enforcementUsageAccessRequired),
                          trailing: _usageGranted
                              ? Chip(label: Text(l10n.enforcementPermissionGranted))
                              : AppButton(
                                  label: l10n.enforcementGrantPermission,
                                  kind: AppButtonKind.secondary,
                                  onPressed: () async {
                                    await ref.read(nativePlatformServiceProvider).openUsageSettings();
                                    Future<void>.delayed(const Duration(seconds: 1), _checkPermissions);
                                  },
                                ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _overlayGranted ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: _overlayGranted ? colors.primary : colors.error,
                          ),
                          title: const Text('Display Over Apps'),
                          subtitle: Text(l10n.enforcementOverlayRequired),
                          trailing: _overlayGranted
                              ? Chip(label: Text(l10n.enforcementPermissionGranted))
                              : AppButton(
                                  label: l10n.enforcementGrantPermission,
                                  kind: AppButtonKind.secondary,
                                  onPressed: () async {
                                    await ref.read(nativePlatformServiceProvider).openOverlaySettings();
                                    Future<void>.delayed(const Duration(seconds: 1), _checkPermissions);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),

                  // Active Rules Section
                  Text(l10n.enforcementActiveRules, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.sm),
                  policiesAsync.when(
                    loading: () => const LoadingView(label: 'Loading rules...'),
                    error: (_, __) => ErrorView(
                      message: l10n.errorGeneric,
                      retryLabel: l10n.retry,
                      onRetry: () => ref.invalidate(activePoliciesProvider),
                    ),
                    data: (policies) {
                      if (policies.isEmpty) {
                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(l10n.enforcementNoRules, style: theme.textTheme.bodyMedium),
                              const SizedBox(height: Spacing.md),
                              AppButton(
                                label: 'Enable Default Study Distraction Block',
                                loading: _loading,
                                onPressed: () => _addPolicy(_commonDistractions),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: policies.map((p) {
                          return AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Icon(Icons.shield, color: colors.primary),
                                    const SizedBox(width: Spacing.sm),
                                    Expanded(
                                      child: Text(
                                        p.title,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(p.mode == 'focus_session_lock' ? 'Focus Lock' : p.mode),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: Spacing.sm),
                                Text(
                                  'Restricted packages: ${p.blockedPackages.length} apps',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: Spacing.xs),
                                Wrap(
                                  spacing: Spacing.xs,
                                  runSpacing: Spacing.xs,
                                  children: p.blockedPackages.map((pkg) {
                                    final short = pkg.split('.').last;
                                    return Chip(label: Text(short));
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: Spacing.xl),

                  // Violations & Overrides History
                  Text(l10n.enforcementViolationsHistory, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.sm),
                  violationsAsync.when(
                    loading: () => const LoadingView(label: 'Loading violations...'),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (violations) {
                      if (violations.isEmpty) {
                        return AppCard(
                          child: Text(l10n.enforcementNoViolations, style: theme.textTheme.bodyMedium),
                        );
                      }
                      return AppCard(
                        child: Column(
                          children: violations.take(5).map((v) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.block, color: Colors.amber),
                              title: Text(v.packageName),
                              subtitle: Text(
                                '${v.violationType} • ${v.occurredAt.toLocal().toString().substring(0, 16)}',
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: Spacing.xl),

                  // Overrides History
                  Text(l10n.enforcementOverridesHistory, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.sm),
                  overridesAsync.when(
                    loading: () => const LoadingView(label: 'Loading overrides...'),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (overrides) {
                      if (overrides.isEmpty) {
                        return const AppCard(child: Text('No emergency overrides used.'));
                      }
                      return AppCard(
                        child: Column(
                          children: overrides.take(5).map((o) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.key, color: Colors.blue),
                              title: Text('Reason: "${o.reason}"'),
                              subtitle: Text(
                                '${o.durationMinutes} min unlock • ${o.createdAt.toLocal().toString().substring(0, 16)}',
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
