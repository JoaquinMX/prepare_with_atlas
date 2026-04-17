import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';

/// Persistence contract for interview sessions and stage notes.
abstract class SessionRepository {
  /// Persists a new session and returns it with the DB-assigned id.
  Future<InterviewSession> create(InterviewSession session);

  /// Returns the session with [id], or null if not found.
  Future<InterviewSession?> getById(int id);

  /// Returns all sessions, most-recent first.
  Future<List<InterviewSession>> getAll();

  /// Updates an existing session row.
  Future<void> update(InterviewSession session);

  /// Deletes the session identified by [id].
  Future<void> delete(int id);

  /// Emits the full list of sessions whenever any session changes.
  Stream<List<InterviewSession>> watchAll();

  /// Inserts or updates a stage note for its (sessionId, stage) pair.
  Future<StageNote> saveStageNote(StageNote note);

  /// Returns all stage notes for [sessionId].
  Future<List<StageNote>> getStageNotes(int sessionId);

  /// Returns the note for [sessionId] + [stage], or null if none exists.
  Future<StageNote?> getStageNote(int sessionId, InterviewStage stage);
}
