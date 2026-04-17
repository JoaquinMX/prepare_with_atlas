import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';

part 'timer_config.freezed.dart';
part 'timer_config.g.dart';

/// Configuration for the stage timer.
///
/// Includes warning thresholds, grace period, and per-stage duration overrides.
@freezed
abstract class TimerConfig with _$TimerConfig {
  /// Creates a [TimerConfig].
  const factory TimerConfig({
    /// Seconds remaining when the warning state activates.
    @Default(60) int warningThresholdSeconds,

    /// Grace period in seconds for the warning-auto-advance behaviour.
    @Default(30) int gracePeriodSeconds,

    /// Per-stage duration overrides keyed by the stage name.
    ///
    /// Falls back to the stage's default duration in minutes × 60.
    @Default({}) Map<String, int> stageDurationsSeconds,
  }) = _TimerConfig;

  const TimerConfig._();

  /// Deserialises from JSON.
  factory TimerConfig.fromJson(Map<String, dynamic> json) =>
      _$TimerConfigFromJson(json);
}

/// Extension providing stage-aware duration lookup.
extension TimerConfigX on TimerConfig {
  /// Returns the duration in seconds for [stage].
  ///
  /// Uses the override from [stageDurationsSeconds] if present,
  /// otherwise falls back to [InterviewStage.defaultDurationMinutes] × 60.
  int durationFor(InterviewStage stage) =>
      stageDurationsSeconds[stage.key] ?? stage.defaultDurationMinutes * 60;
}
