import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_repository.dart';
import 'package:prepare_with_atlas/features/history/application/comparison_state.dart';
import 'package:prepare_with_atlas/features/history/domain/progress_diff.dart';

/// Provides the [EvaluationRepository] used by [ComparisonController].
///
/// Override in tests to inject a mock:
/// ```dart
/// comparisonEvaluationRepositoryProvider.overrideWithValue(mockRepo)
/// ```
final comparisonEvaluationRepositoryProvider =
    Provider<EvaluationRepository>((ref) {
  throw UnimplementedError(
    'comparisonEvaluationRepositoryProvider must be overridden',
  );
});

/// Provides the [ComparisonController] / [ComparisonState] pair.
final comparisonControllerProvider =
    NotifierProvider<ComparisonController, ComparisonState>(
  ComparisonController.new,
);

/// Loads and computes a [ProgressDiff] between two sessions.
class ComparisonController extends Notifier<ComparisonState> {
  @override
  ComparisonState build() => const ComparisonIdle();

  /// Fetches evaluations for [priorSessionId] and [currentSessionId],
  /// then computes a [ProgressDiff] and emits [ComparisonSuccess].
  ///
  /// Emits [ComparisonError] if either evaluation cannot be found.
  Future<void> loadComparison({
    required String priorSessionId,
    required String currentSessionId,
  }) async {
    state = const ComparisonLoading();
    try {
      final repo = ref.read(comparisonEvaluationRepositoryProvider);
      final results = await Future.wait([
        repo.getBySessionId(priorSessionId),
        repo.getBySessionId(currentSessionId),
      ]);
      final priorEval = results[0];
      final currentEval = results[1];

      if (priorEval == null) {
        state = const ComparisonError(
          message: 'No evaluation found for the prior session.',
        );
        return;
      }
      if (currentEval == null) {
        state = const ComparisonError(
          message: 'No evaluation found for the current session.',
        );
        return;
      }

      state = ComparisonSuccess(
        diff: ProgressDiff.from(priorEval, currentEval),
      );
    } catch (e) {
      state = ComparisonError(message: e.toString());
    }
  }
}
