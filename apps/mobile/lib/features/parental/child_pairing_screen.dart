import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import 'parental_repository.dart';

class ChildPairingScreen extends ConsumerStatefulWidget {
  const ChildPairingScreen({super.key});

  @override
  ConsumerState<ChildPairingScreen> createState() => _ChildPairingScreenState();
}

class _ChildPairingScreenState extends ConsumerState<ChildPairingScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pairDevice() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Please enter a valid 6-digit pairing code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final success = await ref.read(parentalRepositoryProvider).pairWithCode(code);
      if (success) {
        setState(() {
          _success = 'Successfully linked with parent! Parental settings will now sync.';
          _codeController.clear();
        });
        ref.invalidate(parentLinkStatusProvider);
        ref.invalidate(deviceConfigProvider);
      } else {
        setState(() => _error = 'Invalid or expired pairing code. Please check with your parent.');
      }
    } catch (e) {
      setState(() => _error = 'Error pairing device: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final linkStatusAsync = ref.watch(parentLinkStatusProvider);
    final configAsync = ref.watch(deviceConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parental Device Management'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Status Header Card
                linkStatusAsync.when(
                  loading: () => const LoadingView(label: 'Checking parental connection...'),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (status) {
                    if (status.isLinked) {
                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(Icons.verified_user, color: colors.primary, size: Sizes.iconMd),
                                const SizedBox(width: Spacing.sm),
                                Text(
                                  'Linked with Parent',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                const Chip(label: Text('Supervised')),
                              ],
                            ),
                            const SizedBox(height: Spacing.sm),
                            Text(
                              'Profile: ${status.childDisplayName ?? "Child Device"}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              'Your digital wellbeing, screen time, and educational focus schedules are managed by your parent.',
                              style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                            ),
                          ],
                        ),
                      );
                    }
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(Icons.link_off, color: colors.textMuted, size: Sizes.iconMd),
                              const SizedBox(width: Spacing.sm),
                              Text(
                                'Not Linked to a Parent',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            'Pair this device with your parent\'s FocusLearn dashboard to enable study schedules, safety rules, and digital wellbeing.',
                            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: Spacing.xl),

                // Pairing Form
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('Pair With Code', style: theme.textTheme.titleMedium),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'Enter the 6-digit pairing code displayed on your parent\'s dashboard.',
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                      ),
                      const SizedBox(height: Spacing.md),
                      if (_error != null) ...<Widget>[
                        Text(_error!, style: TextStyle(color: colors.error, fontSize: 13)),
                        const SizedBox(height: Spacing.sm),
                      ],
                      if (_success != null) ...<Widget>[
                        Text(_success!, style: TextStyle(color: colors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: Spacing.sm),
                      ],
                      AppTextField(
                        controller: _codeController,
                        label: '6-digit Pairing Code (e.g. 849201)',
                      ),
                      const SizedBox(height: Spacing.md),
                      AppButton(
                        label: 'Pair This Device',
                        loading: _loading,
                        onPressed: _pairDevice,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xl),

                // Active Rules / Policies Summary
                configAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (config) {
                    if (config == null) return const SizedBox.shrink();
                    final limitHours = (config.dailyScreenTimeLimitMinutes / 60).toStringAsFixed(1);
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Active Supervision Settings', style: theme.textTheme.titleMedium),
                          const SizedBox(height: Spacing.sm),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.timer, color: colors.primary),
                            title: const Text('Daily Screen Time Limit'),
                            subtitle: Text('$limitHours hours / day'),
                          ),
                          if (config.bedtimeStart != null && config.bedtimeEnd != null) ...<Widget>[
                            const Divider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.bedtime, color: Colors.indigo),
                              title: const Text('Scheduled Bedtime'),
                              subtitle: Text('${config.bedtimeStart} - ${config.bedtimeEnd}'),
                            ),
                          ],
                          if (config.blockedPackages.isNotEmpty) ...<Widget>[
                            const Divider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.block, color: colors.error),
                              title: const Text('Restricted Applications'),
                              subtitle: Text('${config.blockedPackages.length} apps restricted during study sessions'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
