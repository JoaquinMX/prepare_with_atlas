import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart'
    hide InterviewSession, StageNote;
import 'package:prepare_with_atlas/features/interview_session/data/drift_session_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

void main() {
  late AppDatabase db;
  late DriftSessionRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftSessionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  InterviewSession makeSession() => InterviewSession(
        id: 0,
        problemId: 1,
        mode: SessionMode.full,
        timerBehavior: TimerBehavior.softWarning,
        timerConfig: const TimerConfig(),
        startedAt: DateTime(2026, 4, 9),
      );

  group('DriftSessionRepository', () {
    test('create returns session with non-zero id', () async {
      final created = await repo.create(makeSession());
      expect(created.id, isNonZero);
    });

    test('getById returns created session', () async {
      final created = await repo.create(makeSession());
      final found = await repo.getById(created.id);
      expect(found, isNotNull);
      expect(found!.id, created.id);
      expect(found.problemId, 1);
    });

    test('update with new status is persisted', () async {
      final created = await repo.create(makeSession());
      final updated = created.copyWith(status: SessionStatus.completed);
      await repo.update(updated);
      final found = await repo.getById(created.id);
      expect(found!.status, SessionStatus.completed);
    });

    test('saveStageNote and getStageNote returns it', () async {
      final session = await repo.create(makeSession());
      final note = StageNote(
        id: 0,
        sessionId: session.id,
        stage: InterviewStage.highLevelDesign,
        notes: 'Test notes',
        timerDurationSeconds: 720,
        updatedAt: DateTime(2026, 4, 9),
      );
      final saved = await repo.saveStageNote(note);
      expect(saved.id, isNonZero);

      final found = await repo.getStageNote(
        session.id,
        InterviewStage.highLevelDesign,
      );
      expect(found, isNotNull);
      expect(found!.notes, 'Test notes');
    });

    test('second saveStageNote for same session+stage is upsert', () async {
      final session = await repo.create(makeSession());
      final note = StageNote(
        id: 0,
        sessionId: session.id,
        stage: InterviewStage.deepDive,
        notes: 'First',
        timerDurationSeconds: 1020,
        updatedAt: DateTime(2026, 4, 9),
      );
      await repo.saveStageNote(note);
      await repo.saveStageNote(note.copyWith(notes: 'Second'));

      final all = await repo.getStageNotes(session.id);
      expect(all.length, 1);
      expect(all.first.notes, 'Second');
    });

    test('delete removes session and getById returns null', () async {
      final created = await repo.create(makeSession());
      await repo.delete(created.id);
      final found = await repo.getById(created.id);
      expect(found, isNull);
    });
  });
}
