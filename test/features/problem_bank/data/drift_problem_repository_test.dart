import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart';
import 'package:prepare_with_atlas/features/problem_bank/data/drift_problem_repository.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart'
    as domain;

domain.Problem _makeProblem({
  int id = 0,
  String title = 'Test Problem',
  String difficulty = 'easy',
  String description = 'A test problem description',
  String category = 'storage',
}) {
  return domain.Problem(
    id: id,
    title: title,
    description: description,
    difficulty: difficulty,
    category: category,
    createdAt: DateTime(2026, 4, 8),
  );
}

void main() {
  late AppDatabase db;
  late DriftProblemRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftProblemRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftProblemRepository', () {
    test('getByExperienceLevel returns problems matching difficulty', () async {
      await repository.insert(_makeProblem(title: 'Easy One'));

      final problems = await repository.getByExperienceLevel(
        ExperienceLevel.warmUp,
      );
      expect(problems.length, 1);
      expect(problems.first.title, 'Easy One');
    });

    test(
      'getByExperienceLevel does NOT return problems of other difficulty',
      () async {
        await repository.insert(
          _makeProblem(difficulty: 'medium', title: 'Medium One'),
        );

        final problems = await repository.getByExperienceLevel(
          ExperienceLevel.warmUp,
        );
        expect(problems, isEmpty);
      },
    );

    test(
      'searchByTitle returns problems with matching title (case-insensitive)',
      () async {
        await repository.insert(
          _makeProblem(title: 'Design a URL shortener'),
        );
        await repository.insert(_makeProblem(title: 'Design WhatsApp'));

        final results = await repository.searchByTitle('url');
        expect(results.length, 1);
        expect(results.first.title, 'Design a URL shortener');
      },
    );

    test('searchByTitle does NOT search description', () async {
      await repository.insert(
        _makeProblem(
          title: 'Design a cache',
          description: 'This problem involves url redirection',
        ),
      );

      final results = await repository.searchByTitle('url');
      expect(results, isEmpty);
    });

    test('delete removes the problem', () async {
      final id = await repository.insert(
        _makeProblem(title: 'To Delete'),
      );
      await repository.delete(id);

      final all = await repository.getByExperienceLevel(
        ExperienceLevel.warmUp,
      );
      expect(all, isEmpty);
    });

    test('count returns correct number of problems', () async {
      expect(await repository.count(), 0);

      await repository.insert(_makeProblem());
      await repository.insert(_makeProblem(difficulty: 'medium'));
      await repository.insert(_makeProblem(difficulty: 'hard'));

      expect(await repository.count(), 3);
    });

    test('getById returns correct problem', () async {
      final id = await repository.insert(
        _makeProblem(title: 'Specific Problem'),
      );
      final problem = await repository.getById(id);

      expect(problem, isNotNull);
      expect(problem!.title, 'Specific Problem');
    });

    test('getById returns null for non-existent id', () async {
      final problem = await repository.getById(9999);
      expect(problem, isNull);
    });
  });
}
