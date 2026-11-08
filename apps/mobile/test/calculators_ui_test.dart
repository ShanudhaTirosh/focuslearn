import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focuslearn/features/calculators/calculators_screen.dart';
import 'package:focuslearn/features/calculators/converter_screen.dart';
import 'package:focuslearn/features/calculators/formula_library_screen.dart';
import 'package:focuslearn/features/calculators/percentage_calc_screen.dart';
import 'package:focuslearn/features/calculators/standard_calc_screen.dart';
import 'package:focuslearn/l10n/generated/app_localizations.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
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
  testWidgets('CalculatorsScreen lists all study tools', (tester) async {
    await tester.pumpWidget(_wrap(const CalculatorsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Study Calculators'), findsOneWidget);
    expect(find.text('Standard & Fractions'), findsOneWidget);
    expect(find.text('Percentage'), findsOneWidget);
    expect(find.text('Commercial & Business'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Unit Converter'), findsOneWidget);
    expect(find.text('Formula Reference'), findsOneWidget);
  });

  testWidgets('StandardCalcScreen calculates expression and shows result', (tester) async {
    await tester.pumpWidget(_wrap(const StandardCalcScreen()));
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    expect(input, findsOneWidget);

    await tester.enterText(input, '15 + 25 * 2');
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();

    expect(find.text('65'), findsOneWidget);
  });

  testWidgets('PercentageCalcScreen calculates percent of base', (tester) async {
    await tester.pumpWidget(_wrap(const PercentageCalcScreen()));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    await tester.enterText(textFields.at(0), '15');
    await tester.enterText(textFields.at(1), '2400');
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();

    expect(find.text('360.00'), findsOneWidget);
  });

  testWidgets('ConverterScreen converts units', (tester) async {
    await tester.pumpWidget(_wrap(const ConverterScreen()));
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    await tester.enterText(input, '5');
    await tester.pumpAndSettle();

    expect(find.text('5 m = 0.005 km'), findsOneWidget);
  });

  testWidgets('FormulaLibraryScreen renders formulas', (tester) async {
    await tester.pumpWidget(_wrap(const FormulaLibraryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Accounting Equation'), findsOneWidget);
    expect(find.text('Newton\'s Second Law'), findsOneWidget);
    expect(find.text('Ohm\'s Law'), findsOneWidget);
  });
}
