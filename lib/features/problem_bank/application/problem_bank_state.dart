import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';

part 'problem_bank_state.freezed.dart';

/// Immutable state managed by the ProblemBankController.
@freezed
abstract class ProblemBankState with _$ProblemBankState {
  /// Creates a [ProblemBankState].
  const factory ProblemBankState({
    /// Problems grouped by [ExperienceLevel], filtered by [searchQuery].
    @Default({}) Map<ExperienceLevel, List<Problem>> sections,

    /// Current search query string; empty string means no active search.
    @Default('') String searchQuery,

    /// Whether the initial data load is in progress.
    @Default(true) bool isLoading,

    /// Non-null when an error occurred during loading.
    String? errorMessage,
  }) = _ProblemBankState;
}
