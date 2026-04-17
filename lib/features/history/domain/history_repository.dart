import 'package:prepare_with_atlas/features/history/domain/problem_attempts.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';

/// Persistence contract for session history queries.
abstract class HistoryRepository {
  /// Returns a stream of ended sessions (completed only) with their latest
  /// evaluation score, sorted by start date descending.
  /// Abandoned and in-progress sessions are excluded.
  Stream<List<SessionSummary>> watchHistory();

  /// Returns a stream of ended sessions (completed only) grouped by problem,
  /// each group sorted by date ascending.
  /// Abandoned and in-progress sessions are excluded.
  Stream<List<ProblemAttempts>> watchHistoryByProblem();

  /// Returns all ended sessions (completed only) for [problemId], sorted by
  /// start date ascending. Abandoned and in-progress sessions are excluded.
  Future<List<SessionSummary>> getAttemptsForProblem(String problemId);

  /// Deletes the session identified by [sessionId].
  Future<void> deleteSession(int sessionId);
}
