import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart'
    hide InterviewSession, StageNote;
import 'package:prepare_with_atlas/features/evaluation/data/drift_evaluation_repository.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/history/data/drift_history_repository.dart';
import 'package:prepare_with_atlas/features/history/domain/problem_attempts.dart';
import 'package:prepare_with_atlas/features/interview_session/data/drift_session_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

void main() {
  late AppDatabase db;
  late DriftHistoryRepository historyRepo;
  late DriftSessionRepository sessionRepo;
  late DriftEvaluationRepository evalRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    historyRepo = DriftHistoryRepository(db);
    sessionRepo = DriftSessionRepository(db);
    evalRepo = DriftEvaluationRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<InterviewSession> makeSession({
    required int problemId,
    DateTime? startedAt,
    SessionStatus status = SessionStatus.completed,
  }) async {
    return sessionRepo.create(
      InterviewSession(
        id: 0,
        problemId: problemId,
        mode: SessionMode.full,
        timerBehavior: TimerBehavior.softWarning,
        timerConfig: const TimerConfig(),
        startedAt: startedAt ?? DateTime(2026, 4, 9),
        status: status,
      ),
    );
  }

  Future<void> insertProblem({required int id, required String title}) async {
    await db
        .into(db.problems)
        .insert(
          ProblemsCompanion.insert(
            id: Value(id),
            title: title,
            description: 'Test description',
            difficulty: 'medium',
            category: 'web',
          ),
        );
  }

  EvaluationResult makeEval(int sessionId, {int overall = 7}) =>
      EvaluationResult(
        id: 'eval-$sessionId',
        sessionId: sessionId.toString(),
        scorecard: {
          'requirementsGathering': 8,
          'estimationQuality': 6,
          'highLevelDesign': 7,
          'deepDiveQuality': 7,
          'scalingAwareness': 5,
          'communicationClarity': 8,
          'overall': overall,
        },
        overallScore: overall,
        strengths: const ['Good'],
        improvements: const ['More depth'],
        narrative: 'Solid.',
        providerUsed: 'anthropic',
        modelUsed: 'claude-3-5-sonnet',
        createdAt: DateTime(2026, 4, 9, 12),
      );

  // ── watchHistory ──────────────────────────────────────────────────────────

  group('watchHistory', () {
    test('emits empty list when no sessions exist', () async {
      final stream = historyRepo.watchHistory();
      final result = await stream.first;
      expect(result, isEmpty);
    });

    test('returns session summaries with problem title', () async {
      await insertProblem(id: 1, title: 'Design a URL Shortener');
      await makeSession(problemId: 1);

      final stream = historyRepo.watchHistory();
      final result = await stream.first;

      expect(result, hasLength(1));
      expect(result.first.problemTitle, 'Design a URL Shortener');
    });

    test('includes overall score when evaluation exists', () async {
      await insertProblem(id: 1, title: 'Design a CDN');
      final session = await makeSession(problemId: 1);
      await evalRepo.save(makeEval(session.id, overall: 8));

      final stream = historyRepo.watchHistory();
      final result = await stream.first;

      expect(result.first.overallScore, 8);
    });

    test('overallScore is null when no evaluation exists', () async {
      await insertProblem(id: 1, title: 'Design a CDN');
      await makeSession(problemId: 1);

      final stream = historyRepo.watchHistory();
      final result = await stream.first;

      expect(result.first.overallScore, isNull);
    });

    test('sessions are sorted by start date descending', () async {
      await insertProblem(id: 1, title: 'Problem A');
      await insertProblem(id: 2, title: 'Problem B');

      await makeSession(problemId: 1, startedAt: DateTime(2026, 4, 7));
      await makeSession(problemId: 2, startedAt: DateTime(2026, 4, 9));

      final stream = historyRepo.watchHistory();
      final result = await stream.first;

      expect(result.first.problemTitle, 'Problem B');
      expect(result.last.problemTitle, 'Problem A');
    });

    test('emits updated list after new session is added', () async {
      await insertProblem(id: 1, title: 'Design a Cache');

      final stream = historyRepo.watchHistory();
      final firstEmit = await stream.first;
      expect(firstEmit, isEmpty);

      await makeSession(problemId: 1);

      final secondEmit = await stream.first;
      expect(secondEmit, hasLength(1));
    });

    test('excludes abandoned sessions', () async {
      await insertProblem(id: 1, title: 'Problem A');

      await makeSession(problemId: 1);
      await makeSession(problemId: 1, status: SessionStatus.abandoned);

      final stream = historyRepo.watchHistory();
      final result = await stream.first;

      expect(result, hasLength(1));
    });

    test('excludes in-progress sessions', () async {
      await insertProblem(id: 1, title: 'Problem A');

      await makeSession(problemId: 1);
      await makeSession(problemId: 1, status: SessionStatus.inProgress);

      final stream = historyRepo.watchHistory();
      final result = await stream.first;

      expect(result, hasLength(1));
    });
  });

  // ── watchHistoryByProblem ─────────────────────────────────────────────────

  group('watchHistoryByProblem', () {
    test('emits empty list when no sessions exist', () async {
      final stream = historyRepo.watchHistoryByProblem();
      final result = await stream.first;
      expect(result, isEmpty);
    });

    test('groups sessions by problem', () async {
      await insertProblem(id: 1, title: 'Problem A');
      await insertProblem(id: 2, title: 'Problem B');

      await makeSession(problemId: 1);
      await makeSession(problemId: 1);
      await makeSession(problemId: 2);

      final stream = historyRepo.watchHistoryByProblem();
      final result = await stream.first;

      expect(result, hasLength(2));
      final groupA = result.firstWhere((g) => g.problemTitle == 'Problem A');
      expect(groupA.attempts, hasLength(2));
      final groupB = result.firstWhere((g) => g.problemTitle == 'Problem B');
      expect(groupB.attempts, hasLength(1));
    });

    test('sets firstScore and latestScore when evaluations exist', () async {
      await insertProblem(id: 1, title: 'Problem A');

      final s1 = await makeSession(
        problemId: 1,
        startedAt: DateTime(2026, 4, 7),
      );
      final s2 = await makeSession(
        problemId: 1,
        startedAt: DateTime(2026, 4, 9),
      );

      await evalRepo.save(makeEval(s1.id, overall: 5));
      await evalRepo.save(makeEval(s2.id, overall: 8));

      final stream = historyRepo.watchHistoryByProblem();
      final result = await stream.first;
      final group = result.first;

      expect(group.firstScore, 5);
      expect(group.latestScore, 8);
    });

    test('trend is 1 when score improved', () async {
      await insertProblem(id: 1, title: 'Problem A');

      final s1 = await makeSession(
        problemId: 1,
        startedAt: DateTime(2026, 4, 7),
      );
      final s2 = await makeSession(
        problemId: 1,
        startedAt: DateTime(2026, 4, 9),
      );

      await evalRepo.save(makeEval(s1.id, overall: 4));
      await evalRepo.save(makeEval(s2.id, overall: 9));

      final stream = historyRepo.watchHistoryByProblem();
      final result = await stream.first;
      expect(result.first.trend, 1);
    });

    test('trend is -1 when score declined', () async {
      await insertProblem(id: 1, title: 'Problem A');

      final s1 = await makeSession(
        problemId: 1,
        startedAt: DateTime(2026, 4, 7),
      );
      final s2 = await makeSession(
        problemId: 1,
        startedAt: DateTime(2026, 4, 9),
      );

      await evalRepo.save(makeEval(s1.id, overall: 9));
      await evalRepo.save(makeEval(s2.id, overall: 4));

      final stream = historyRepo.watchHistoryByProblem();
      final result = await stream.first;
      expect(result.first.trend, -1);
    });

    test('trend is 0 when insufficient data', () async {
      await insertProblem(id: 1, title: 'Problem A');
      await makeSession(problemId: 1);

      final stream = historyRepo.watchHistoryByProblem();
      final result = await stream.first;
      expect(result.first.trend, 0);
    });
  });

  // ── getAttemptsForProblem ──────────────────────────────────────────────────

  group('getAttemptsForProblem', () {
    test('returns empty list when no sessions for problem', () async {
      await insertProblem(id: 1, title: 'Problem A');
      final result = await historyRepo.getAttemptsForProblem('1');
      expect(result, isEmpty);
    });

    test('returns only sessions for the given problem', () async {
      await insertProblem(id: 1, title: 'Problem A');
      await insertProblem(id: 2, title: 'Problem B');

      await makeSession(problemId: 1);
      await makeSession(problemId: 2);

      final result = await historyRepo.getAttemptsForProblem('1');
      expect(result, hasLength(1));
      expect(result.first.problemTitle, 'Problem A');
    });

    test('results are sorted by start date ascending', () async {
      await insertProblem(id: 1, title: 'Problem A');

      await makeSession(problemId: 1, startedAt: DateTime(2026, 4, 9));
      await makeSession(problemId: 1, startedAt: DateTime(2026, 4, 7));

      final result = await historyRepo.getAttemptsForProblem('1');
      expect(result.first.session.startedAt, DateTime(2026, 4, 7));
      expect(result.last.session.startedAt, DateTime(2026, 4, 9));
    });

    test('excludes abandoned sessions', () async {
      await insertProblem(id: 1, title: 'Problem A');

      await makeSession(problemId: 1);
      await makeSession(problemId: 1, status: SessionStatus.abandoned);

      final result = await historyRepo.getAttemptsForProblem('1');
      expect(result, hasLength(1));
    });

    test('excludes in-progress sessions', () async {
      await insertProblem(id: 1, title: 'Problem A');

      await makeSession(problemId: 1);
      await makeSession(problemId: 1, status: SessionStatus.inProgress);

      final result = await historyRepo.getAttemptsForProblem('1');
      expect(result, hasLength(1));
    });
  });

  // ── deleteSession ─────────────────────────────────────────────────────────

  group('deleteSession', () {
    test('removes session from watch stream', () async {
      await insertProblem(id: 1, title: 'Design a Cache');
      final session = await makeSession(problemId: 1);

      await historyRepo.deleteSession(session.id);

      final stream = historyRepo.watchHistory();
      final result = await stream.first;
      expect(result, isEmpty);
    });
  });
}
