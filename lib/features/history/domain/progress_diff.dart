import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';

part 'progress_diff.freezed.dart';

/// Score difference between two evaluations.
@freezed
abstract class ProgressDiff with _$ProgressDiff {
  /// Creates a [ProgressDiff].
  const factory ProgressDiff({
    /// Per-dimension score deltas: positive = improvement, negative = decline,
    /// null = dimension was absent in the prior evaluation (N/A).
    required Map<String, int?> scorecardDeltas,

    /// Overall score delta; null when either evaluation lacks an overall score.
    required int? overallDelta,

    /// The earlier evaluation used as the baseline.
    required EvaluationResult priorEvaluation,

    /// The more recent evaluation being compared.
    required EvaluationResult currentEvaluation,
  }) = _ProgressDiff;

  const ProgressDiff._();

  /// Computes a [ProgressDiff] between [prior] (baseline) and [current].
  ///
  /// For each dimension present in [current], the delta is
  /// `current - prior`. If the dimension was absent in [prior] the delta
  /// is null (N/A).
  factory ProgressDiff.from(
    EvaluationResult prior,
    EvaluationResult current,
  ) {
    final deltas = <String, int?>{};
    for (final entry in current.scorecard.entries) {
      final priorScore = prior.scorecard[entry.key];
      deltas[entry.key] =
          priorScore == null ? null : entry.value - priorScore;
    }

    final overallDelta = current.scorecard['overall'] != null &&
            prior.scorecard['overall'] != null
        ? current.scorecard['overall']! - prior.scorecard['overall']!
        : null;

    return ProgressDiff(
      scorecardDeltas: Map.unmodifiable(deltas),
      overallDelta: overallDelta,
      priorEvaluation: prior,
      currentEvaluation: current,
    );
  }

  /// Number of dimensions where the score improved (delta > 0).
  int get improvedDimensions =>
      scorecardDeltas.values.where((d) => d != null && d > 0).length;

  /// Number of dimensions where the score declined (delta < 0).
  int get declinedDimensions =>
      scorecardDeltas.values.where((d) => d != null && d < 0).length;
}
