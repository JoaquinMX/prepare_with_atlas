import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_bank_state.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_repository_provider.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem_repository.dart';

/// Manages the [ProblemBankState] for the Problem Bank screen.
///
/// Loads problems from [ProblemRepository] grouped by [ExperienceLevel] and
/// supports in-memory title search without re-querying the database.
///
/// The repository is resolved through [problemRepositoryProvider]. Override
/// that provider in tests to inject a fake:
/// ```dart
/// ProviderScope(
///   overrides: [
///     problemRepositoryProvider.overrideWithValue(fakeRepo),
///   ],
/// )
/// ```
class ProblemBankController extends Notifier<ProblemBankState> {
  // Full unfiltered sections kept in memory so clearSearch is instant.
  Map<ExperienceLevel, List<Problem>> _allSections = {};

  @override
  ProblemBankState build() {
    // Schedule _loadAll after build() returns so that the initial state is
    // set before we try to call state.copyWith(...) inside _loadAll.
    Future.microtask(_loadAll);
    return const ProblemBankState();
  }

  /// Loads problems for all three experience levels from the repository.
  Future<void> _loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(problemRepositoryProvider);
      final results = await Future.wait<List<Problem>>(
        ExperienceLevel.values.map(repo.getByExperienceLevel),
      );
      _allSections = <ExperienceLevel, List<Problem>>{
        for (var i = 0; i < ExperienceLevel.values.length; i++)
          ExperienceLevel.values[i]: results[i],
      };
      state = state.copyWith(
        sections: Map<ExperienceLevel, List<Problem>>.unmodifiable(
          _allSections,
        ),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Filters each section in-memory to problems whose title contains [query].
  ///
  /// The search is case-insensitive and limited to the title field.
  Future<void> search(String query) async {
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    final lower = query.toLowerCase();
    final filtered = <ExperienceLevel, List<Problem>>{
      for (final entry in _allSections.entries)
        entry.key: entry.value
            .where((p) => p.title.toLowerCase().contains(lower))
            .toList(),
    };
    state = state.copyWith(
      sections: Map<ExperienceLevel, List<Problem>>.unmodifiable(filtered),
      searchQuery: query,
    );
  }

  /// Resets the search and restores the full unfiltered problem list.
  void clearSearch() {
    state = state.copyWith(
      sections: Map<ExperienceLevel, List<Problem>>.unmodifiable(
        _allSections,
      ),
      searchQuery: '',
    );
  }

  /// Reloads all problems from the repository.
  Future<void> refresh() => _loadAll();
}
