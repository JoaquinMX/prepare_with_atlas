import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';

void main() {
  final testCreatedAt = DateTime(2026, 4, 8);

  final testProblem = Problem(
    id: 1,
    title: 'Design a URL shortener',
    description: 'Design a URL shortening service.',
    difficulty: 'easy',
    category: 'storage',
    tags: const ['hashing', 'caching'],
    createdAt: testCreatedAt,
  );

  group('Problem', () {
    test('can be created with all required fields', () {
      expect(testProblem.id, 1);
      expect(testProblem.title, 'Design a URL shortener');
      expect(testProblem.description, 'Design a URL shortening service.');
      expect(testProblem.difficulty, 'easy');
      expect(testProblem.category, 'storage');
      expect(testProblem.tags, ['hashing', 'caching']);
      expect(testProblem.referenceSolution, isNull);
      expect(testProblem.isCurated, isTrue);
      expect(testProblem.isAiGenerated, isFalse);
    });

    test('copyWith works correctly', () {
      final updated = testProblem.copyWith(title: 'Updated Title');
      expect(updated.title, 'Updated Title');
      expect(updated.id, testProblem.id);
      expect(updated.difficulty, testProblem.difficulty);
    });

    test('JSON round-trip preserves all fields', () {
      final json = testProblem.toJson();
      final restored = Problem.fromJson(json);
      expect(restored.id, testProblem.id);
      expect(restored.title, testProblem.title);
      expect(restored.description, testProblem.description);
      expect(restored.difficulty, testProblem.difficulty);
      expect(restored.category, testProblem.category);
      expect(restored.tags, testProblem.tags);
      expect(restored.isCurated, testProblem.isCurated);
      expect(restored.isAiGenerated, testProblem.isAiGenerated);
    });

    group('experienceLevel getter', () {
      test('easy difficulty returns warmUp', () {
        expect(testProblem.experienceLevel, ExperienceLevel.warmUp);
      });

      test('medium difficulty returns advanced', () {
        final medium = testProblem.copyWith(difficulty: 'medium');
        expect(medium.experienceLevel, ExperienceLevel.advanced);
      });

      test('hard difficulty returns expert', () {
        final hard = testProblem.copyWith(difficulty: 'hard');
        expect(hard.experienceLevel, ExperienceLevel.expert);
      });
    });
  });
}
