import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_bank_providers.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_bank_state.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem_repository.dart';
import 'package:prepare_with_atlas/features/problem_bank/presentation/problem_bank_screen.dart';

/// Minimal [ProblemRepository] stub — always returns empty lists.
class _StubRepo implements ProblemRepository {
  @override
  Future<List<Problem>> getByExperienceLevel(ExperienceLevel level) async =>
      const [];

  @override
  Future<Problem?> getById(int id) async => null;

  @override
  Future<List<Problem>> searchByTitle(String query) async => const [];

  @override
  Future<int> insert(Problem problem) async => 0;

  @override
  Future<void> delete(int id) async {}

  @override
  Stream<List<Problem>> watchAll() => const Stream.empty();

  @override
  Future<int> count() async => 0;
}

/// Builds the screen with a fixed [ProblemBankState], bypassing the real DB.
Widget _buildScreen(ProblemBankState fixedState) {
  return ProviderScope(
    overrides: [
      problemRepositoryProvider.overrideWithValue(_StubRepo()),
      curatedSeedProvider.overrideWith((ref) async {}),
      // Override build() to return fixedState immediately.
      problemBankControllerProvider.overrideWithBuild(
        (ref, notifier) => fixedState,
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: ProblemsScreen()),
    ),
  );
}

ProblemBankState _stateWithProblems({
  List<Problem> easy = const [],
  List<Problem> medium = const [],
  List<Problem> hard = const [],
}) {
  return ProblemBankState(
    isLoading: false,
    sections: {
      ExperienceLevel.warmUp: easy,
      ExperienceLevel.advanced: medium,
      ExperienceLevel.expert: hard,
    },
  );
}

void main() {
  final easyProblem = Problem(
    id: 1,
    title: 'Design a URL shortener',
    description: 'A URL shortener problem',
    difficulty: 'easy',
    category: 'storage',
    createdAt: DateTime(2026, 4, 8),
  );

  group('ProblemsScreen', () {
    testWidgets('renders Warm-up Classics section header', (tester) async {
      await tester.pumpWidget(_buildScreen(_stateWithProblems()));
      await tester.pump();
      expect(find.text('Warm-up Classics'), findsOneWidget);
    });

    testWidgets('renders Advanced Systems section header', (tester) async {
      await tester.pumpWidget(_buildScreen(_stateWithProblems()));
      await tester.pump();
      expect(find.text('Advanced Systems'), findsOneWidget);
    });

    testWidgets('renders Expert Challenges section header', (tester) async {
      await tester.pumpWidget(_buildScreen(_stateWithProblems()));
      await tester.pump();
      expect(find.text('Expert Challenges'), findsOneWidget);
    });

    testWidgets('shows exact warm-up subtitle', (tester) async {
      await tester.pumpWidget(_buildScreen(_stateWithProblems()));
      await tester.pump();
      expect(
        find.text(
          'Recommended first — build foundations with familiar systems',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows exact advanced subtitle', (tester) async {
      await tester.pumpWidget(_buildScreen(_stateWithProblems()));
      await tester.pump();
      expect(
        find.text('For skilled developers — complex trade-offs and scaling'),
        findsOneWidget,
      );
    });

    testWidgets('shows exact expert subtitle', (tester) async {
      await tester.pumpWidget(_buildScreen(_stateWithProblems()));
      await tester.pump();
      expect(
        find.text(
          'For expert developers — ambiguous, cutting-edge problems',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'empty warmUp section shows placeholder message',
      (tester) async {
        await tester.pumpWidget(_buildScreen(_stateWithProblems()));
        await tester.pump();
        expect(
          find.textContaining('No Warm-up Classics problems yet'),
          findsOneWidget,
        );
      },
    );

    testWidgets('non-empty section shows problem tiles', (tester) async {
      await tester.pumpWidget(
        _buildScreen(_stateWithProblems(easy: [easyProblem])),
      );
      await tester.pump();
      expect(find.text('Design a URL shortener'), findsOneWidget);
    });
  });
}
