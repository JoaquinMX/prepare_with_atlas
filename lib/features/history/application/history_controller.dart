import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/history/application/history_providers.dart';
import 'package:prepare_with_atlas/features/history/application/history_state.dart';
import 'package:prepare_with_atlas/features/history/application/history_view_mode.dart';
import 'package:prepare_with_atlas/features/history/domain/problem_attempts.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';

/// Provides a reactive stream of all session summaries sorted by date.
final historySessionsStreamProvider =
    StreamProvider<List<SessionSummary>>((ref) {
  return ref.watch(historyRepositoryProvider).watchHistory();
});

/// Provides a reactive stream of sessions grouped by problem.
final historyByProblemStreamProvider =
    StreamProvider<List<ProblemAttempts>>((ref) {
  return ref.watch(historyRepositoryProvider).watchHistoryByProblem();
});

/// Manages the [HistoryState] for the history screens.
///
/// Derives sessions and problem groups from watched stream providers.
/// The view mode survives rebuilds because it is stored in
/// [_currentViewMode] and applied during each [build] call.
class HistoryController extends Notifier<HistoryState> {
  HistoryViewMode _currentViewMode = HistoryViewMode.flat;

  @override
  HistoryState build() {
    final sessionsAsync = ref.watch(historySessionsStreamProvider);
    final groupsAsync = ref.watch(historyByProblemStreamProvider);

    return HistoryState(
      viewMode: _currentViewMode,
      sessions: sessionsAsync.value ?? const [],
      problemGroups: groupsAsync.value ?? const [],
      isLoading: sessionsAsync.isLoading,
    );
  }

  /// Toggles between [HistoryViewMode.flat] and [HistoryViewMode.byProblem].
  void toggleView() {
    _currentViewMode = _currentViewMode == HistoryViewMode.flat
        ? HistoryViewMode.byProblem
        : HistoryViewMode.flat;
    state = state.copyWith(viewMode: _currentViewMode);
  }

  /// Deletes the session with [sessionId] from the repository.
  Future<void> deleteSession(int sessionId) async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.deleteSession(sessionId);
  }
}
