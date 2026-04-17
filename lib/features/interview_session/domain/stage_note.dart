import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';

part 'stage_note.freezed.dart';
part 'stage_note.g.dart';

/// Notes and time tracking for a single stage within a session.
@freezed
abstract class StageNote with _$StageNote {
  /// Creates a [StageNote].
  const factory StageNote({
    /// Database-assigned identifier (0 before persistence).
    required int id,

    /// ID of the owning session.
    required int sessionId,

    /// Which stage these notes belong to.
    required InterviewStage stage,

    /// Total allocated seconds for this stage.
    required int timerDurationSeconds,

    /// When this row was last written.
    required DateTime updatedAt,

    /// Candidate's free-form notes for this stage.
    @Default('') String notes,

    /// Seconds spent on this stage.
    @Default(0) int timeSpentSeconds,
  }) = _StageNote;

  const StageNote._();

  /// Deserialises from JSON.
  factory StageNote.fromJson(Map<String, dynamic> json) =>
      _$StageNoteFromJson(json);
}
