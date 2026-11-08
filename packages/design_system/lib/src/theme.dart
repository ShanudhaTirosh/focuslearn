import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// `context.colors.primary` and friends: the active theme's token colours (including the semantic text colours
/// such as `errorText` that Material's ColorScheme has no slot for).
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
}

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  // Sinhala and Tamil need fonts with those scripts. Android and Windows ship some, budget phones may not: verify on devices.
  static const List<String> _fontFallback = <String>[
    'Noto Sans Sinhala',
    'Noto Sans Tamil',
    'Nirmala UI',
    'Iskoola Pota',
  ];

  static TextStyle _style(TypeSpec t, Color color) => TextStyle(
        fontSize: t.size,
        height: t.height,
        fontWeight: FontWeight.values[(t.weight ~/ 100) - 1],
        color: color,
        fontFamilyFallback: _fontFallback,
      );

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.secondary,
      onSecondary: c.onSecondary,
      error: c.error,
      onError: c.onError,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      outline: c.borderStrong,
      outlineVariant: c.border,
    );

    final textTheme = TextTheme(
      displaySmall: _style(TypeScale.display, c.text),
      headlineSmall: _style(TypeScale.headline, c.text),
      titleLarge: _style(TypeScale.title, c.text),
      titleMedium: _style(TypeScale.label, c.text),
      bodyLarge: _style(TypeScale.bodyLarge, c.text),
      bodyMedium: _style(TypeScale.body, c.text),
      bodySmall: _style(TypeScale.caption, c.textMuted),
      labelLarge: _style(TypeScale.label, c.text),
    );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: c.borderStrong),
    );
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
    final minimum = Size(Sizes.minTouchTarget, Sizes.minTouchTarget);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      textTheme: textTheme,
      dividerColor: c.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.primary, width: 2)),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.error)),
        focusedErrorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.error, width: 2)),
        labelStyle: _style(TypeScale.body, c.textMuted),
        errorStyle: _style(TypeScale.caption, c.errorText),
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: minimum, shape: buttonShape, textStyle: _style(TypeScale.label, c.onPrimary)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minimum,
          shape: buttonShape,
          side: BorderSide(color: c.borderStrong),
          foregroundColor: c.text,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: minimum, shape: buttonShape, foregroundColor: c.primary),
      ),
    );
  }
}
