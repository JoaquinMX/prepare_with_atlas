import 'package:drift/drift.dart';
import 'package:prepare_with_atlas/data/local/tables/interview_sessions_table.dart';

/// Stores AI-generated evaluation results for completed interview sessions.
class Evaluations extends Table {
  /// Unique string identifier for the evaluation.
  TextColumn get id => text()();

  /// Foreign key referencing the interview_sessions table.
  IntColumn get sessionId =>
      integer().references(InterviewSessions, #id)();

  /// The AI provider used to generate this evaluation.
  TextColumn get providerUsed => text()();

  /// The model identifier used to generate this evaluation.
  TextColumn get modelUsed => text()();

  /// JSON-encoded scorecard map (dimension → score).
  TextColumn get scorecardJson => text()();

  /// Markdown narrative from the AI evaluator.
  TextColumn get narrative => text()();

  /// Raw JSON response from the AI provider (nullable).
  TextColumn get rawResponseJson => text().nullable()();

  /// Full JSON-encoded evaluation result for round-trip restoration.
  TextColumn get evaluationDataJson => text()();

  /// Unix timestamp (milliseconds since epoch) when this row was created.
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
