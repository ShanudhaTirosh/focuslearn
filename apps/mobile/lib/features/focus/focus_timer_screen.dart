import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../enforcement/enforcement_overlay_screen.dart';
import '../enforcement/enforcement_repository.dart';
import '../enforcement/enforcement_rules_screen.dart';
import 'focus_models.dart';
import 'focus_repository.dart';
import 'forest_screen.dart';

enum _TimerState { idle, running, paused, finished }

/// Study focus timer with presets, pause handling, tree progress, and emergency exit.
class FocusTimerScreen extends ConsumerStatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  ConsumerState<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends ConsumerState<FocusTimerScreen> {
  int _plannedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  int _elapsedActiveSeconds = 0;
  int _totalPausedSeconds = 0;
  _TimerState _state = _TimerState.idle;
  Timer? _timer;
  Timer? _monitoringTimer;
  DateTime? _startedAt;
  DateTime? _pausedAt;
  DateTime? _overrideUntil;

  @override
  void dispose() {
    _timer?.cancel();
    _monitoringTimer?.cancel();
    super.dispose();
  }

  void _setDuration(int minutes) {
    if (_state != _TimerState.idle) return;
    setState(() {
      _plannedMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _elapsedActiveSeconds = 0;
      _totalPausedSeconds = 0;
    });
  }

  void _start() {
    setState(() {
      _state = _TimerState.running;
      _startedAt = DateTime.now();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    _startMonitoring();
  }

  void _pause() {
    _timer?.cancel();
    _stopMonitoring();
    setState(() {
      _state = _TimerState.paused;
      _pausedAt = DateTime.now();
    });
  }

  void _resume() {
    if (_pausedAt != null) {
      _totalPausedSeconds += DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
    }
    setState(() {
      _state = _TimerState.running;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    _startMonitoring();
  }

  void _startMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkDistractions());
  }

  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  Future<void> _checkDistractions() async {
    if (_state != _TimerState.running) return;
    if (_overrideUntil != null && DateTime.now().isBefore(_overrideUntil!)) return;

    final platform = ref.read(nativePlatformServiceProvider);
    final foreground = await platform.getForegroundPackage();
    if (foreground == null || foreground.isEmpty) return;

    final enforcementRepo = ref.read(enforcementRepositoryProvider);
    final policies = await enforcementRepo.loadCachedPolicies();

    if (enforcementRepo.isPackageRestricted(foreground, policies)) {
      await enforcementRepo.recordViolation(
        deviceId: 'current-device',
        packageName: foreground,
        violationType: 'distraction_opened',
      );
      await platform.bringAppToFront();

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EnforcementOverlayScreen(
              blockedPackage: foreground,
              remainingSeconds: _remainingSeconds,
              onOverrideGranted: () {
                setState(() {
                  _overrideUntil = DateTime.now().add(const Duration(minutes: 15));
                });
              },
            ),
          ),
        );
      }
    }
  }

  void _tick(Timer timer) {
    if (_remainingSeconds > 0) {
      setState(() {
        _remainingSeconds--;
        _elapsedActiveSeconds++;
      });
    } else {
      _finish(status: 'completed');
    }
  }

  Future<void> _finish({required String status}) async {
    _timer?.cancel();
    _stopMonitoring();
    if (_pausedAt != null) {
      _totalPausedSeconds += DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
    }
    final ended = DateTime.now();
    final started = _startedAt ?? ended.subtract(Duration(seconds: _elapsedActiveSeconds + _totalPausedSeconds));

    final session = await ref.read(focusRepositoryProvider).recordSession(
      startedAt: started,
      endedAt: ended,
      plannedSeconds: _plannedMinutes * 60,
      clientReportedSeconds: _elapsedActiveSeconds,
      pauseSeconds: _totalPausedSeconds,
      status: status,
    );

    ref.invalidate(focusSessionsProvider);

    if (mounted) {
      setState(() {
        _state = _TimerState.finished;
      });
      _showCompletionDialog(session);
    }
  }

  void _confirmEmergencyExit() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.focusEmergencyExit),
          content: Text(l10n.focusEmergencyExitConfirm),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _finish(status: 'ended_early');
              },
              child: Text(l10n.focusEmergencyExit),
            ),
          ],
        );
      },
    );
  }

  void _showCompletionDialog(StudySession session) {
    final l10n = AppLocalizations.of(context);
    final minutes = (session.validatedSeconds / 60).round();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.doneMessage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.focusTreeEarned(session.tree)),
              const SizedBox(height: Spacing.sm),
              Text(l10n.focusValidatedMinutes(minutes.toString())),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _state = _TimerState.idle;
                  _remainingSeconds = _plannedMinutes * 60;
                  _elapsedActiveSeconds = 0;
                  _totalPausedSeconds = 0;
                });
              },
              child: Text(l10n.continueLabel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ForestScreen()),
                );
              },
              child: Text(l10n.focusForest),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;

    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final progress = _plannedMinutes > 0 ? (_elapsedActiveSeconds / (_plannedMinutes * 60)).clamp(0.0, 1.0) : 0.0;
    final currentTree = treeStage(_elapsedActiveSeconds);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.focusTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.enforcementTitle,
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EnforcementRulesScreen()),
            ),
          ),
          IconButton(
            tooltip: l10n.focusForest,
            icon: const Icon(Icons.park_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ForestScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: Spacing.lg),
                if (_state == _TimerState.idle) ...<Widget>[
                  Text(l10n.focusDuration, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.md),
                  Wrap(
                    spacing: Spacing.sm,
                    children: <int>[15, 25, 50, 90].map((m) {
                      return ChoiceChip(
                        label: Text(l10n.focusMinutes(m.toString())),
                        selected: _plannedMinutes == m,
                        onSelected: (_) => _setDuration(m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: Spacing.xl),
                ],
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: colors.surfaceVariant,
                        color: colors.primary,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '$mins:$secs', // l10n-ok
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          l10n.focusTreeEarned(currentTree),
                          style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xxl),
                if (_state == _TimerState.idle)
                  AppButton(
                    label: l10n.focusStart,
                    onPressed: _start,
                  )
                else if (_state == _TimerState.running)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      AppButton(
                        label: l10n.focusPause,
                        kind: AppButtonKind.secondary,
                        onPressed: _pause,
                      ),
                      const SizedBox(width: Spacing.md),
                      AppButton(
                        label: l10n.focusEndEarly,
                        onPressed: () => _finish(status: 'ended_early'),
                      ),
                    ],
                  )
                else if (_state == _TimerState.paused)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      AppButton(
                        label: l10n.focusResume,
                        onPressed: _resume,
                      ),
                      const SizedBox(width: Spacing.md),
                      AppButton(
                        label: l10n.focusEmergencyExit,
                        kind: AppButtonKind.secondary,
                        onPressed: _confirmEmergencyExit,
                      ),
                    ],
                  ),
                const SizedBox(height: Spacing.xl),
                AppCard(
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.info_outline, color: colors.primary, size: Sizes.iconMd),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Text(
                          l10n.focusGentleRestDay,
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

