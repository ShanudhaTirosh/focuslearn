import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focuslearn/features/focus/focus_timer_screen.dart';
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
  testWidgets('FocusTimerScreen displays duration choices and initial timer', (tester) async {
    await tester.pumpWidget(_wrap(const FocusTimerScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Focus Timer'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Start Focus'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('50 min'), findsOneWidget);
  });

  testWidgets('FocusTimerScreen changes duration on chip tap', (tester) async {
    await tester.pumpWidget(_wrap(const FocusTimerScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('50 min'));
    await tester.pumpAndSettle();

    expect(find.text('50:00'), findsOneWidget);
  });
}
