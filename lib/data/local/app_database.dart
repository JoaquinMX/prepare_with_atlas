import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:prepare_with_atlas/data/local/tables/ai_provider_configs_table.dart';
import 'package:prepare_with_atlas/data/local/tables/evaluations_table.dart';
import 'package:prepare_with_atlas/data/local/tables/interview_sessions_table.dart';
import 'package:prepare_with_atlas/data/local/tables/problems_table.dart';
import 'package:prepare_with_atlas/data/local/tables/stage_notes_table.dart';
import 'package:prepare_with_atlas/data/local/tables/whiteboard_snapshots_table.dart';

part 'app_database.g.dart';

/// The local SQLite database for PrepareWithAtlas.
@DriftDatabase(
  tables: [
    Problems,
    AiProviderConfigs,
    InterviewSessions,
    StageNotes,
    WhiteboardSnapshots,
    Evaluations,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates an [AppDatabase] with the default drift_flutter connection.
  AppDatabase() : super(_openConnection());

  /// Creates an [AppDatabase] with a custom [QueryExecutor].
  ///
  /// Use this constructor in tests to provide an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // createTable uses CREATE TABLE IF NOT EXISTS — safe to call even
          // if the table already exists on this device.
          if (from < 6) {
            // Spec 03 — Interview Session & Timer
            await m.createTable(interviewSessions);
            await m.createTable(stageNotes);
            // Spec 04 — Whiteboard Integration
            await m.createTable(whiteboardSnapshots);
            // Spec 05 — AI Provider System
            await m.createTable(aiProviderConfigs);
            // Spec 06 — AI Evaluation
            await m.createTable(evaluations);
          }
          if (from < 7) {
            // Add audioFilePath column to stage_notes for voice recording.
            await m.addColumn(stageNotes, stageNotes.audioFilePath);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'prepare_with_atlas');
  }
}
