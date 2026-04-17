import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';

part 'problem_attempts.freezed.dart';

/// A grouped view of all attempts at a specific problem.
@freezed
abstract class ProblemAttempts with _$ProblemAttempts {
  /// Creates a [ProblemAttempts].
  const factory ProblemAttempts({
    /// ID of the problem.
    required String problemId,

    /// Title of the problem.
    required String problemTitle,

    /// All session summaries for this problem, sorted by date ascending.
    required List<SessionSummary> attempts,

    /// Overall score from the first attempt, or null if unavailable.
    int? firstScore,

    /// Overall score from the most recent attempt, or null if unavailable.
    int? latestScore,
  }) = _ProblemAttempts;
}

/// Extension providing trend analysis for [ProblemAttempts].
extension ProblemAttemptsTrend on ProblemAttempts {
  /// Returns 1 if improving, -1 if declining, 0 if flat or insufficient data.
  int get trend {
    if (firstScore == null || latestScore == null) return 0;
    if (latestScore! > firstScore!) return 1;
    if (latestScore! < firstScore!) return -1;
    return 0;
  }
}
