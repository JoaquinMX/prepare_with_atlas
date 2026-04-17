import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';

void main() {
  group('ExperienceLevel', () {
    test('has exactly 3 values', () {
      expect(ExperienceLevel.values.length, 3);
    });

    group('fromDifficulty', () {
      test('maps easy to warmUp', () {
        expect(ExperienceLevel.fromDifficulty('easy'), ExperienceLevel.warmUp);
      });

      test('maps medium to advanced', () {
        expect(
          ExperienceLevel.fromDifficulty('medium'),
          ExperienceLevel.advanced,
        );
      });

      test('maps hard to expert', () {
        expect(
          ExperienceLevel.fromDifficulty('hard'),
          ExperienceLevel.expert,
        );
      });

      test('throws ArgumentError for unknown difficulty', () {
        expect(
          () => ExperienceLevel.fromDifficulty('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('displayLabel', () {
      test('warmUp displayLabel is Warm-up Classics', () {
        expect(ExperienceLevel.warmUp.displayLabel, 'Warm-up Classics');
      });

      test('advanced displayLabel is Advanced Systems', () {
        expect(ExperienceLevel.advanced.displayLabel, 'Advanced Systems');
      });

      test('expert displayLabel is Expert Challenges', () {
        expect(ExperienceLevel.expert.displayLabel, 'Expert Challenges');
      });
    });

    group('subtitle', () {
      test('warmUp subtitle matches spec', () {
        expect(
          ExperienceLevel.warmUp.subtitle,
          'Recommended first — build foundations with familiar systems',
        );
      });

      test('advanced subtitle matches spec', () {
        expect(
          ExperienceLevel.advanced.subtitle,
          'For skilled developers — complex trade-offs and scaling',
        );
      });

      test('expert subtitle matches spec', () {
        expect(
          ExperienceLevel.expert.subtitle,
          'For expert developers — ambiguous, cutting-edge problems',
        );
      });
    });

    group('difficultyKey', () {
      test('warmUp difficultyKey is easy', () {
        expect(ExperienceLevel.warmUp.difficultyKey, 'easy');
      });

      test('advanced difficultyKey is medium', () {
        expect(ExperienceLevel.advanced.difficultyKey, 'medium');
      });

      test('expert difficultyKey is hard', () {
        expect(ExperienceLevel.expert.difficultyKey, 'hard');
      });
    });
  });
}
