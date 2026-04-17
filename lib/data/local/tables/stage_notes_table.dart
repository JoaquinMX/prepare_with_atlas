import 'package:drift/drift.dart';

/// Stores per-stage notes and time tracking for an interview session.
class StageNotes extends Table {
  /// Auto-incremented primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key referencing the interview_sessions table.
  IntColumn get sessionId => integer()();

  /// Stage key matching the InterviewStage enum name.
  TextColumn get stageName => text()();

  /// Free-form notes typed by the candidate.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Total allocated seconds for this stage.
  IntColumn get timerDurationSeconds => integer()();

  /// Seconds actually spent on this stage.
  IntColumn get timeSpentSeconds =>
      integer().withDefault(const Constant(0))();

  /// Last time this row was written.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
