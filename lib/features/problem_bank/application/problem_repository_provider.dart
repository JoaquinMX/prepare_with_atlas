import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/providers/app_database_provider.dart';
import 'package:prepare_with_atlas/features/problem_bank/data/drift_problem_repository.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem_repository.dart';

export 'package:prepare_with_atlas/core/providers/app_database_provider.dart'
    show appDatabaseProvider;

/// Provides the [ProblemRepository] backed by the local Drift database.
///
/// Override this in tests to inject a fake repository:
/// ```dart
/// problemRepositoryProvider.overrideWithValue(fakeRepo)
/// ```
final problemRepositoryProvider = Provider<ProblemRepository>(
  (ref) => DriftProblemRepository(ref.watch(appDatabaseProvider)),
);
