import 'package:flutter/material.dart';

enum AppButtonKind { primary, secondary, text }

/// A button with a loading state. While loading it ignores taps and keeps its label for screen readers.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.kind = AppButtonKind.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final AppButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final scheme = Theme.of(context).colorScheme;
    final Widget child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kind == AppButtonKind.primary ? scheme.onPrimary : scheme.primary,
            ),
          )
        : Text(label);
    final VoidCallback? handler = enabled ? onPressed : null;

    final Widget button;
    switch (kind) {
      case AppButtonKind.primary:
        button = FilledButton(onPressed: handler, child: child);
      case AppButtonKind.secondary:
        button = OutlinedButton(onPressed: handler, child: child);
      case AppButtonKind.text:
        button = TextButton(onPressed: handler, child: child);
    }
    return Semantics(button: true, enabled: enabled, label: label, excludeSemantics: true, child: button);
  }
}
