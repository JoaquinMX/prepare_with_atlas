import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/recording/application/audio_recorder_state.dart';

part 'session_state.freezed.dart';

/// UI state for the active interview session.
@freezed
abstract class SessionState with _$SessionState {
  /// Creates a [SessionState].
  const factory SessionState({
    /// The currently active session, or null when none is in progress.
    InterviewSession? currentSession,

    /// The stage the candidate is currently working on.
    InterviewStage? currentStage,

    /// Notes keyed by [InterviewStage.key].
    @Default({}) Map<String, StageNote> stageNotes,

    /// True while the session is being created or loaded.
    @Default(false) bool isLoading,

    /// True while stage notes are being saved.
    @Default(false) bool isSaving,

    /// Non-null when an error has occurred.
    String? errorMessage,

    /// Set to `true` after `endSession` completes successfully to signal that
    /// the UI should navigate to the evaluation flow.
    @Default(false) bool pendingEvaluation,

    /// The recording mode selected at session start.
    @Default(RecordingMode.notesOnly) RecordingMode recordingMode,
  }) = _SessionState;
}
