import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focuslearn/features/calculators/camera_calc_models.dart';
import 'package:focuslearn/features/calculators/camera_calc_repository.dart';
import 'package:focuslearn/features/calculators/camera_calc_screen.dart';
import 'package:focuslearn/l10n/generated/app_localizations.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

class FakeCameraCalcRepository implements CameraCalcRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<CameraProblemSolution> solveProblem({
    String? imageBase64,
    String? mimeType,
    String? problemText,
    String language = 'en',
    String action = 'solve',
  }) async {
    return const CameraProblemSolution(
      problemTitle: 'Projectile Motion',
      problemUnderstood: 'Ball dropped from height h = 50m. Calculate time t.',
      canonicalExpression: 'sqrt(2 * 50 / 9.8)',
      steps: [
        'Formula: s = ut + 1/2gt²',
        'Initial velocity u = 0, so 50 = 1/2(9.8)t²',
        't = √(100 / 9.8) ≈ 3.19 s',
      ],
      finalAnswer: '3.19 s',
      formulaUsed: 's = ut + ½gt²',
      explanation: 'Constant acceleration under gravity.',
      verification: DeterministicVerification(
        status: VerificationStatus.verified,
        exactValue: '3.19438',
        message: 'Verified by Focus Learn Exact Math Engine: Numeric calculation matches analytical evaluation.',
      ),
    );
  }
}

Widget _wrap(Widget child, {CameraCalcRepository? mockRepo}) {
  return ProviderScope(
    overrides: [
      if (mockRepo != null) cameraCalcRepositoryProvider.overrideWithValue(mockRepo),
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
  testWidgets('CameraCalcScreen renders capture buttons and input', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const CameraCalcScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Solve Problem'), findsOneWidget);
  });

  testWidgets('CameraCalcScreen displays verified solution and steps', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockRepo = FakeCameraCalcRepository();
    await tester.pumpWidget(_wrap(const CameraCalcScreen(), mockRepo: mockRepo));
    await tester.pumpAndSettle();

    // Enter a question
    await tester.enterText(find.byType(TextField), 'Ball dropped from 50m');
    await tester.tap(find.text('Solve Problem'));
    await tester.pumpAndSettle();

    expect(find.text('Projectile Motion'), findsOneWidget);
    expect(find.text('Deterministic Verification Passed'), findsOneWidget);
    expect(find.text('3.19 s'), findsOneWidget);
    expect(find.text('Explain Differently'), findsOneWidget);
    expect(find.text('Similar Practice Question'), findsOneWidget);
  });
}
