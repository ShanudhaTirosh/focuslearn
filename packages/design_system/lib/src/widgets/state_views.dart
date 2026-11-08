import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.g.dart';
import 'app_button.dart';
import 'status_banner.dart';

/// Every key screen needs these states: loading, empty, error (and offline, via [OfflineBanner]).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, required this.label});

  /// Spoken by screen readers (for example "Loading your profile").
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(child: Semantics(label: label, liveRegion: true, child: const CircularProgressIndicator()));
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.message, this.icon = Icons.inbox_outlined});

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: Sizes.iconLg, color: c.textMuted),
            const SizedBox(height: Spacing.md),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              Text(message!, style: text.bodyMedium?.copyWith(color: c.textMuted), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.retryLabel, required this.onRetry});

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StatusBanner(kind: BannerKind.error, message: message),
            const SizedBox(height: Spacing.lg),
            AppButton(label: retryLabel, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

/// Shown when the device is offline or the server cannot be reached.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => StatusBanner(kind: BannerKind.warning, message: message);
}
