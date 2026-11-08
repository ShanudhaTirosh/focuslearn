import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.g.dart';

enum BannerKind { info, success, warning, error }

/// A message with an icon AND text, so meaning never depends on colour alone. Announced politely to screen readers.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.kind, required this.message});

  final BannerKind kind;
  final String message;

  IconData get _icon => switch (kind) {
        BannerKind.info => Icons.info_outline,
        BannerKind.success => Icons.check_circle_outline,
        BannerKind.warning => Icons.warning_amber_outlined,
        BannerKind.error => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color textColor = switch (kind) {
      BannerKind.info => c.infoText,
      BannerKind.success => c.successText,
      BannerKind.warning => c.warningText,
      BannerKind.error => c.errorText,
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(_icon, color: textColor, size: Sizes.iconMd),
              const SizedBox(width: Spacing.md),
              Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor))),
            ],
          ),
        ),
      ),
    );
  }
}
