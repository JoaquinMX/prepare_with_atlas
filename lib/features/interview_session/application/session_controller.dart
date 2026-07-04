import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_state.dart';
import 'package:prepare_with_atlas/features/interview_session/application/timer_state.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/session_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';
import 'package:prepare_with_atlas/features/recording/application/audio_recorder_state.dart';
import 'package:prepare_with_atlas/features/recording/application/audio_recorder_controller.dart';

/// Orchestrates an interview session: lifecycle, stage transitions, and notes.
class SessionController extends Notifier<SessionState> {
  Timer? _debounce;

  SessionRepository get _repo => ref.read(sessionRepositoryProvider);

  @override
  SessionState build() => const SessionState();

  // ── Session start ─────────────────────────────────────────────────────────

  /// Creates and starts a full five-stage session for [problemId].
  Future<void> startFullSession({
    required int problemId,
    required TimerBehavior behavior,
    required TimerConfig config,
    required RecordingMode recordingMode,
  }) async {
    dev.log(
      'startFullSession: problemId=$problemId behavior=$behavior',
      name: 'SessionController',
    );
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final draft = InterviewSession(
        id: 0,
        problemId: problemId,
        mode: SessionMode.full,
        timerBehavior: behavior,
        timerConfig: config,
        startedAt: DateTime.now(),
      );
      dev.log(
        'startFullSession: calling repo.create()',
        name: 'SessionController',
      );
      final created = await _repo.create(draft);
      dev.log(
        'startFullSession: session created id=${created.id}',
        name: 'SessionController',
      );
      const firstStage = InterviewStage.requirementGathering;
      ref
          .read(stageTimerControllerProvider.notifier)
          .startStage(firstStage, config, behavior);
      if (recordingMode == RecordingMode.voiceRecording) {
        await _startVoiceRecording(created.id, firstStage);
      }
      state = state.copyWith(
        currentSession: created,
        currentStage: firstStage,
        isLoading: false,
        recordingMode: recordingMode,
      );
      dev.log(
        'startFullSession: state updated — currentSession=${created.id}',
        name: 'SessionController',
      );
    } on Object catch (e, st) {
      dev.log(
        'startFullSession: ERROR $e',
        name: 'SessionController',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Creates and starts a single-stage session for [problemId].
  Future<void> startSingleStageSession({
    required int problemId,
    required InterviewStage stage,
    required TimerBehavior behavior,
    required TimerConfig config,
    required RecordingMode recordingMode,
  }) async {
    dev.log(
      'startSingleStageSession: problemId=$problemId stage=$stage '
      'behavior=$behavior',
      name: 'SessionController',
    );
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final draft = InterviewSession(
        id: 0,
        problemId: problemId,
        mode: SessionMode.singleStage,
        focusStage: stage,
        timerBehavior: behavior,
        timerConfig: config,
        startedAt: DateTime.now(),
      );
      dev.log(
        'startSingleStageSession: calling repo.create()',
        name: 'SessionController',
      );
      final created = await _repo.create(draft);
      dev.log(
        'startSingleStageSession: session created id=${created.id}',
        name: 'SessionController',
      );
      ref
          .read(stageTimerControllerProvider.notifier)
          .startStage(stage, config, behavior);
      if (recordingMode == RecordingMode.voiceRecording) {
        await _startVoiceRecording(created.id, stage);
      }
      state = state.copyWith(
        currentSession: created,
        currentStage: stage,
        isLoading: false,
        recordingMode: recordingMode,
      );
      dev.log(
        'startSingleStageSession: state updated — '
        'currentSession=${created.id}',
        name: 'SessionController',
      );
    } on Object catch (e, st) {
      dev.log(
        'startSingleStageSession: ERROR $e',
        name: 'SessionController',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  /// Debounces saving notes (1 s delay) for the current stage.
  void updateNotes(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () async {
      await _saveCurrentNote(notes: text);
    });
  }

  // ── Stage transitions ─────────────────────────────────────────────────────

  /// Saves notes for the current stage and advances to the next.
  ///
  /// In [SessionMode.singleStage] mode the session ends immediately.
  /// In [SessionMode.full] mode, the session ends when the last stage
  /// is completed.
  Future<void> advanceToNextStage() async {
    final session = state.currentSession;
    final currentStage = state.currentStage;
    if (session == null || currentStage == null) return;

    await _saveCurrentNote();

    // Single-stage drill: completing the one stage ends the session.
    if (session.mode == SessionMode.singleStage) {
      await endSession();
      return;
    }

    final idx = InterviewStage.values.indexOf(currentStage);
    if (idx >= InterviewStage.values.length - 1) {
      await endSession();
      return;
    }

    final nextStage = InterviewStage.values[idx + 1];

    // Stop current voice recording before advancing.
    if (state.recordingMode == RecordingMode.voiceRecording) {
      await _stopVoiceRecording();
    }

    ref
        .read(stageTimerControllerProvider.notifier)
        .startStage(nextStage, session.timerConfig, session.timerBehavior);

    // Start new voice recording for next stage.
    if (state.recordingMode == RecordingMode.voiceRecording) {
      await _startVoiceRecording(session.id, nextStage);
    }

    state = state.copyWith(currentStage: nextStage);
  }

  /// Marks the session as completed and signals that the UI should navigate
  /// to the evaluation loading screen via [SessionState.pendingEvaluation].
  Future<void> endSession() async {
    final session = state.currentSession;
    if (session == null) return;
    await _saveCurrentNote();

    // Stop voice recording if active.
    if (state.recordingMode == RecordingMode.voiceRecording) {
      await _stopVoiceRecording();
    }

    ref.read(stageTimerControllerProvider.notifier).reset();
    final completed = session.copyWith(
      status: SessionStatus.completed,
      completedAt: DateTime.now(),
    );
    await _repo.update(completed);
    state = state.copyWith(
      currentSession: completed,
      pendingEvaluation: true,
    );
  }

  /// Clears the [SessionState.pendingEvaluation] flag after the UI has
  /// handled the navigation to evaluation.
  void clearPendingEvaluation() {
    state = state.copyWith(pendingEvaluation: false);
  }

  /// Marks the session as abandoned without saving final notes.
  Future<void> abandonSession() async {
    final session = state.currentSession;
    if (session == null) return;
    _debounce?.cancel();

    // Cancel any active voice recording.
    if (state.recordingMode == RecordingMode.voiceRecording) {
      await ref.read(audioRecorderProvider.notifier).cancelRecording();
    }

    ref.read(stageTimerControllerProvider.notifier).reset();
    final abandoned = session.copyWith(status: SessionStatus.abandoned);
    await _repo.update(abandoned);
    state = state.copyWith(currentSession: abandoned);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _startVoiceRecording(int sessionId, InterviewStage stage) async {
    await ref.read(audioRecorderProvider.notifier).startRecording(
          sessionId: sessionId,
          stageIndex: InterviewStage.values.indexOf(stage),
        );
  }

  Future<void> _stopVoiceRecording() async {
    await ref.read(audioRecorderProvider.notifier).stopRecording();
  }

  Future<void> _saveCurrentNote({String? notes}) async {
    final session = state.currentSession;
    final stage = state.currentStage;
    if (session == null || stage == null) return;

    final timerState = ref.read(stageTimerControllerProvider);
    final timeSpent = switch (timerState) {
      TimerStageEnded(:final timeSpentSeconds) => timeSpentSeconds,
      TimerRunning(:final remainingSeconds, :final totalSeconds) =>
        totalSeconds - remainingSeconds,
      TimerWarning(:final remainingSeconds, :final totalSeconds) =>
        totalSeconds - remainingSeconds,
      TimerPaused(:final remainingSeconds, :final totalSeconds) =>
        totalSeconds - remainingSeconds,
      TimerOvertime(:final overtimeSeconds) =>
        (state.currentSession?.timerConfig.durationFor(stage) ?? 0) +
            overtimeSeconds,
      _ => 0,
    };

    // Capture audio file path if voice recording is active.
    String? audioFilePath;
    if (state.recordingMode == RecordingMode.voiceRecording) {
      final recorderState = ref.read(audioRecorderProvider);
      if (recorderState is AudioRecorderRecording) {
        audioFilePath = recorderState.filePath;
      }
    }

    final existing = state.stageNotes[stage.key];
    final note = StageNote(
      id: existing?.id ?? 0,
      sessionId: session.id,
      stage: stage,
      notes: notes ?? (existing?.notes ?? ''),
      timerDurationSeconds:
          session.timerConfig.durationFor(stage),
      timeSpentSeconds: timeSpent,
      updatedAt: DateTime.now(),
      audioFilePath: audioFilePath ?? existing?.audioFilePath,
    );

    state = state.copyWith(isSaving: true);
    try {
      final saved = await _repo.saveStageNote(note);
      state = state.copyWith(
        stageNotes: Map.of(state.stageNotes)..[stage.key] = saved,
        isSaving: false,
      );
    } on Object {
      state = state.copyWith(isSaving: false);
    }
  }
}
