import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart'
    as domain;
import 'package:prepare_with_atlas/features/problem_bank/domain/problem_repository.dart';

/// Drift-backed implementation of [ProblemRepository].
///
/// All queries operate on the problems table inside [AppDatabase].
/// The Drift-generated row type is the unqualified Problem from the generated
/// database file; the domain model is aliased as a prefixed import.
class DriftProblemRepository implements ProblemRepository {
  /// Creates a [DriftProblemRepository] backed by [_db].
  const DriftProblemRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<domain.Problem>> getByExperienceLevel(
    ExperienceLevel level,
  ) async {
    final rows = await (_db.select(_db.problems)
          ..where((t) => t.difficulty.equals(level.difficultyKey))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows.map(_toModel).toList();
  }

  @override
  Future<domain.Problem?> getById(int id) async {
    final row = await (_db.select(_db.problems)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  @override
  Future<List<domain.Problem>> searchByTitle(String query) async {
    final pattern = '%${query.toLowerCase()}%';
    final rows = await (_db.select(_db.problems)
          ..where(
            (t) => t.title.lower().like(pattern),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.difficulty),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return rows.map(_toModel).toList();
  }

  @override
  Future<int> insert(domain.Problem problem) async {
    return _db.into(_db.problems).insert(
          ProblemsCompanion.insert(
            title: problem.title,
            description: problem.description,
            difficulty: problem.difficulty,
            category: problem.category,
            tags: Value(jsonEncode(problem.tags)),
            referenceSolution: Value(problem.referenceSolution),
            isCurated: Value(problem.isCurated),
            isAiGenerated: Value(problem.isAiGenerated),
          ),
        );
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.problems)..where((t) => t.id.equals(id))).go();
  }

  @override
  Stream<List<domain.Problem>> watchAll() {
    return (_db.select(_db.problems)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  @override
  Future<int> count() async {
    final countExpr = _db.problems.id.count();
    final query = _db.selectOnly(_db.problems)..addColumns([countExpr]);
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// Maps a Drift-generated [Problem] row to the domain [domain.Problem] model.
  domain.Problem _toModel(Problem row) {
    final rawTags = jsonDecode(row.tags) as List<dynamic>;
    return domain.Problem(
      id: row.id,
      title: row.title,
      description: row.description,
      difficulty: row.difficulty,
      category: row.category,
      tags: rawTags.cast<String>(),
      referenceSolution: row.referenceSolution,
      isCurated: row.isCurated,
      isAiGenerated: row.isAiGenerated,
      createdAt: row.createdAt,
    );
  }
}
