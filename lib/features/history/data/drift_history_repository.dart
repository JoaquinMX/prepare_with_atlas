import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart' as db_lib;
import 'package:prepare_with_atlas/features/history/domain/history_repository.dart';
import 'package:prepare_with_atlas/features/history/domain/problem_attempts.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

/// Drift-backed implementation of [HistoryRepository].
class DriftHistoryRepository implements HistoryRepository {
  /// Creates a [DriftHistoryRepository] backed by [_db].
  DriftHistoryRepository(this._db);

  final db_lib.AppDatabase _db;

  @override
  Stream<List<SessionSummary>> watchHistory() {
    // Join sessions with problems to get the problem title,
    // and left-join evaluations to get the latest overall score.
    // Only include sessions that are ended (completed), excluding
    // abandoned and in-progress sessions.
    final query =
        _db.select(_db.interviewSessions).join([
            innerJoin(
              _db.problems,
              _db.problems.id.equalsExp(_db.interviewSessions.problemId),
            ),
            leftOuterJoin(
              _db.evaluations,
              _db.evaluations.sessionId.equalsExp(_db.interviewSessions.id),
            ),
          ])
          ..where(_db.interviewSessions.status.equals('completed'))
          ..orderBy([OrderingTerm.desc(_db.interviewSessions.startedAt)]);

    return query.watch().map(_rowsToSummaries);
  }

  @override
  Stream<List<ProblemAttempts>> watchHistoryByProblem() {
    return watchHistory().map(_groupByProblem);
  }

  @override
  Future<List<SessionSummary>> getAttemptsForProblem(String problemId) async {
    final id = int.tryParse(problemId) ?? 0;
    final query =
        _db.select(_db.interviewSessions).join([
            innerJoin(
              _db.problems,
              _db.problems.id.equalsExp(_db.interviewSessions.problemId),
            ),
            leftOuterJoin(
              _db.evaluations,
              _db.evaluations.sessionId.equalsExp(_db.interviewSessions.id),
            ),
          ])
          ..where(
            _db.interviewSessions.problemId.equals(id) &
                _db.interviewSessions.status.equals('completed'),
          )
          ..orderBy([OrderingTerm.asc(_db.interviewSessions.startedAt)]);

    final rows = await query.get();
    return _rowsToSummaries(rows);
  }

  @override
  Future<void> deleteSession(int sessionId) async {
    await (_db.delete(
      _db.interviewSessions,
    )..where((t) => t.id.equals(sessionId))).go();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<SessionSummary> _rowsToSummaries(List<TypedResult> rows) {
    return rows.map((row) {
      final sessionRow = row.readTable(_db.interviewSessions);
      final problemRow = row.readTable(_db.problems);
      final evalRow = row.readTableOrNull(_db.evaluations);

      int? overallScore;
      if (evalRow != null) {
        final scorecard =
            jsonDecode(evalRow.scorecardJson) as Map<String, dynamic>;
        final raw = scorecard['overall'];
        overallScore = raw is int ? raw : (raw as num?)?.toInt();
      }

      return SessionSummary(
        session: _toSession(sessionRow),
        problemTitle: problemRow.title,
        overallScore: overallScore,
      );
    }).toList();
  }

  List<ProblemAttempts> _groupByProblem(List<SessionSummary> summaries) {
    // Build an insertion-ordered map of problemId → list of summaries
    // (already sorted asc per problem because watchHistory is desc overall;
    // we reverse within each group to get asc order).
    final grouped = <int, List<SessionSummary>>{};
    for (final s in summaries.reversed) {
      final id = s.session.problemId;
      grouped.putIfAbsent(id, () => []).add(s);
    }

    return grouped.entries.map((entry) {
      final attempts = entry.value; // sorted asc
      final scoredAttempts = attempts
          .where((a) => a.overallScore != null)
          .toList();
      return ProblemAttempts(
        problemId: entry.key.toString(),
        problemTitle: attempts.first.problemTitle,
        attempts: attempts,
        firstScore: scoredAttempts.isNotEmpty
            ? scoredAttempts.first.overallScore
            : null,
        latestScore: scoredAttempts.isNotEmpty
            ? scoredAttempts.last.overallScore
            : null,
      );
    }).toList();
  }

  InterviewSession _toSession(db_lib.InterviewSession row) => InterviewSession(
    id: row.id,
    problemId: row.problemId,
    mode: SessionMode.fromKey(row.mode),
    focusStage: row.focusStage != null
        ? InterviewStage.fromKey(row.focusStage!)
        : null,
    timerBehavior: TimerBehavior.fromKey(row.timerBehavior),
    timerConfig: TimerConfig.fromJson(
      jsonDecode(row.timerConfigJson) as Map<String, dynamic>,
    ),
    status: SessionStatus.fromKey(row.status),
    startedAt: row.startedAt,
    completedAt: row.completedAt,
  );
}
