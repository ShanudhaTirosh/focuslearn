import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focuslearn/features/calculators/scientific_calc_screen.dart';
import 'package:focuslearn/l10n/generated/app_localizations.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  testWidgets('ScientificCalcScreen renders tabs and keypad', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const ScientificCalcScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Expression & Trig'), findsOneWidget);
    expect(find.text('Equation Solver'), findsOneWidget);
    expect(find.text('Chemistry Mass'), findsOneWidget);
    expect(find.text('2D Graph'), findsOneWidget);

    // Keypad buttons
    expect(find.text('sin'), findsOneWidget);
    expect(find.text('cos'), findsOneWidget);
    expect(find.text('tan'), findsOneWidget);
    expect(find.text('DEL'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
  });

  testWidgets('ScientificCalcScreen calculates arithmetic and trig', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const ScientificCalcScreen()));
    await tester.pumpAndSettle();

    // Type sin(30) + 5
    await tester.tap(find.text('sin'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('0').last);
    await tester.pump();
    await tester.tap(find.text(')'));
    await tester.pump();
    await tester.tap(find.text('+'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();

    // Tap =
    await tester.tap(find.text('='));
    await tester.pumpAndSettle();

    // sin(30) is 0.5, so 0.5 + 5 = 5.5
    expect(find.text('5.5'), findsOneWidget);
  });

  testWidgets('ScientificCalcScreen solves quadratic equations', (tester) async {
    await tester.pumpWidget(_wrap(const ScientificCalcScreen()));
    await tester.pumpAndSettle();

    // Switch to Equation Solver tab
    await tester.tap(find.text('Equation Solver'));
    await tester.pumpAndSettle();

    // Tap Solve Quadratic button
    await tester.tap(find.text('Solve Quadratic (ax²+bx+c=0)'));
    await tester.pumpAndSettle();

    expect(find.text('Analytical Solution'), findsOneWidget);
    expect(find.textContaining('Standard Form'), findsOneWidget);
    expect(find.textContaining('Discriminant'), findsOneWidget);
  });
}
