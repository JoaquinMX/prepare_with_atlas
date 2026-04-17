import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/history/application/history_view_mode.dart';
import 'package:prepare_with_atlas/features/history/domain/problem_attempts.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';

part 'history_state.freezed.dart';

/// State managed by the history controller.
@freezed
abstract class HistoryState with _$HistoryState {
  /// Creates a [HistoryState].
  const factory HistoryState({
    /// Whether the history is in flat (date-sorted) or grouped-by-problem view.
    @Default(HistoryViewMode.flat) HistoryViewMode viewMode,

    /// Flat list of session summaries, sorted by date descending.
    @Default([]) List<SessionSummary> sessions,

    /// Sessions grouped by problem.
    @Default([]) List<ProblemAttempts> problemGroups,

    /// True while the initial data is being loaded.
    @Default(false) bool isLoading,
  }) = _HistoryState;
}
