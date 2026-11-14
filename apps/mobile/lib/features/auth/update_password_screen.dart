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

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _done = false;
  String? _passwordError;
  String? _confirmError;
  String? _failure;

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = ref.read(authRepositoryProvider).currentUser?.email ?? '';
    final code = validatePassword(_password.text, email);
    final confirmMismatch = _password.text != _confirmPassword.text;

    setState(() {
      _passwordError = code == null ? null : validationMessage(l10n, code);
      _confirmError = confirmMismatch ? l10n.passwordMismatch : null;
      _failure = null;
      _done = false;
    });

    if (code != null || confirmMismatch) {
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (mounted) {
        setState(() => _done = true);
      }
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
      appBar: AppBar(title: Text(l10n.updatePasswordTitle)),
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
                  StatusBanner(kind: BannerKind.success, message: l10n.passwordUpdatedSuccess),
                  const SizedBox(height: Spacing.lg),
                  AppButton(
                    label: l10n.signIn,
                    onPressed: () => context.go(Routes.login),
                  ),
                ] else ...<Widget>[
                  Text(l10n.passwordHelp, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: Spacing.sm),
                  AppTextField(
                    controller: _password,
                    label: l10n.newPasswordLabel,
                    errorText: _passwordError,
                    obscureText: !_showPassword,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    suffix: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                      tooltip: _showPassword ? l10n.hidePassword : l10n.showPassword,
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    enabled: !_loading,
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    controller: _confirmPassword,
                    label: l10n.confirmPasswordLabel,
                    errorText: _confirmError,
                    obscureText: !_showPassword,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    enabled: !_loading,
                  ),
                  const SizedBox(height: Spacing.xl),
                  AppButton(
                    label: l10n.updatePasswordButton,
                    loading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
