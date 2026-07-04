import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/session_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';
import 'package:prepare_with_atlas/features/recording/application/audio_recorder_controller.dart';
import 'package:prepare_with_atlas/features/recording/application/audio_recorder_state.dart';

import 'session_controller_test.mocks.dart';

@GenerateMocks([SessionRepository])
void main() {
  late MockSessionRepository mockRepo;
  late ProviderContainer container;

  final baseSession = InterviewSession(
    id: 1,
    problemId: 42,
    mode: SessionMode.full,
    timerBehavior: TimerBehavior.softWarning,
    timerConfig: const TimerConfig(),
    startedAt: DateTime(2026, 4, 9),
  );

  setUp(() {
    mockRepo = MockSessionRepository();

    // Stub create to return baseSession with id=1
    when(
      mockRepo.create(any),
    ).thenAnswer((_) async => baseSession);

    // Stub update to do nothing
    when(mockRepo.update(any)).thenAnswer((_) async {});

    // Stub getStageNote to return null
    when(
      mockRepo.getStageNote(any, any),
    ).thenAnswer((_) async => null);

    // Stub saveStageNote
    when(mockRepo.saveStageNote(any)).thenAnswer(
      (inv) async => inv.positionalArguments.first as StageNote,
    );

    container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(mockRepo),
        // Use a fake audio recorder that stays idle (notesOnly mode in tests).
        audioRecorderProvider.overrideWith(
          () => _FakeAudioRecorderController(),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('SessionController', () {
    test('startFullSession sets currentSession and currentStage', () async {
      final notifier = container.read(sessionControllerProvider.notifier);
      await notifier.startFullSession(
        problemId: 42,
        behavior: TimerBehavior.softWarning,
        config: const TimerConfig(),
        recordingMode: RecordingMode.notesOnly,
      );
      final state = container.read(sessionControllerProvider);
      expect(state.currentSession, isNotNull);
      expect(
        state.currentStage,
        InterviewStage.requirementGathering,
      );
    });

    test('startSingleStageSession sets currentStage to chosen stage', () async {
      const chosenStage = InterviewStage.highLevelDesign;
      when(mockRepo.create(any)).thenAnswer(
        (_) async => baseSession.copyWith(
          mode: SessionMode.singleStage,
          focusStage: chosenStage,
        ),
      );
      final notifier = container.read(sessionControllerProvider.notifier);
      await notifier.startSingleStageSession(
        problemId: 42,
        stage: chosenStage,
        behavior: TimerBehavior.softWarning,
        config: const TimerConfig(),
        recordingMode: RecordingMode.notesOnly,
      );
      final state = container.read(sessionControllerProvider);
      expect(state.currentSession, isNotNull);
      expect(state.currentSession!.mode, SessionMode.singleStage);
      expect(state.currentStage, chosenStage);
    });

    test('startSingleStageSession passes focusStage to repository', () async {
      const chosenStage = InterviewStage.deepDive;
      when(mockRepo.create(any)).thenAnswer(
        (_) async => baseSession.copyWith(
          mode: SessionMode.singleStage,
          focusStage: chosenStage,
        ),
      );
      final notifier = container.read(sessionControllerProvider.notifier);
      await notifier.startSingleStageSession(
        problemId: 42,
        stage: chosenStage,
        behavior: TimerBehavior.softWarning,
        config: const TimerConfig(),
        recordingMode: RecordingMode.notesOnly,
      );
      final captured = verify(mockRepo.create(captureAny)).captured.first
          as InterviewSession;
      expect(captured.mode, SessionMode.singleStage);
      expect(captured.focusStage, chosenStage);
    });

    test('advanceToNextStage in full mode advances to next stage', () async {
      final notifier = container.read(sessionControllerProvider.notifier);
      await notifier.startFullSession(
        problemId: 42,
        behavior: TimerBehavior.softWarning,
        config: const TimerConfig(),
        recordingMode: RecordingMode.notesOnly,
      );
      await notifier.advanceToNextStage();
      final state = container.read(sessionControllerProvider);
      expect(
        state.currentStage,
        InterviewStage.backOfEnvelopeEstimation,
      );
    });

    test('advanceToNextStage in single-stage mode ends the session', () async {
      const chosenStage = InterviewStage.highLevelDesign;
      when(mockRepo.create(any)).thenAnswer(
        (_) async => baseSession.copyWith(
          mode: SessionMode.singleStage,
          focusStage: chosenStage,
        ),
      );
      when(mockRepo.update(any)).thenAnswer((_) async {});
      final notifier = container.read(sessionControllerProvider.notifier);
      await notifier.startSingleStageSession(
        problemId: 42,
        stage: chosenStage,
        behavior: TimerBehavior.softWarning,
        config: const TimerConfig(),
        recordingMode: RecordingMode.notesOnly,
      );
      await notifier.advanceToNextStage();
      final state = container.read(sessionControllerProvider);
      expect(state.currentSession!.status, SessionStatus.completed);
    });

    test('endSession sets status to completed', () async {
      final notifier = container.read(sessionControllerProvider.notifier);
      await notifier.startFullSession(
        problemId: 42,
        behavior: TimerBehavior.softWarning,
        config: const TimerConfig(),
        recordingMode: RecordingMode.notesOnly,
      );
      when(mockRepo.update(any)).thenAnswer((_) async {});
      await notifier.endSession();
      final state = container.read(sessionControllerProvider);
      expect(
        state.currentSession!.status,
        SessionStatus.completed,
      );
    });

    test('abandonSession sets status to abandoned', () async {
      final notifier = container.read(sessionControllerProvider.notifier);
      await notifier.startFullSession(
        problemId: 42,
        behavior: TimerBehavior.softWarning,
        config: const TimerConfig(),
        recordingMode: RecordingMode.notesOnly,
      );
      when(mockRepo.update(any)).thenAnswer((_) async {});
      await notifier.abandonSession();
      final state = container.read(sessionControllerProvider);
      expect(
        state.currentSession!.status,
        SessionStatus.abandoned,
      );
    });
  });
}

/// A fake [AudioRecorderController] that stays in idle state.
class _FakeAudioRecorderController
    extends AudioRecorderController {
  @override
  AudioRecorderState build() => const AudioRecorderState.idle();
}
