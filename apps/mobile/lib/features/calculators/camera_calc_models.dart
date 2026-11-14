enum VerificationStatus { verified, mismatch, symbolic }

class DeterministicVerification {
  const DeterministicVerification({
    required this.status,
    required this.message,
    this.exactValue,
  });

  final VerificationStatus status;
  final String message;
  final String? exactValue;

  static const unverified = DeterministicVerification(
    status: VerificationStatus.symbolic,
    message: 'Symbolic or conceptual question; exact numeric evaluation not applicable.',
  );
}

class CameraProblemSolution {
  const CameraProblemSolution({
    required this.problemTitle,
    required this.problemUnderstood,
    this.canonicalExpression,
    required this.steps,
    required this.finalAnswer,
    this.formulaUsed,
    this.explanation,
    required this.verification,
  });

  final String problemTitle;
  final String problemUnderstood;
  final String? canonicalExpression;
  final List<String> steps;
  final String finalAnswer;
  final String? formulaUsed;
  final String? explanation;
  final DeterministicVerification verification;

  factory CameraProblemSolution.fromJson(
    Map<String, dynamic> json,
    DeterministicVerification verification,
  ) {
    final stepsList = <String>[];
    if (json['steps'] is List) {
      for (final s in (json['steps'] as List)) {
        stepsList.add(s.toString());
      }
    }

    return CameraProblemSolution(
      problemTitle: (json['problemTitle'] as String?) ?? 'A/L Problem',
      problemUnderstood: (json['problemUnderstood'] as String?) ?? '',
      canonicalExpression: json['canonicalExpression'] as String?,
      steps: stepsList,
      finalAnswer: (json['finalAnswer'] as String?) ?? '',
      formulaUsed: json['formulaUsed'] as String?,
      explanation: json['explanation'] as String?,
      verification: verification,
    );
  }
}
