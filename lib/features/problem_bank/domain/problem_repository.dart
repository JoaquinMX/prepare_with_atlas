import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';

/// Contract for accessing and mutating [Problem] records.
///
/// Implementations may use a local database, an in-memory store for
/// tests, or a remote data source.
abstract class ProblemRepository {
  /// Returns all problems whose difficulty maps to [level], ordered by id.
  Future<List<Problem>> getByExperienceLevel(ExperienceLevel level);

  /// Returns the problem with [id], or null if not found.
  Future<Problem?> getById(int id);

  /// Returns all problems whose title contains [query] (case-insensitive).
  ///
  /// The search is limited to the title field — description and tags are
  /// not searched to avoid leaking spoilers.
  Future<List<Problem>> searchByTitle(String query);

  /// Persists [problem] and returns the auto-assigned id.
  Future<int> insert(Problem problem);

  /// Removes the problem with [id].
  Future<void> delete(int id);

  /// Emits the full problem list whenever it changes.
  Stream<List<Problem>> watchAll();

  /// Returns the total number of stored problems.
  Future<int> count();
}
