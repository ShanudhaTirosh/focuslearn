import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';
import 'package:go_router/go_router.dart';

import '../../app/messages.dart';
import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../l10n/generated/app_localizations.dart';
import 'auth_repository.dart';

/// Shown after sign-up. The wording is the same whether or not the address already has an account.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const int _cooldownSeconds = 60;

  Timer? _timer;
  int _secondsLeft = _cooldownSeconds;
  bool _sending = false;
  bool _sent = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _failure = null;
      _sent = false;
    });
    try {
      final token = await ref.read(captchaProvider).token();
      await ref.read(authRepositoryProvider).resendConfirmation(widget.email, captchaToken: token);
      if (mounted) {
        setState(() => _sent = true);
        _startCooldown();
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _failure = e.kind);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final canResend = widget.email.isNotEmpty && _secondsLeft == 0 && !_sending;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkInboxTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.checkInboxBody, style: text.bodyLarge),
                const SizedBox(height: Spacing.lg),
                if (_failure != null) ...<Widget>[
                  StatusBanner(kind: BannerKind.error, message: authMessage(l10n, _failure!)),
                  const SizedBox(height: Spacing.lg),
                ],
                if (_sent) ...<Widget>[
                  StatusBanner(kind: BannerKind.success, message: l10n.doneMessage),
                  const SizedBox(height: Spacing.lg),
                ],
                AppButton(
                  label: _secondsLeft > 0 ? l10n.resendIn(_secondsLeft.toString()) : l10n.resendEmail,
                  kind: AppButtonKind.secondary,
                  loading: _sending,
                  onPressed: canResend ? _resend : null,
                ),
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
