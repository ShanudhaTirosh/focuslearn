import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focuslearn/features/notebooks/notebook_models.dart';
import 'package:focuslearn/features/notebooks/notebook_repository.dart';
import 'package:focuslearn/features/notebooks/notebooks_hub_screen.dart';
import 'package:focuslearn/l10n/generated/app_localizations.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

Widget _wrap(Widget child, {List<Notebook>? notebooks}) {
  return ProviderScope(
    overrides: [
      if (notebooks != null)
        myNotebooksProvider.overrideWith((ref) => Future.value(notebooks)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
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
  testWidgets('NotebooksHubScreen shows empty state when no notebooks', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const NotebooksHubScreen(), notebooks: []));
    await tester.pumpAndSettle();

    expect(find.text('No Research Notebooks Yet'), findsOneWidget);
    expect(find.text('Create First Notebook'), findsOneWidget);
  });

  testWidgets('NotebooksHubScreen lists student notebooks', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockNotebooks = [
      Notebook(
        id: 'nb-1',
        ownerId: 'u-1',
        title: 'Combined Maths Revision',
        description: 'Past papers and trigonometric proofs',
        color: '#4F46E5',
        createdAt: DateTime.now(),
      ),
      Notebook(
        id: 'nb-2',
        ownerId: 'u-1',
        title: 'Physics Mechanics Notes',
        description: 'Gravitation and circular motion',
        color: '#059669',
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(_wrap(const NotebooksHubScreen(), notebooks: mockNotebooks));
    await tester.pumpAndSettle();

    expect(find.text('Combined Maths Revision'), findsOneWidget);
    expect(find.text('Physics Mechanics Notes'), findsOneWidget);
    expect(find.text('New Notebook'), findsOneWidget);
  });
}
