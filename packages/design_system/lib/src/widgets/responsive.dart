import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// Centres content and caps its width, so a form is readable on a tablet or a desktop window as well as on a phone.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Sizes.maxContentWidth),
        child: Padding(padding: const EdgeInsets.all(Spacing.lg), child: child),
      ),
    );
  }
}
