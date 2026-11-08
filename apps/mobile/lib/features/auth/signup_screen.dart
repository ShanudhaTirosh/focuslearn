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

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
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
    final router = GoRouter.of(context);
    final email = validateEmail(_email.text);
    final passwordCode = validatePassword(_password.text, email.normalized);
    setState(() {
      _emailError = email.ok ? null : validationMessage(l10n, email.code!);
      _passwordError = passwordCode == null ? null : validationMessage(l10n, passwordCode);
      _failure = null;
    });
    if (!email.ok || passwordCode != null) {
      return;
    }
    setState(() => _loading = true);
    var proceed = false;
    try {
      final token = await ref.read(captchaProvider).token();
      await ref.read(authRepositoryProvider).signUp(email: email.normalized, password: _password.text, captchaToken: token);
      proceed = true;
    } on AuthFailure catch (e) {
      // "Already registered" must look exactly like success, so the form cannot be used to find out who has an account.
      if (e.kind == 'email_taken') {
        proceed = true;
      } else if (mounted) {
        setState(() => _failure = e.kind);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
    if (proceed) {
      router.go(Routes.verify, extra: email.normalized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createAccount)),
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
                    autofillHints: const <String>[AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    enabled: !_loading,
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    controller: _password,
                    label: l10n.passwordLabel,
                    errorText: _passwordError,
                    obscureText: !_showPassword,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    enabled: !_loading,
                    suffix: IconButton(
                      tooltip: _showPassword ? l10n.hidePassword : l10n.showPassword,
                      icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(l10n.passwordHelp, style: text.bodySmall),
                  const SizedBox(height: Spacing.lg),
                  Text(l10n.signupTermsNote, style: text.bodySmall),
                  const SizedBox(height: Spacing.xl),
                  AppButton(label: l10n.signUp, loading: _loading, onPressed: _submit),
                  const SizedBox(height: Spacing.md),
                  AppButton(label: l10n.haveAccount, kind: AppButtonKind.text, onPressed: () => context.go(Routes.login)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
