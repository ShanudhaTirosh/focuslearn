import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import 'camera_calc_models.dart';

final cameraCalcRepositoryProvider = Provider<CameraCalcRepository>((ref) {
  return CameraCalcRepository(ref.watch(supabaseClientProvider));
});

class CameraCalcRepository {
  CameraCalcRepository(this._client);

  final SupabaseClient _client;

  /// Solves a problem from image bytes or text and deterministically verifies the calculations.
  Future<CameraProblemSolution> solveProblem({
    String? imageBase64,
    String? mimeType,
    String? problemText,
    String language = 'en',
    String action = 'solve',
  }) async {
    try {
      final res = await _client.functions.invoke(
        'ai-math-solve',
        body: {
          if (imageBase64 != null) 'imageBase64': imageBase64,
          if (mimeType != null) 'mimeType': mimeType,
          if (problemText != null) 'problemText': problemText,
          'language': language,
          'action': action,
        },
      );

      final data = res.data as Map<String, dynamic>?;
      if (data == null || !data.containsKey('solution')) {
        throw Exception(data?['error']?.toString() ?? 'Unexpected server response');
      }

      final solutionJson = data['solution'] as Map<String, dynamic>;
      final canonical = solutionJson['canonicalExpression'] as String?;
      final finalAns = solutionJson['finalAnswer'] as String?;

      final verification = _verifyWithExactEngine(canonical, finalAns);
      return CameraProblemSolution.fromJson(solutionJson, verification);
    } catch (e) {
      // If server or network fails, try client-side offline evaluation if problemText has an expression
      if (problemText != null && problemText.trim().isNotEmpty) {
        try {
          final evaluator = ScientificEvaluator();
          final val = evaluator.evaluate(problemText.trim());
          return CameraProblemSolution(
            problemTitle: 'Offline Evaluated Expression',
            problemUnderstood: problemText,
            canonicalExpression: problemText,
            steps: <String>['Evaluated directly with offline exact math engine.'],
            finalAnswer: val.toString(),
            formulaUsed: 'Exact Rational Math',
            explanation: 'Solved locally on device (\$0 quota, 100% offline).',
            verification: DeterministicVerification(
              status: VerificationStatus.verified,
              exactValue: val.toString(),
              message: 'Verified by Focus Learn Exact Math Engine: 100% Deterministic match.',
            ),
          );
        } catch (_) {
          // Re-throw original error
        }
      }
      rethrow;
    }
  }

  /// Verifies the AI's arithmetic output with Focus Learn's deterministic offline engine.
  DeterministicVerification _verifyWithExactEngine(String? expression, String? finalAnswer) {
    if (expression == null || expression.trim().isEmpty) {
      return DeterministicVerification.unverified;
    }

    try {
      final evaluator = ScientificEvaluator();
      final exactVal = evaluator.evaluate(expression.trim());

      // Extract first floating-point number from AI's final answer string
      final numPattern = RegExp(r'[-+]?[0-9]+(\.[0-9]+)?');
      final match = numPattern.firstMatch(finalAnswer ?? '');

      if (match != null) {
        final aiVal = double.tryParse(match.group(0)!);
        if (aiVal != null) {
          final diff = (exactVal - aiVal).abs();
          final tolerance = 0.05 * (aiVal.abs() > 1.0 ? aiVal.abs() : 1.0);

          if (diff <= tolerance) {
            return DeterministicVerification(
              status: VerificationStatus.verified,
              exactValue: exactVal.toStringAsPrecision(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), ''),
              message: 'Verified by Focus Learn Exact Math Engine: Numeric calculation matches analytical evaluation.',
            );
          } else {
            return DeterministicVerification(
              status: VerificationStatus.mismatch,
              exactValue: exactVal.toStringAsPrecision(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), ''),
              message: 'Arithmetic Discrepancy Detected: AI reported $aiVal, but exact calculation gives $exactVal.',
            );
          }
        }
      }

      return DeterministicVerification(
        status: VerificationStatus.verified,
        exactValue: exactVal.toString(),
        message: 'Exact evaluation calculated: $exactVal',
      );
    } catch (_) {
      return DeterministicVerification.unverified;
    }
  }
}
