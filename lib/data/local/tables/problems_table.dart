import 'package:drift/drift.dart';

/// Drift table definition for the [Problems] data store.
///
/// Metadata columns ([difficulty], [category], [tags]) exist only for
/// AI evaluation and section grouping. They must never be exposed in
/// the Problem Bank list UI (no-spoilers constraint).
class Problems extends Table {
  /// Auto-incremented primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Short title of the problem.
  TextColumn get title => text().withLength(min: 1, max: 500)();

  /// Full problem statement — shown at session start only.
  TextColumn get description => text()();

  /// Difficulty level: 'easy' | 'medium' | 'hard'. Metadata only.
  TextColumn get difficulty => text()();

  /// High-level category. Metadata only.
  TextColumn get category => text()();

  /// JSON array string of keyword tags. Metadata only.
  TextColumn get tags => text().withDefault(const Constant('[]'))();

  /// Model reference answer — shown only after AI evaluation.
  TextColumn get referenceSolution => text().nullable()();

  /// True for hand-curated Atlas problems.
  BoolColumn get isCurated => boolean().withDefault(const Constant(true))();

  /// True for AI-generated problems (Spec 05).
  BoolColumn get isAiGenerated =>
      boolean().withDefault(const Constant(false))();

  /// Timestamp when the row was created.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
