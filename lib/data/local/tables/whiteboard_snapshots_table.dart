import 'package:drift/drift.dart';

/// Stores periodic Excalidraw scene snapshots for an interview session.
class WhiteboardSnapshots extends Table {
  /// Auto-incremented primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key referencing the interview_sessions table.
  IntColumn get sessionId => integer()();

  /// JSON-encoded Excalidraw scene data.
  TextColumn get sceneJson => text()();

  /// Optional PNG screenshot captured at snapshot time (raw bytes).
  BlobColumn get screenshotPng => blob().nullable()();

  /// When this snapshot was recorded.
  DateTimeColumn get capturedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
