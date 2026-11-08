import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../app/messages.dart';
import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_repository.dart';
import '../devices/device_repository.dart';
import '../profile/profile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<bool> _confirm(String title, String body, String confirmLabel) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(confirmLabel)),
        ],
      ),
    );
    return result ?? false;
  }

  /// Runs [action] with a busy flag and reports the outcome in a snack bar. Failures show a coarse message only.
  Future<void> _run(Future<void> Function() action, {bool announceDone = true}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (announceDone) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.doneMessage)));
      }
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(authMessage(l10n, e.kind))));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final prefs = ref.watch(userPreferencesProvider).valueOrNull ?? UserPreferences.defaults;
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '';
    final installId = ref.watch(installIdProvider).valueOrNull;
    final devices = ref.watch(devicesProvider);
    final pendingDeletion = ref.watch(pendingDeletionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.accountSection, style: text.titleLarge),
                const SizedBox(height: Spacing.sm),
                Text(l10n.signedInAs(email), style: text.bodyMedium),
                const SizedBox(height: Spacing.md),
                AppButton(
                  label: l10n.signOut,
                  kind: AppButtonKind.secondary,
                  onPressed: _busy ? null : () => _run(() => ref.read(authRepositoryProvider).signOut(), announceDone: false),
                ),
                const SizedBox(height: Spacing.sm),
                AppButton(
                  label: l10n.signOutOthers,
                  kind: AppButtonKind.secondary,
                  onPressed: _busy
                      ? null
                      : () async {
                          final ok = await _confirm(l10n.signOutOthers, l10n.signOutOthersBody, l10n.signOutOthersConfirm);
                          if (ok) {
                            await _run(() => ref.read(authRepositoryProvider).signOutOthers());
                          }
                        },
                ),
                const SizedBox(height: Spacing.xxl),
                Text(l10n.preferencesSection, style: text.titleLarge),
                const SizedBox(height: Spacing.md),
                DropdownMenu<String>(
                  initialSelection: prefs.language,
                  label: Text(l10n.languageLabel),
                  expandedInsets: EdgeInsets.zero,
                  enabled: !_busy,
                  dropdownMenuEntries: <DropdownMenuEntry<String>>[
                    DropdownMenuEntry<String>(value: 'en', label: l10n.languageEnglish),
                    DropdownMenuEntry<String>(value: 'si', label: l10n.languageSinhala),
                    DropdownMenuEntry<String>(value: 'ta', label: l10n.languageTamil),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      _run(() async {
                        await ref.read(profileRepositoryProvider).updatePreferences(language: value);
                        ref.invalidate(userPreferencesProvider);
                      });
                    }
                  },
                ),
                const SizedBox(height: Spacing.lg),
                DropdownMenu<String>(
                  initialSelection: prefs.theme,
                  label: Text(l10n.themeLabel),
                  expandedInsets: EdgeInsets.zero,
                  enabled: !_busy,
                  dropdownMenuEntries: <DropdownMenuEntry<String>>[
                    DropdownMenuEntry<String>(value: 'system', label: l10n.themeSystem),
                    DropdownMenuEntry<String>(value: 'light', label: l10n.themeLight),
                    DropdownMenuEntry<String>(value: 'dark', label: l10n.themeDark),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      _run(() async {
                        await ref.read(profileRepositoryProvider).updatePreferences(theme: value);
                        ref.invalidate(userPreferencesProvider);
                      });
                    }
                  },
                ),
                const SizedBox(height: Spacing.xxl),
                Text(l10n.devicesSection, style: text.titleLarge),
                const SizedBox(height: Spacing.sm),
                devices.when(
                  loading: () => Padding(padding: const EdgeInsets.all(Spacing.lg), child: LoadingView(label: l10n.devicesSection)),
                  error: (error, stack) => ErrorView(
                    message: l10n.errorGeneric,
                    retryLabel: l10n.retry,
                    onRetry: () => ref.invalidate(devicesProvider),
                  ),
                  data: (list) => list.isEmpty
                      ? Text(l10n.devicesNone, style: text.bodyMedium)
                      : Column(
                          children: <Widget>[
                            for (final d in list)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(d.name),
                                subtitle: Text(d.installId == installId ? l10n.thisDevice : d.platform),
                                trailing: d.installId == installId
                                    ? null
                                    : TextButton(
                                        onPressed: _busy ? null : () => _removeDevice(d),
                                        child: Text(l10n.removeDevice),
                                      ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(l10n.devicesNote, style: text.bodySmall),
                const SizedBox(height: Spacing.xxl),
                Text(l10n.privacySection, style: text.titleLarge),
                const SizedBox(height: Spacing.sm),
                Text(l10n.deletionTitle, style: text.titleMedium),
                const SizedBox(height: Spacing.xs),
                Text(l10n.deletionBody, style: text.bodyMedium),
                const SizedBox(height: Spacing.md),
                pendingDeletion.when(
                  loading: () => LoadingView(label: l10n.deletionTitle),
                  error: (error, stack) => ErrorView(
                    message: l10n.errorGeneric,
                    retryLabel: l10n.retry,
                    onRetry: () => ref.invalidate(pendingDeletionProvider),
                  ),
                  data: (scheduled) => scheduled == null
                      ? AppButton(
                          label: l10n.requestDeletion,
                          kind: AppButtonKind.secondary,
                          onPressed: _busy
                              ? null
                              : () async {
                                  final ok = await _confirm(l10n.deletionTitle, l10n.deletionBody, l10n.requestDeletion);
                                  if (ok) {
                                    await _run(() async {
                                      await ref.read(profileRepositoryProvider).requestDeletion();
                                      ref.invalidate(pendingDeletionProvider);
                                    });
                                  }
                                },
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            StatusBanner(
                              kind: BannerKind.warning,
                              message: l10n.deletionPending(MaterialLocalizations.of(context).formatMediumDate(scheduled)),
                            ),
                            const SizedBox(height: Spacing.md),
                            AppButton(
                              label: l10n.cancelDeletion,
                              kind: AppButtonKind.secondary,
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                        await ref.read(profileRepositoryProvider).cancelDeletion();
                                        ref.invalidate(pendingDeletionProvider);
                                      }),
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

  Future<void> _removeDevice(DeviceInfo device) async {
    final l10n = AppLocalizations.of(context);
    final ok = await _confirm(l10n.removeDevice, l10n.removeDeviceBody, l10n.removeDevice);
    if (ok) {
      await _run(() async {
        await ref.read(deviceRepositoryProvider).remove(device.id);
        ref.invalidate(devicesProvider);
      });
    }
  }
}
