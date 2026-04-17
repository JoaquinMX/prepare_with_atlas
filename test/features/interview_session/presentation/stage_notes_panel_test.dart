import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/application/dictation_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/dictation_state.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_state.dart';
import 'package:prepare_with_atlas/features/interview_session/application/stage_timer_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/timer_state.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/session_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';
import 'package:prepare_with_atlas/features/interview_session/presentation/stage_notes_panel.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_repository_provider.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem_repository.dart';

class _FakeDictationController extends DictationController {
  @override
  DictationState build() => const DictationState.idle();

  @override
  Future<void> cancelListening() async {}

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> toggleListening() async {}

  @override
  Future<void> reset() async {}
}

class _FakeSessionController extends SessionController {
  @override
  SessionState build() => SessionState(
    currentSession: InterviewSession(
      id: 1,
      problemId: 1,
      mode: SessionMode.full,
      timerBehavior: TimerBehavior.softWarning,
      timerConfig: const TimerConfig(),
      startedAt: DateTime(2026, 4, 9),
    ),
    currentStage: InterviewStage.requirementGathering,
  );

  @override
  Future<void> endSession() async {}

  @override
  Future<void> abandonSession() async {}
}

class _FakeTimerController extends StageTimerController {
  @override
  TimerState build() => const TimerState.running(
    stage: InterviewStage.requirementGathering,
    remainingSeconds: 420,
    totalSeconds: 420,
  );
}

class _FakeRepo extends Fake implements SessionRepository {}

class _FakeProblemRepo implements ProblemRepository {
  @override
  Future<Problem?> getById(int id) async => null;
  @override
  Future<List<Problem>> getByExperienceLevel(ExperienceLevel level) =>
      Future.value([]);
  @override
  Future<List<Problem>> searchByTitle(String query) => Future.value([]);
  @override
  Future<int> insert(Problem problem) async => 0;
  @override
  Future<void> delete(int id) async {}
  @override
  Stream<List<Problem>> watchAll() => const Stream.empty();
  @override
  Future<int> count() async => 0;
}

void main() {
  group('StageNotesPanel', () {
    Widget buildSubject() => ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(_FakeRepo()),
        problemRepositoryProvider.overrideWithValue(_FakeProblemRepo()),
        sessionControllerProvider.overrideWith(_FakeSessionController.new),
        stageTimerControllerProvider.overrideWith(_FakeTimerController.new),
        dictationControllerProvider.overrideWith(_FakeDictationController.new),
      ],
      child: const MaterialApp(home: Scaffold(body: StageNotesPanel())),
    );

    testWidgets('renders STAGE NOTES label', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('STAGE NOTES'), findsOneWidget);
    });

    testWidgets('renders mic button for dictation', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.mic_outlined), findsOneWidget);
    });

    testWidgets('renders text field with hint', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Type or dictate your notes here…'), findsOneWidget);
    });

    testWidgets('does not render Fn Fn dictation hint', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Fn Fn to dictate'), findsNothing);
    });
  });

  group('DictationController state transitions', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('initial state is idle', () {
      final state = container.read(dictationControllerProvider);
      expect(state, isA<DictationIdle>());
    });

    test('reset transitions to idle', () async {
      final notifier = container.read(dictationControllerProvider.notifier);
      await notifier.reset();
      expect(container.read(dictationControllerProvider), isA<DictationIdle>());
    });
  });
}
