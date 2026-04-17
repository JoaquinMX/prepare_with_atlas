import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem_repository.dart';

/// Loads the bundled curated problem set into the local database on first run.
///
/// If the database already contains problems the seed is skipped, making this
/// safe to call every time the app starts.
class CuratedProblemsLoader {
  /// Creates a [CuratedProblemsLoader].
  CuratedProblemsLoader({Logger? logger})
      : _logger = logger ?? Logger();

  final Logger _logger;

  static const _assetPath = 'assets/problems/curated_problems.json';

  /// Seeds the repository with curated problems if it is empty.
  ///
  /// Parses errors are caught and logged; they do not propagate to the caller.
  Future<void> seedIfNeeded(ProblemRepository repo) async {
    try {
      final existing = await repo.count();
      if (existing > 0) return;

      final raw = await rootBundle.loadString(_assetPath);
      final list = jsonDecode(raw) as List<dynamic>;

      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final tags = (map['tags'] as List<dynamic>? ?? []).cast<String>();
        final problem = Problem(
          id: 0,
          title: map['title'] as String,
          description: map['description'] as String,
          difficulty: map['difficulty'] as String,
          category: map['category'] as String,
          tags: tags,
          referenceSolution: map['reference_solution'] as String?,
          createdAt: DateTime.now(),
        );
        await repo.insert(problem);
      }

      _logger.i('Seeded ${list.length} curated problems.');
    } catch (e, st) {
      _logger.e('Failed to seed curated problems', error: e, stackTrace: st);
    }
  }
}
