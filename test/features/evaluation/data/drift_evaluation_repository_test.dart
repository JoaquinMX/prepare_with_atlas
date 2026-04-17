import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart'
    hide InterviewSession, StageNote;
import 'package:prepare_with_atlas/features/evaluation/data/drift_evaluation_repository.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/interview_session/data/drift_session_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

void main() {
  late AppDatabase db;
  late DriftEvaluationRepository repo;
  late int sessionId;

  final createdAt = DateTime(2026, 4, 9, 12);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftEvaluationRepository(db);

    // Insert a session row so the FK reference is valid
    final sessionRepo = DriftSessionRepository(db);
    final session = await sessionRepo.create(
      InterviewSession(
        id: 0,
        problemId: 1,
        mode: SessionMode.full,
        timerBehavior: TimerBehavior.softWarning,
        timerConfig: const TimerConfig(),
        startedAt: DateTime(2026, 4, 9),
      ),
    );
    sessionId = session.id;
  });

  tearDown(() async {
    await db.close();
  });

  EvaluationResult makeEvaluation({
    String id = 'eval-1',
    DateTime? at,
    String providerUsed = 'anthropic',
  }) =>
      EvaluationResult(
        id: id,
        sessionId: sessionId.toString(),
        scorecard: const {
          'requirementsGathering': 8,
          'estimationQuality': 6,
          'highLevelDesign': 7,
          'deepDiveQuality': 7,
          'scalingAwareness': 5,
          'communicationClarity': 8,
          'overall': 7,
        },
        overallScore: 7,
        strengths: const ['Clear requirements'],
        improvements: const ['More depth'],
        narrative: '## Overall\n\nSolid.',
        providerUsed: providerUsed,
        modelUsed: 'claude-3-5-sonnet',
        createdAt: at ?? createdAt,
      );

  group('DriftEvaluationRepository', () {
    test('save and getBySessionId round-trip', () async {
      final evaluation = makeEvaluation();
      await repo.save(evaluation);

      final found = await repo.getBySessionId(sessionId.toString());
      expect(found, isNotNull);
      expect(found!.id, 'eval-1');
      expect(found.sessionId, sessionId.toString());
      expect(found.overallScore, 7);
      expect(found.scorecard['requirementsGathering'], 8);
      expect(found.strengths, hasLength(1));
      expect(found.improvements, hasLength(1));
      expect(found.narrative, contains('Solid'));
    });

    test('getBySessionId returns null when not found', () async {
      final found = await repo.getBySessionId('999');
      expect(found, isNull);
    });

    test('getAll returns all evaluations', () async {
      await repo.save(makeEvaluation());
      await repo.save(makeEvaluation(id: 'eval-2'));

      final all = await repo.getAll();
      expect(all, hasLength(2));
    });

    test('delete removes the evaluation', () async {
      await repo.save(makeEvaluation());
      await repo.delete('eval-1');

      final found = await repo.getBySessionId(sessionId.toString());
      expect(found, isNull);
    });

    test('save overwrites existing evaluation for same id', () async {
      await repo.save(makeEvaluation());
      final updated = makeEvaluation().copyWith(overallScore: 9);
      await repo.save(updated);

      final found = await repo.getBySessionId(sessionId.toString());
      expect(found!.overallScore, 9);
    });

    test('getBySessionId returns the latest evaluation by createdAt', () async {
      await repo.save(
        makeEvaluation(id: 'older', at: DateTime(2026, 4, 1)),
      );
      await repo.save(
        makeEvaluation(
          id: 'newer',
          at: DateTime(2026, 4, 10),
          providerUsed: 'gemini',
        ),
      );

      final found = await repo.getBySessionId(sessionId.toString());
      expect(found, isNotNull);
      expect(found!.id, 'newer');
      expect(found.providerUsed, 'gemini');
    });

    test('getAllBySessionId returns all evaluations newest-first', () async {
      await repo.save(
        makeEvaluation(id: 'a', at: DateTime(2026, 4, 1)),
      );
      await repo.save(
        makeEvaluation(id: 'b', at: DateTime(2026, 4, 10)),
      );
      await repo.save(
        makeEvaluation(id: 'c', at: DateTime(2026, 4, 5)),
      );

      final all = await repo.getAllBySessionId(sessionId.toString());
      expect(all.map((e) => e.id).toList(), ['b', 'c', 'a']);
    });

    test('getAllBySessionId returns empty list when no evals', () async {
      final all = await repo.getAllBySessionId(sessionId.toString());
      expect(all, isEmpty);
    });
  });
}
