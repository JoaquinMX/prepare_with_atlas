import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';

part 'timer_state.freezed.dart';

/// All possible states of the stage countdown timer.
@freezed
sealed class TimerState with _$TimerState {
  /// Timer has not been started yet.
  const factory TimerState.idle() = TimerIdle;

  /// Timer is counting down normally.
  const factory TimerState.running({
    required InterviewStage stage,
    required int remainingSeconds,
    required int totalSeconds,
  }) = TimerRunning;

  /// Timer is paused mid-stage.
  const factory TimerState.paused({
    required InterviewStage stage,
    required int remainingSeconds,
    required int totalSeconds,
  }) = TimerPaused;

  /// Remaining seconds are at or below the warning threshold.
  const factory TimerState.warning({
    required InterviewStage stage,
    required int remainingSeconds,
    required int totalSeconds,
  }) = TimerWarning;

  /// Stage time is exhausted; timer counts upward in overtime.
  const factory TimerState.overtime({
    required InterviewStage stage,
    required int overtimeSeconds,
  }) = TimerOvertime;

  /// A fixed grace window is counting down before auto-advance.
  const factory TimerState.gracePeriod({
    required InterviewStage stage,
    required int remainingGraceSeconds,
  }) = TimerGracePeriod;

  /// Stage has ended; carries total time spent.
  const factory TimerState.stageEnded({
    required InterviewStage stage,
    required int timeSpentSeconds,
  }) = TimerStageEnded;
}
