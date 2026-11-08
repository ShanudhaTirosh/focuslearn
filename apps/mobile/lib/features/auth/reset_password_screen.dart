import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';
import 'package:go_router/go_router.dart';

import '../../app/messages.dart';
import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../l10n/generated/app_localizations.dart';
import 'auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  /// Failures worth telling the user about. Anything else is shown as the same generic success, so the form
  /// cannot be used to discover which addresses have an account.
  static const Set<String> _visibleFailures = <String>{'network', 'rate_limited', 'server', 'captcha_failed'};

  final TextEditingController _email = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _emailError;
  String? _failure;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = validateEmail(_email.text);
    setState(() {
      _emailError = email.ok ? null : validationMessage(l10n, email.code!);
      _failure = null;
      _done = false;
    });
    if (!email.ok) {
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await ref.read(captchaProvider).token();
      await ref.read(authRepositoryProvider).requestPasswordReset(email.normalized, captchaToken: token);
      if (mounted) {
        setState(() => _done = true);
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          if (_visibleFailures.contains(e.kind)) {
            _failure = e.kind;
          } else {
            _done = true;
          }
        });
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPasswordTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_failure != null) ...<Widget>[
                  StatusBanner(kind: BannerKind.error, message: authMessage(l10n, _failure!)),
                  const SizedBox(height: Spacing.lg),
                ],
                if (_done) ...<Widget>[
                  StatusBanner(kind: BannerKind.success, message: l10n.resetEmailSentGeneric),
                  const SizedBox(height: Spacing.lg),
                ],
                AppTextField(
                  controller: _email,
                  label: l10n.emailLabel,
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  enabled: !_loading,
                ),
                const SizedBox(height: Spacing.xl),
                AppButton(label: l10n.sendResetLink, loading: _loading, onPressed: _submit),
                const SizedBox(height: Spacing.md),
                AppButton(label: l10n.backToSignIn, kind: AppButtonKind.text, onPressed: () => context.go(Routes.login)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
