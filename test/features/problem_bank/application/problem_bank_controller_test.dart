import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_bank_providers.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem_repository.dart';

/// A fake in-memory implementation of [ProblemRepository] for testing.
class FakeProblemRepository implements ProblemRepository {
  final List<Problem> _problems = [];
  int _nextId = 1;

  @override
  Future<List<Problem>> getByExperienceLevel(ExperienceLevel level) async {
    return _problems
        .where((p) => p.difficulty == level.difficultyKey)
        .toList();
  }

  @override
  Future<Problem?> getById(int id) async {
    try {
      return _problems.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Problem>> searchByTitle(String query) async {
    final lower = query.toLowerCase();
    return _problems
        .where((p) => p.title.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Future<int> insert(Problem problem) async {
    final id = _nextId++;
    _problems.add(problem.copyWith(id: id));
    return id;
  }

  @override
  Future<void> delete(int id) async {
    _problems.removeWhere((p) => p.id == id);
  }

  @override
  Stream<List<Problem>> watchAll() =>
      Stream.value(List<Problem>.unmodifiable(_problems));

  @override
  Future<int> count() async => _problems.length;

  /// Adds a problem directly without auto-increment for testing convenience.
  void addProblem(Problem problem) => _problems.add(problem);
}

Problem _makeProblem({
  int id = 1,
  String title = 'Test Problem',
  String difficulty = 'easy',
}) {
  return Problem(
    id: id,
    title: title,
    description: 'Description',
    difficulty: difficulty,
    category: 'storage',
    createdAt: DateTime(2026, 4, 8),
  );
}

/// Creates a [ProviderContainer] with [repo] injected as the repository.
ProviderContainer _makeContainer(FakeProblemRepository repo) {
  return ProviderContainer(
    overrides: [
      problemRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  group('ProblemBankController', () {
    test('initializes with 3 sections (one per experience level)', () async {
      final repo = FakeProblemRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(problemBankControllerProvider);
      // Wait for async _loadAll to complete.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(problemBankControllerProvider);
      expect(state.sections.keys, containsAll(ExperienceLevel.values));
    });

    test('loads problems into correct sections after init', () async {
      final repo = FakeProblemRepository()
        ..addProblem(_makeProblem(title: 'URL Shortener'))
        ..addProblem(
          _makeProblem(id: 2, title: 'WhatsApp', difficulty: 'medium'),
        );

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(problemBankControllerProvider);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(problemBankControllerProvider);
      expect(state.sections[ExperienceLevel.warmUp]!.length, 1);
      expect(
        state.sections[ExperienceLevel.warmUp]!.first.title,
        'URL Shortener',
      );
      expect(state.sections[ExperienceLevel.advanced]!.length, 1);
    });

    test('search filters sections by title (case insensitive)', () async {
      final repo = FakeProblemRepository()
        ..addProblem(_makeProblem(title: 'Design a URL shortener'))
        ..addProblem(_makeProblem(id: 2, title: 'Design WhatsApp'));

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(problemBankControllerProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(problemBankControllerProvider.notifier)
          .search('url');

      final warmUpProblems = container
          .read(problemBankControllerProvider)
          .sections[ExperienceLevel.warmUp]!;
      expect(warmUpProblems.length, 1);
      expect(warmUpProblems.first.title, 'Design a URL shortener');
    });

    test('clearSearch restores full unfiltered state', () async {
      final repo = FakeProblemRepository()
        ..addProblem(_makeProblem(title: 'Design a URL shortener'))
        ..addProblem(_makeProblem(id: 2, title: 'Design WhatsApp'));

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(problemBankControllerProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(problemBankControllerProvider.notifier)
          .search('url');
      expect(
        container
            .read(problemBankControllerProvider)
            .sections[ExperienceLevel.warmUp]!
            .length,
        1,
      );

      container
          .read(problemBankControllerProvider.notifier)
          .clearSearch();
      await Future<void>.delayed(Duration.zero);

      expect(
        container
            .read(problemBankControllerProvider)
            .sections[ExperienceLevel.warmUp]!
            .length,
        2,
      );
    });
  });
}
