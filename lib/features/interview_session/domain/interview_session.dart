import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

part 'interview_session.freezed.dart';
part 'interview_session.g.dart';

/// Mode in which an interview session is conducted.
enum SessionMode {
  /// All five stages in sequence.
  full,

  /// A single chosen stage only.
  singleStage;

  /// Stable string key for serialisation.
  String get key => switch (this) {
        full => 'full',
        singleStage => 'single_stage',
      };

  /// Deserialises a [key] back to a [SessionMode].
  static SessionMode fromKey(String k) =>
      SessionMode.values.firstWhere((m) => m.key == k);
}

/// Lifecycle status of an interview session.
enum SessionStatus {
  /// Session is currently active.
  inProgress,

  /// Session finished normally.
  completed,

  /// Session was discarded mid-way.
  abandoned;

  /// Stable string key for serialisation.
  String get key => switch (this) {
        inProgress => 'in_progress',
        completed => 'completed',
        abandoned => 'abandoned',
      };

  /// Deserialises a [key] back to a [SessionStatus].
  static SessionStatus fromKey(String k) =>
      SessionStatus.values.firstWhere((s) => s.key == k);
}

/// A complete record of a candidate's interview practice session.
@freezed
abstract class InterviewSession with _$InterviewSession {
  /// Creates an [InterviewSession].
  const factory InterviewSession({
    /// Database-assigned identifier (0 before persistence).
    required int id,

    /// ID of the problem being practised.
    required int problemId,

    /// Whether this is a full or single-stage session.
    required SessionMode mode,

    /// How the timer should behave when time runs out.
    required TimerBehavior timerBehavior,

    /// Duration and threshold configuration.
    required TimerConfig timerConfig,

    /// When the session started.
    required DateTime startedAt,

    /// The stage practised in single-stage mode; null for full sessions.
    InterviewStage? focusStage,

    /// Current lifecycle status.
    @Default(SessionStatus.inProgress) SessionStatus status,

    /// When the session ended; null while in progress.
    DateTime? completedAt,
  }) = _InterviewSession;

  const InterviewSession._();

  /// Deserialises from JSON.
  factory InterviewSession.fromJson(Map<String, dynamic> json) =>
      _$InterviewSessionFromJson(json);
}
