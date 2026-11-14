import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focuslearn/features/enforcement/enforcement_overlay_screen.dart';
import 'package:focuslearn/features/enforcement/enforcement_rules_screen.dart';
import 'package:focuslearn/l10n/generated/app_localizations.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('EnforcementRulesScreen renders permissions and rules sections', (tester) async {
    await tester.pumpWidget(_wrap(const EnforcementRulesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Focus Enforcement & Rules'), findsOneWidget);
    expect(find.text('Required Permissions'), findsOneWidget);
    expect(find.text('Active Rules'), findsOneWidget);
    expect(find.text('Violations & Interceptions'), findsOneWidget);
  });

  testWidgets('EnforcementOverlayScreen displays blocked app and time remaining', (tester) async {
    await tester.pumpWidget(_wrap(const EnforcementOverlayScreen(
      blockedPackage: 'com.instagram.android',
      remainingSeconds: 1500,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Focus Mode Active'), findsOneWidget);
    expect(find.text('com.instagram.android'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Emergency Override'), findsOneWidget);
  });
}
