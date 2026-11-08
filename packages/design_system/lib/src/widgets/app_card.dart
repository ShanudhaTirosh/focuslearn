import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.g.dart';

/// A rounded surface with a faint border and no shadow (a restrained look that is cheap to draw on low-end devices).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(Spacing.lg)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
