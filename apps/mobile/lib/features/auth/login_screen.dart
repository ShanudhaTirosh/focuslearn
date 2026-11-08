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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _emailError;
  String? _passwordError;
  String? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = validateEmail(_email.text);
    final passwordMissing = _password.text.isEmpty;
    setState(() {
      _emailError = email.ok ? null : validationMessage(l10n, email.code!);
      _passwordError = passwordMissing ? l10n.errorBlank : null;
      _failure = null;
    });
    if (!email.ok || passwordMissing) {
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await ref.read(captchaProvider).token();
      await ref.read(authRepositoryProvider).signIn(email: email.normalized, password: _password.text, captchaToken: token);
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _failure = e.kind);
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
      appBar: AppBar(title: Text(l10n.signIn)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_failure != null) ...<Widget>[
                    StatusBanner(kind: BannerKind.error, message: authMessage(l10n, _failure!)),
                    const SizedBox(height: Spacing.lg),
                  ],
                  AppTextField(
                    controller: _email,
                    label: l10n.emailLabel,
                    errorText: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.username, AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    enabled: !_loading,
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    controller: _password,
                    label: l10n.passwordLabel,
                    errorText: _passwordError,
                    obscureText: !_showPassword,
                    autofillHints: const <String>[AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    enabled: !_loading,
                    suffix: IconButton(
                      tooltip: _showPassword ? l10n.hidePassword : l10n.showPassword,
                      icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),
                  AppButton(label: l10n.signIn, loading: _loading, onPressed: _submit),
                  if (_failure == 'email_not_confirmed')
                    AppButton(
                      label: l10n.resendEmail,
                      kind: AppButtonKind.secondary,
                      onPressed: () => context.go(Routes.verify, extra: _email.text.trim()),
                    ),
                  const SizedBox(height: Spacing.md),
                  AppButton(label: l10n.forgotPassword, kind: AppButtonKind.text, onPressed: () => context.go(Routes.reset)),
                  AppButton(label: l10n.noAccountYet, kind: AppButtonKind.text, onPressed: () => context.go(Routes.signup)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
