import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_bank_controller.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_bank_state.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_repository_provider.dart';
import 'package:prepare_with_atlas/features/problem_bank/data/curated_problems_loader.dart';

export 'problem_repository_provider.dart';

/// Seeds the curated problem set the first time the provider is read.
///
/// Reading this provider triggers seeding. It is safe to call multiple times
/// because [CuratedProblemsLoader.seedIfNeeded] is a no-op when data exists.
final curatedSeedProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(problemRepositoryProvider);
  await CuratedProblemsLoader().seedIfNeeded(repo);
});

/// Provides the [ProblemBankController] / [ProblemBankState] pair.
///
/// The controller reads [problemRepositoryProvider] internally.
final problemBankControllerProvider =
    NotifierProvider<ProblemBankController, ProblemBankState>(
  ProblemBankController.new,
);
