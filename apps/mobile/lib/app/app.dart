import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../l10n/generated/app_localizations.dart';
import 'messages.dart';
import 'providers.dart';
import 'router.dart';

ThemeMode _themeMode(String? theme) => switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

class FocusLearnApp extends ConsumerWidget {
  const FocusLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final prefs = ref.watch(userPreferencesProvider).valueOrNull;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode(prefs?.theme),
      locale: prefs == null ? null : Locale(prefs.language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

/// Shown instead of the app when the build settings are unusable (for example a secret key was compiled in).
class MisconfiguredApp extends StatelessWidget {
  const MisconfiguredApp({super.key, required this.problem});

  final String problem;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: ContentWidth(child: StatusBanner(kind: BannerKind.error, message: configMessage(AppLocalizations.of(context), problem))),
          ),
        ),
      ),
    );
  }
}
