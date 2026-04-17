import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/history/application/history_controller.dart';
import 'package:prepare_with_atlas/features/history/application/history_state.dart';
import 'package:prepare_with_atlas/features/history/data/drift_history_repository.dart';
import 'package:prepare_with_atlas/features/history/domain/history_repository.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_repository_provider.dart';

export 'package:prepare_with_atlas/features/history/application/history_controller.dart'
    show
        HistoryController,
        historyByProblemStreamProvider,
        historySessionsStreamProvider;

/// Provides the [HistoryRepository] backed by the local Drift database.
///
/// Override this in tests to inject a fake repository:
/// ```dart
/// historyRepositoryProvider.overrideWithValue(fakeRepo)
/// ```
final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => DriftHistoryRepository(ref.watch(appDatabaseProvider)),
);

/// Provides the history controller and its state.
final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryState>(
  HistoryController.new,
);

/// Returns the number of attempts the user has made for a given problem id.
final attemptCountForProblemProvider =
    FutureProvider.autoDispose.family<int, int>((ref, problemId) async {
  final attempts = await ref
      .watch(historyRepositoryProvider)
      .getAttemptsForProblem(problemId.toString());
  return attempts.length;
});
