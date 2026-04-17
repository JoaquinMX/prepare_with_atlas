import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_repository.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';

/// Drift-backed implementation of [EvaluationRepository].
class DriftEvaluationRepository implements EvaluationRepository {
  /// Creates a [DriftEvaluationRepository] with the given [_db].
  const DriftEvaluationRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> save(EvaluationResult evaluation) async {
    final sessionId = int.tryParse(evaluation.sessionId) ?? 0;
    await _db.into(_db.evaluations).insertOnConflictUpdate(
          EvaluationsCompanion.insert(
            id: evaluation.id,
            sessionId: sessionId,
            providerUsed: evaluation.providerUsed,
            modelUsed: evaluation.modelUsed,
            scorecardJson: jsonEncode(evaluation.scorecard),
            narrative: evaluation.narrative,
            rawResponseJson: Value(evaluation.rawResponse),
            evaluationDataJson: jsonEncode(evaluation.toJson()),
            createdAt: evaluation.createdAt.millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<EvaluationResult?> getBySessionId(String sessionId) async {
    final id = int.tryParse(sessionId) ?? 0;
    final row = await (_db.select(_db.evaluations)
          ..where((t) => t.sessionId.equals(id))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<EvaluationResult>> getAllBySessionId(String sessionId) async {
    final id = int.tryParse(sessionId) ?? 0;
    final rows = await (_db.select(_db.evaluations)
          ..where((t) => t.sessionId.equals(id))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<EvaluationResult>> getAll() async {
    final rows = await (_db.select(_db.evaluations)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.evaluations)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  EvaluationResult _fromRow(Evaluation row) {
    final json =
        jsonDecode(row.evaluationDataJson) as Map<String, dynamic>;
    return EvaluationResult.fromJson(json);
  }
}
