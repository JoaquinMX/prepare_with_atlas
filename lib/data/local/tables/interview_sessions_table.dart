import 'package:drift/drift.dart';

/// Stores persistent interview session records.
class InterviewSessions extends Table {
  /// Auto-incremented primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to the Problems table.
  IntColumn get problemId => integer()();

  /// Session mode: 'full' or 'single_stage'.
  TextColumn get mode => text()();

  /// Stage key for single-stage mode; null for full sessions.
  TextColumn get focusStage => text().nullable()();

  /// Timer behavior key: soft_warning, warning_auto_advance, or hard_stop.
  TextColumn get timerBehavior => text()();

  /// JSON-serialised timer configuration.
  TextColumn get timerConfigJson => text()();

  /// Session lifecycle status.
  TextColumn get status =>
      text().withDefault(const Constant('in_progress'))();

  /// When the session began.
  DateTimeColumn get startedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// When the session ended; null while in progress.
  DateTimeColumn get completedAt => dateTime().nullable()();
}
