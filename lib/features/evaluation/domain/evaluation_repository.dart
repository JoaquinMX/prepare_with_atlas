import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';

/// Abstract port for evaluation persistence.
abstract class EvaluationRepository {
  /// Saves [evaluation] to the data store.
  Future<void> save(EvaluationResult evaluation);

  /// Returns the **latest** [EvaluationResult] for [sessionId] (highest
  /// `createdAt`), or null if no evaluation exists. A single session may
  /// have multiple evaluations when the user re-evaluates with a different
  /// AI provider (spec 07, US-07.8).
  Future<EvaluationResult?> getBySessionId(String sessionId);

  /// Returns every [EvaluationResult] persisted for [sessionId], newest
  /// first. Used by the session-detail UI to populate the multi-evaluation
  /// dropdown (spec 07, EC-07.2).
  Future<List<EvaluationResult>> getAllBySessionId(String sessionId);

  /// Returns all persisted evaluations, newest first.
  Future<List<EvaluationResult>> getAll();

  /// Deletes the evaluation with [id].
  Future<void> delete(String id);
}
