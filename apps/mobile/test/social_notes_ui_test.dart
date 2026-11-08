import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focuslearn/features/notes/notes_screen.dart';
import 'package:focuslearn/features/social/social_screen.dart';
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
  testWidgets('NotesScreen renders search and notes list', (tester) async {
    await tester.pumpWidget(_wrap(const NotesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Study Notes'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('SocialScreen renders study groups and switch to friends', (tester) async {
    await tester.pumpWidget(_wrap(const SocialScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Study Groups & Friends'), findsOneWidget);
    expect(find.text('Combined Maths 2026'), findsOneWidget);
    expect(find.text('Physics Mechanics Study Circle'), findsOneWidget);

    // Switch to friends
    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();

    expect(find.text('Kasun Perera'), findsOneWidget);
    expect(find.text('Dilini Fernando'), findsOneWidget);
  });
}

