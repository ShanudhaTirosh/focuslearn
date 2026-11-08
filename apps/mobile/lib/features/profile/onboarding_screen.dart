import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../app/messages.dart';
import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import 'legal.dart';

/// First-run profile setup. Age-aware: anyone who could still be under 18 gets a private, undiscoverable profile
/// (the database enforces this too, whatever the app sends).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _year = TextEditingController();
  final TextEditingController _subjects = TextEditingController();
  String _stream = 'other';
  bool _accepted = false;
  bool _loading = false;
  String? _nameError;
  String? _yearError;
  String? _subjectsError;
  String? _acceptError;
  String? _failure;

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _subjects.dispose();
    super.dispose();
  }

  List<String> _parseSubjects() =>
      _subjects.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now().year;
    final name = validateDisplayName(_name.text);
    final year = int.tryParse(_year.text.trim());
    final yearCode = year == null ? 'invalid_format' : validateBirthYear(year, now);
    final subjects = _parseSubjects();
    final subjectsCode = validateSubjects(subjects);
    final streamCode = validateStream(_stream);
    setState(() {
      _nameError = name.ok ? null : validationMessage(l10n, name.code!);
      _yearError = yearCode == null ? null : validationMessage(l10n, yearCode);
      _subjectsError = subjectsCode == null ? null : validationMessage(l10n, subjectsCode);
      _acceptError = _accepted ? null : l10n.mustAcceptTerms;
      _failure = null;
    });
    if (!name.ok || yearCode != null || subjectsCode != null || streamCode != null || !_accepted || year == null) {
      return;
    }

    setState(() => _loading = true);
    final repo = ref.read(profileRepositoryProvider);
    final language = const <String>['en', 'si', 'ta'].contains(Localizations.localeOf(context).languageCode)
        ? Localizations.localeOf(context).languageCode
        : 'en';
    try {
      // Consent first, profile second: a profile can then never exist without a consent record.
      // A retry after a dropped connection adds duplicate consent events, which is harmless (the table is append-only).
      await repo.recordConsent(kind: 'terms', version: legalVersion, action: 'grant');
      await repo.recordConsent(kind: 'privacy', version: legalVersion, action: 'grant');
      await repo.createProfile(
        displayName: name.normalized,
        birthYear: year,
        stream: _stream,
        subjects: subjects,
        timeZone: defaultTimeZone,
      );
      try {
        await repo.ensurePreferences(language);
      } on Object {
        // Not critical: preferences are created again the first time the user changes one.
      }
      ref.invalidate(userPreferencesProvider);
      ref.invalidate(myProfileProvider);
    } on SocketException {
      if (mounted) {
        setState(() => _failure = l10n.authNetwork);
      }
    } on PostgrestException {
      if (mounted) {
        setState(() => _failure = l10n.errorGeneric);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final year = int.tryParse(_year.text.trim());
    final now = DateTime.now().year;
    final showMinorNotice = year != null && validateBirthYear(year, now) == null && isPossibleMinor(year, now);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.onboardingTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.onboardingIntro, style: text.bodyLarge),
                const SizedBox(height: Spacing.lg),
                if (_failure != null) ...<Widget>[
                  StatusBanner(kind: BannerKind.error, message: _failure!),
                  const SizedBox(height: Spacing.lg),
                ],
                AppTextField(
                  controller: _name,
                  label: l10n.displayNameLabel,
                  errorText: _nameError,
                  textInputAction: TextInputAction.next,
                  enabled: !_loading,
                ),
                const SizedBox(height: Spacing.lg),
                AppTextField(
                  controller: _year,
                  label: l10n.birthYearLabel,
                  errorText: _yearError,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  enabled: !_loading,
                ),
                if (showMinorNotice) ...<Widget>[
                  const SizedBox(height: Spacing.md),
                  StatusBanner(kind: BannerKind.info, message: l10n.minorNotice),
                ],
                const SizedBox(height: Spacing.lg),
                DropdownMenu<String>(
                  initialSelection: _stream,
                  label: Text(l10n.streamLabel),
                  expandedInsets: EdgeInsets.zero,
                  enabled: !_loading,
                  dropdownMenuEntries: <DropdownMenuEntry<String>>[
                    for (final s in ValidationRules.streams) DropdownMenuEntry<String>(value: s, label: streamName(l10n, s)),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      setState(() => _stream = value);
                    }
                  },
                ),
                const SizedBox(height: Spacing.lg),
                AppTextField(
                  controller: _subjects,
                  label: l10n.subjectsLabel,
                  errorText: _subjectsError,
                  textInputAction: TextInputAction.done,
                  enabled: !_loading,
                ),
                const SizedBox(height: Spacing.xs),
                Text(l10n.subjectsHelp, style: text.bodySmall),
                const SizedBox(height: Spacing.md),
                Text(l10n.timeZoneNote(defaultTimeZone), style: text.bodySmall),
                const SizedBox(height: Spacing.lg),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _accepted,
                  onChanged: _loading ? null : (value) => setState(() => _accepted = value ?? false),
                  title: Text(l10n.acceptTermsLabel),
                ),
                if (_acceptError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: Text(_acceptError!, style: text.bodySmall?.copyWith(color: context.colors.errorText)),
                  ),
                const SizedBox(height: Spacing.lg),
                AppButton(label: l10n.continueLabel, loading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
