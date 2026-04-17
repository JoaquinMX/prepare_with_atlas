import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

void main() {
  final startedAt = DateTime(2026, 4, 9);

  final session = InterviewSession(
    id: 1,
    problemId: 42,
    mode: SessionMode.full,
    timerBehavior: TimerBehavior.softWarning,
    timerConfig: const TimerConfig(),
    startedAt: startedAt,
  );

  group('InterviewSession', () {
    test('creates with required fields', () {
      expect(session.id, 1);
      expect(session.problemId, 42);
      expect(session.mode, SessionMode.full);
      expect(session.status, SessionStatus.inProgress);
    });

    test('copyWith updates fields', () {
      final updated = session.copyWith(status: SessionStatus.completed);
      expect(updated.status, SessionStatus.completed);
      expect(updated.id, 1);
    });

    test('JSON round-trip preserves all fields', () {
      final json = session.toJson();
      final restored = InterviewSession.fromJson(json);
      expect(restored.id, session.id);
      expect(restored.problemId, session.problemId);
      expect(restored.mode, session.mode);
      expect(restored.status, session.status);
      expect(restored.timerBehavior, session.timerBehavior);
    });

    test('SessionMode keys are correct', () {
      expect(SessionMode.full.key, 'full');
      expect(SessionMode.singleStage.key, 'single_stage');
      expect(SessionMode.fromKey('full'), SessionMode.full);
      expect(SessionMode.fromKey('single_stage'), SessionMode.singleStage);
    });

    test('SessionStatus keys are correct', () {
      expect(SessionStatus.inProgress.key, 'in_progress');
      expect(SessionStatus.completed.key, 'completed');
      expect(SessionStatus.abandoned.key, 'abandoned');
    });
  });
}
