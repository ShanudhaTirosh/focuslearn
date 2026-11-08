import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focuslearn/features/planner/timetable_screen.dart';
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
  testWidgets('TimetableScreen renders navigation and buttons', (tester) async {
    await tester.pumpWidget(_wrap(const TimetableScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Planner & Timetable'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
