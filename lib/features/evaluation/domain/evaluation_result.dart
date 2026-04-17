import 'package:freezed_annotation/freezed_annotation.dart';

part 'evaluation_result.freezed.dart';
part 'evaluation_result.g.dart';

/// The seven dimensions used to score a system design interview.
///
/// These keys must appear in the [EvaluationResult.scorecard] map.
const List<String> scorecardDimensions = [
  'requirementsGathering',
  'estimationQuality',
  'highLevelDesign',
  'deepDiveQuality',
  'scalingAwareness',
  'communicationClarity',
  'overall',
];

/// Immutable result of an AI-powered evaluation of an interview session.
@freezed
abstract class EvaluationResult with _$EvaluationResult {
  /// Creates an [EvaluationResult].
  const factory EvaluationResult({
    /// Unique identifier for this evaluation.
    required String id,

    /// ID of the interview session that was evaluated.
    required String sessionId,

    /// Dimension scores keyed by dimension name (0-10 each).
    required Map<String, int> scorecard,

    /// Aggregate score for the entire session (0-10).
    required int overallScore,

    /// Things the candidate did well.
    required List<String> strengths,

    /// Areas for improvement.
    required List<String> improvements,

    /// Full markdown narrative from the AI evaluator.
    required String narrative,

    /// The AI provider used to generate this evaluation.
    required String providerUsed,

    /// The model identifier used to generate this evaluation.
    required String modelUsed,

    /// When this evaluation was created.
    required DateTime createdAt,

    /// Comparison to the reference solution (curated problems only).
    String? referenceComparison,

    /// Raw JSON response from the AI provider, stored for debugging.
    String? rawResponse,
  }) = _EvaluationResult;

  /// Deserialises an [EvaluationResult] from [json].
  factory EvaluationResult.fromJson(Map<String, dynamic> json) =>
      _$EvaluationResultFromJson(json);
}
