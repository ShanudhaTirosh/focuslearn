import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';
import 'enforcement_repository.dart';

class EnforcementOverlayScreen extends ConsumerStatefulWidget {
  const EnforcementOverlayScreen({
    super.key,
    required this.blockedPackage,
    required this.remainingSeconds,
    this.policyId,
    this.onReturnToStudy,
    this.onOverrideGranted,
  });

  final String blockedPackage;
  final int remainingSeconds;
  final String? policyId;
  final VoidCallback? onReturnToStudy;
  final VoidCallback? onOverrideGranted;

  @override
  ConsumerState<EnforcementOverlayScreen> createState() => _EnforcementOverlayScreenState();
}

class _EnforcementOverlayScreenState extends ConsumerState<EnforcementOverlayScreen> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isOverriding = false;
  String? _reasonError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showOverrideDialog() {
    final l10n = AppLocalizations.of(context);
    final rootNav = Navigator.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final dialogNav = Navigator.of(dialogCtx);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(l10n.enforcementEmergencyOverride),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.enforcementOverrideReasonHelp, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: _reasonController,
                  autofocus: true,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.enforcementOverrideReasonTitle,
                    errorText: _reasonError,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => dialogNav.pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: _isOverriding ? null : () async {
                  final reason = _reasonController.text.trim();
                  if (reason.length < 3) {
                    setDialogState(() {
                      _reasonError = l10n.errorTooShort;
                    });
                    return;
                  }
                  setDialogState(() => _isOverriding = true);
                  await ref.read(enforcementRepositoryProvider).recordOverride(
                    policyId: widget.policyId,
                    reason: reason,
                    durationMinutes: 15,
                  );
                  if (mounted) {
                    dialogNav.pop();
                    widget.onOverrideGranted?.call();
                    rootNav.maybePop();
                  }
                },
                child: Text(l10n.enforcementOverrideConfirm),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;

    final mins = (widget.remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (widget.remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.shield_outlined,
                      size: 80,
                      color: colors.primary,
                    ),
                    const SizedBox(height: Spacing.lg),
                    Text(
                      l10n.enforcementOverlayTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      l10n.enforcementOverlayPrompt,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.md),
                    Chip(
                      backgroundColor: Colors.white12,
                      label: Text(
                        widget.blockedPackage,
                        style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: Spacing.xxl),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl, vertical: Spacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            '$mins:$secs',
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            l10n.enforcementOverlayTimeRemaining('$mins:$secs'),
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xxl),
                    AppButton(
                      label: l10n.focusStart,
                      onPressed: () {
                        widget.onReturnToStudy?.call();
                        Navigator.of(context).maybePop();
                      },
                    ),
                    const SizedBox(height: Spacing.md),
                    AppButton(
                      label: l10n.enforcementEmergencyOverride,
                      kind: AppButtonKind.secondary,
                      onPressed: _showOverrideDialog,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
