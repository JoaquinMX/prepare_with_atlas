import 'dart:convert';
import 'dart:developer' as dev;

import 'package:drift/drift.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart' as db;
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart'
    as domain;
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/session_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart'
    as domain;
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

/// Drift-backed implementation of [SessionRepository].
class DriftSessionRepository implements SessionRepository {
  /// Creates a [DriftSessionRepository] backed by [_db].
  DriftSessionRepository(this._db);

  final db.AppDatabase _db;

  // ── Session CRUD ──────────────────────────────────────────────────────────

  @override
  Future<domain.InterviewSession> create(
    domain.InterviewSession session,
  ) async {
    dev.log(
      'DriftSessionRepository.create: problemId=${session.problemId} '
      'mode=${session.mode} focusStage=${session.focusStage}',
      name: 'DriftSessionRepository',
    );
    try {
      final companion = _toCompanion(session);
      dev.log(
        'DriftSessionRepository.create: companion built — inserting',
        name: 'DriftSessionRepository',
      );
      final id = await _db
          .into(_db.interviewSessions)
          .insert(companion);
      dev.log(
        'DriftSessionRepository.create: inserted id=$id',
        name: 'DriftSessionRepository',
      );
      return session.copyWith(id: id);
    } on Object catch (e, st) {
      dev.log(
        'DriftSessionRepository.create: ERROR $e',
        name: 'DriftSessionRepository',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<domain.InterviewSession?> getById(int id) async {
    final row = await (_db.select(_db.interviewSessions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<domain.InterviewSession>> getAll() async {
    final rows = await _db.select(_db.interviewSessions).get();
    return rows.map<domain.InterviewSession>(_toDomain).toList();
  }

  @override
  Future<void> update(domain.InterviewSession session) async {
    await (_db.update(_db.interviewSessions)
          ..where((t) => t.id.equals(session.id)))
        .write(_toCompanion(session));
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.interviewSessions)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  @override
  Stream<List<domain.InterviewSession>> watchAll() {
    return _db.select(_db.interviewSessions).watch().map(
          (rows) =>
              rows.map<domain.InterviewSession>(_toDomain).toList(),
        );
  }

  // ── Stage notes ───────────────────────────────────────────────────────────

  @override
  Future<domain.StageNote> saveStageNote(domain.StageNote note) async {
    final existing = await getStageNote(note.sessionId, note.stage);
    if (existing == null) {
      final id = await _db
          .into(_db.stageNotes)
          .insert(_toNoteCompanion(note));
      return note.copyWith(id: id);
    } else {
      await (_db.update(_db.stageNotes)
            ..where(
              (t) =>
                  t.sessionId.equals(note.sessionId) &
                  t.stageName.equals(note.stage.key),
            ))
          .write(_toNoteCompanion(note));
      return note.copyWith(id: existing.id);
    }
  }

  @override
  Future<List<domain.StageNote>> getStageNotes(int sessionId) async {
    final rows = await (_db.select(_db.stageNotes)
          ..where((t) => t.sessionId.equals(sessionId)))
        .get();
    return rows.map<domain.StageNote>(_toNoteDomain).toList();
  }

  @override
  Future<domain.StageNote?> getStageNote(
    int sessionId,
    InterviewStage stage,
  ) async {
    final row = await (_db.select(_db.stageNotes)
          ..where(
            (t) =>
                t.sessionId.equals(sessionId) &
                t.stageName.equals(stage.key),
          ))
        .getSingleOrNull();
    return row == null ? null : _toNoteDomain(row);
  }

  // ── Mappers ───────────────────────────────────────────────────────────────

  db.InterviewSessionsCompanion _toCompanion(
    domain.InterviewSession s,
  ) =>
      db.InterviewSessionsCompanion(
        id: s.id == 0 ? const Value.absent() : Value(s.id),
        problemId: Value(s.problemId),
        mode: Value(s.mode.key),
        focusStage: Value(s.focusStage?.key),
        timerBehavior: Value(s.timerBehavior.key),
        timerConfigJson: Value(jsonEncode(s.timerConfig.toJson())),
        status: Value(s.status.key),
        startedAt: Value(s.startedAt),
        completedAt: Value(s.completedAt),
      );

  domain.InterviewSession _toDomain(db.InterviewSession row) =>
      domain.InterviewSession(
        id: row.id,
        problemId: row.problemId,
        mode: domain.SessionMode.fromKey(row.mode),
        focusStage: row.focusStage != null
            ? InterviewStage.fromKey(row.focusStage!)
            : null,
        timerBehavior: TimerBehavior.fromKey(row.timerBehavior),
        timerConfig: TimerConfig.fromJson(
          jsonDecode(row.timerConfigJson) as Map<String, dynamic>,
        ),
        status: domain.SessionStatus.fromKey(row.status),
        startedAt: row.startedAt,
        completedAt: row.completedAt,
      );

  db.StageNotesCompanion _toNoteCompanion(domain.StageNote n) =>
      db.StageNotesCompanion(
        id: n.id == 0 ? const Value.absent() : Value(n.id),
        sessionId: Value(n.sessionId),
        stageName: Value(n.stage.key),
        notes: Value(n.notes),
        timerDurationSeconds: Value(n.timerDurationSeconds),
        timeSpentSeconds: Value(n.timeSpentSeconds),
        updatedAt: Value(n.updatedAt),
      );

  domain.StageNote _toNoteDomain(db.StageNote row) => domain.StageNote(
        id: row.id,
        sessionId: row.sessionId,
        stage: InterviewStage.fromKey(row.stageName),
        notes: row.notes,
        timerDurationSeconds: row.timerDurationSeconds,
        timeSpentSeconds: row.timeSpentSeconds,
        updatedAt: row.updatedAt,
      );
}
