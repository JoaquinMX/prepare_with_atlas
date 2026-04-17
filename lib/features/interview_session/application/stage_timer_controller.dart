import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/interview_session/application/timer_state.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

/// Manages the countdown / overtime timer for a single interview stage.
///
/// Use [startStage] to begin, [pause]/[resume] to pause, [skipStage] to end
/// early, and [reset] to return to idle.
class StageTimerController extends Notifier<TimerState> {
  Timer? _timer;
  TimerBehavior _behavior = TimerBehavior.softWarning;
  int _warningThreshold = 60;
  int _gracePeriod = 30;
  int _totalSeconds = 0;
  int _elapsedSeconds = 0;

  @override
  TimerState build() => const TimerState.idle();

  /// Starts the timer for [stage] using [config] and [behavior].
  void startStage(
    InterviewStage stage,
    TimerConfig config,
    TimerBehavior behavior,
  ) {
    _timer?.cancel();
    _behavior = behavior;
    _warningThreshold = config.warningThresholdSeconds;
    _gracePeriod = config.gracePeriodSeconds;
    _totalSeconds = config.durationFor(stage);
    _elapsedSeconds = 0;

    state = TimerState.running(
      stage: stage,
      remainingSeconds: _totalSeconds,
      totalSeconds: _totalSeconds,
    );
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => onTick());
  }

  /// Advances the timer by one second.
  ///
  /// Exposed as [visibleForTesting] so unit tests can drive the clock
  /// synchronously without a real [Timer].
  @visibleForTesting
  void onTick() {
    switch (state) {
      case TimerRunning(
          :final stage,
          :final remainingSeconds,
          :final totalSeconds,
        ):
        _tick(
          stage: stage,
          remaining: remainingSeconds,
          total: totalSeconds,
        );
      case TimerWarning(
          :final stage,
          :final remainingSeconds,
          :final totalSeconds,
        ):
        _tick(
          stage: stage,
          remaining: remainingSeconds,
          total: totalSeconds,
        );
      case TimerOvertime(:final stage, :final overtimeSeconds):
        _elapsedSeconds++;
        state = TimerState.overtime(
          stage: stage,
          overtimeSeconds: overtimeSeconds + 1,
        );
      case TimerGracePeriod(:final stage, :final remainingGraceSeconds):
        final newGrace = remainingGraceSeconds - 1;
        if (newGrace <= 0) {
          _timer?.cancel();
          state = TimerState.stageEnded(
            stage: stage,
            timeSpentSeconds:
                _totalSeconds + (_gracePeriod - remainingGraceSeconds + 1),
          );
        } else {
          state = TimerState.gracePeriod(
            stage: stage,
            remainingGraceSeconds: newGrace,
          );
        }
      default:
        // Paused, Idle, StageEnded — no-op.
        break;
    }
  }

  void _tick({
    required InterviewStage stage,
    required int remaining,
    required int total,
  }) {
    _elapsedSeconds++;
    final newRemaining = remaining - 1;

    if (newRemaining <= 0) {
      switch (_behavior) {
        case TimerBehavior.softWarning:
          state = TimerState.overtime(stage: stage, overtimeSeconds: 0);
        case TimerBehavior.warningAutoAdvance:
          state = TimerState.gracePeriod(
            stage: stage,
            remainingGraceSeconds: _gracePeriod,
          );
        case TimerBehavior.hardStop:
          _timer?.cancel();
          state = TimerState.stageEnded(
            stage: stage,
            timeSpentSeconds: _totalSeconds,
          );
      }
    } else if (newRemaining <= _warningThreshold) {
      state = TimerState.warning(
        stage: stage,
        remainingSeconds: newRemaining,
        totalSeconds: total,
      );
    } else {
      state = TimerState.running(
        stage: stage,
        remainingSeconds: newRemaining,
        totalSeconds: total,
      );
    }
  }

  /// Pauses a running or warning timer.
  void pause() {
    switch (state) {
      case TimerRunning(
          :final stage,
          :final remainingSeconds,
          :final totalSeconds,
        ):
        _timer?.cancel();
        state = TimerState.paused(
          stage: stage,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
        );
      case TimerWarning(
          :final stage,
          :final remainingSeconds,
          :final totalSeconds,
        ):
        _timer?.cancel();
        state = TimerState.paused(
          stage: stage,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
        );
      default:
        break;
    }
  }

  /// Resumes a paused timer.
  void resume() {
    if (state
        case TimerPaused(
          :final stage,
          :final remainingSeconds,
          :final totalSeconds,
        )) {
      if (remainingSeconds <= _warningThreshold) {
        state = TimerState.warning(
          stage: stage,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
        );
      } else {
        state = TimerState.running(
          stage: stage,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
        );
      }
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => onTick());
    }
  }

  /// Skips the current stage, recording time spent so far.
  void skipStage() {
    _timer?.cancel();
    final currentStage = switch (state) {
      TimerRunning(:final stage) => stage,
      TimerWarning(:final stage) => stage,
      TimerPaused(:final stage) => stage,
      TimerOvertime(:final stage) => stage,
      TimerGracePeriod(:final stage) => stage,
      _ => null,
    };
    if (currentStage != null) {
      state = TimerState.stageEnded(
        stage: currentStage,
        timeSpentSeconds: _elapsedSeconds,
      );
    }
  }

  /// Cancels the timer and returns to idle.
  void reset() {
    _timer?.cancel();
    state = const TimerState.idle();
  }
}
