import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/evaluation/application/prompt_builder.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';

void main() {
  late PromptBuilder builder;
  late Problem problem;
  late List<StageNote> notes;

  setUp(() {
    builder = PromptBuilder();

    problem = Problem(
      id: 1,
      title: 'Design a URL Shortener',
      description: 'Build a system that takes long URLs and shortens them.',
      difficulty: 'medium',
      category: 'web',
      createdAt: DateTime(2026, 4, 9),
    );

    notes = [
      StageNote(
        id: 1,
        sessionId: 1,
        stage: InterviewStage.requirementGathering,
        timerDurationSeconds: 420,
        timeSpentSeconds: 390,
        notes: 'Clarified read/write ratio, DAU 100M',
        updatedAt: DateTime(2026, 4, 9),
      ),
      StageNote(
        id: 2,
        sessionId: 1,
        stage: InterviewStage.backOfEnvelopeEstimation,
        timerDurationSeconds: 300,
        timeSpentSeconds: 280,
        notes: 'QPS ~1160 reads, ~116 writes',
        updatedAt: DateTime(2026, 4, 9),
      ),
    ];
  });

  group('PromptBuilder.buildSystemPrompt', () {
    test('contains role instruction', () {
      final prompt = builder.buildSystemPrompt();
      expect(
        prompt.toLowerCase(),
        anyOf(
          contains('expert'),
          contains('evaluator'),
          contains('system design'),
        ),
      );
    });

    test('contains JSON output format instruction', () {
      final prompt = builder.buildSystemPrompt();
      expect(prompt, contains('JSON'));
    });

    test('contains all 7 scoring dimension keys', () {
      final prompt = builder.buildSystemPrompt();
      expect(prompt, contains('requirementsGathering'));
      expect(prompt, contains('estimationQuality'));
      expect(prompt, contains('highLevelDesign'));
      expect(prompt, contains('deepDiveQuality'));
      expect(prompt, contains('scalingAwareness'));
      expect(prompt, contains('communicationClarity'));
      expect(prompt, contains('overall'));
    });

    test('contains rubric with 0-3 poor', () {
      final prompt = builder.buildSystemPrompt();
      expect(prompt, contains('0'));
      expect(prompt, contains('3'));
      expect(prompt.toLowerCase(), contains('poor'));
    });

    test('contains rubric with 4-6 adequate', () {
      final prompt = builder.buildSystemPrompt();
      expect(prompt, contains('4'));
      expect(prompt, contains('6'));
      expect(prompt.toLowerCase(), contains('adequate'));
    });

    test('contains rubric with 7-10 strong', () {
      final prompt = builder.buildSystemPrompt();
      expect(prompt, contains('7'));
      expect(prompt, contains('10'));
      expect(prompt.toLowerCase(), contains('strong'));
    });
  });

  group('PromptBuilder.buildUserPrompt without reference', () {
    test('includes problem title', () {
      final prompt = builder.buildUserPrompt(problem: problem, notes: notes);
      expect(prompt, contains('Design a URL Shortener'));
    });

    test('includes problem description', () {
      final prompt = builder.buildUserPrompt(problem: problem, notes: notes);
      expect(prompt, contains('takes long URLs and shortens them'));
    });

    test('includes each stage note with stage name', () {
      final prompt = builder.buildUserPrompt(problem: problem, notes: notes);
      // Stage names should appear
      expect(
        prompt,
        anyOf(
          contains('Requirements'),
          contains('requirementGathering'),
          contains('Requirement'),
        ),
      );
      expect(prompt, contains('Clarified read/write ratio'));
    });

    test('includes time spent for each note', () {
      final prompt = builder.buildUserPrompt(problem: problem, notes: notes);
      // Should include time spent in some form (seconds or minutes)
      expect(prompt, anyOf(contains('390'), contains('6 min'), contains('6m')));
    });

    test('omits reference section when referenceAnswer is null', () {
      final prompt = builder.buildUserPrompt(problem: problem, notes: notes);
      expect(prompt.toLowerCase(), isNot(contains('reference solution')));
      expect(prompt.toLowerCase(), isNot(contains('reference answer')));
    });
  });

  group('PromptBuilder.buildUserPrompt with reference', () {
    test('includes reference answer section', () {
      final prompt = builder.buildUserPrompt(
        problem: problem,
        notes: notes,
        referenceAnswer: 'Use a hash function to shorten URLs.',
      );
      expect(prompt, anyOf(contains('Reference'), contains('reference')));
      expect(prompt, contains('Use a hash function to shorten URLs.'));
    });
  });

  group('PromptBuilder truncation', () {
    test('notes under 20000 chars pass through unchanged', () {
      const shortText = 'Short note content';
      final prompt = builder.buildUserPrompt(
        problem: problem,
        notes: [
          StageNote(
            id: 1,
            sessionId: 1,
            stage: InterviewStage.requirementGathering,
            timerDurationSeconds: 420,
            timeSpentSeconds: 390,
            notes: shortText,
            updatedAt: DateTime(2026, 4, 9),
          ),
        ],
      );
      expect(prompt, contains(shortText));
    });

    test('notes over 20000 chars are middle-truncated', () {
      // Build a note with 25000 chars
      final longText = 'A' * 25000;
      final note = StageNote(
        id: 1,
        sessionId: 1,
        stage: InterviewStage.requirementGathering,
        timerDurationSeconds: 420,
        timeSpentSeconds: 390,
        notes: longText,
        updatedAt: DateTime(2026, 4, 9),
      );
      final prompt = builder.buildUserPrompt(problem: problem, notes: [note]);
      expect(prompt, contains('[...content truncated for length...]'));
      // Should start with A's
      expect(prompt, contains('AAAA'));
    });
  });

  group('PromptBuilder.dimensionsForStage', () {
    test('requirementGathering maps to correct dimensions', () {
      final dims = builder.dimensionsForStage(
        InterviewStage.requirementGathering,
      );
      expect(dims, [
        'requirementsGathering',
        'communicationClarity',
        'overall',
      ]);
    });

    test('backOfEnvelopeEstimation maps to correct dimensions', () {
      final dims = builder.dimensionsForStage(
        InterviewStage.backOfEnvelopeEstimation,
      );
      expect(dims, ['estimationQuality', 'communicationClarity', 'overall']);
    });

    test('highLevelDesign maps to correct dimensions', () {
      final dims = builder.dimensionsForStage(InterviewStage.highLevelDesign);
      expect(dims, ['highLevelDesign', 'communicationClarity', 'overall']);
    });

    test('deepDive maps to correct dimensions', () {
      final dims = builder.dimensionsForStage(InterviewStage.deepDive);
      expect(dims, ['deepDiveQuality', 'communicationClarity', 'overall']);
    });

    test('scalingAndBottlenecks maps to correct dimensions', () {
      final dims = builder.dimensionsForStage(
        InterviewStage.scalingAndBottlenecks,
      );
      expect(dims, ['scalingAwareness', 'communicationClarity', 'overall']);
    });
  });

  group('PromptBuilder.buildSystemPrompt stage-to-dimension mapping', () {
    test('contains stage-to-dimension mapping table', () {
      final prompt = builder.buildSystemPrompt();
      expect(prompt, contains('Requirements'));
      expect(prompt, contains('requirementsGathering'));
      expect(prompt, contains('Estimation'));
      expect(prompt, contains('estimationQuality'));
      expect(prompt, contains('High-Level Design'));
      expect(prompt, contains('highLevelDesign'));
      expect(prompt, contains('Deep Dive'));
      expect(prompt, contains('deepDiveQuality'));
      expect(prompt, contains('Scaling'));
      expect(prompt, contains('scalingAwareness'));
    });

    test('each stage row in mapping table includes communicationClarity', () {
      final prompt = builder.buildSystemPrompt();
      expect(
        prompt,
        contains(
          '| Requirements | requirementsGathering, communicationClarity, overall |',
        ),
      );
      expect(
        prompt,
        contains(
          '| Estimation | estimationQuality, communicationClarity, overall |',
        ),
      );
      expect(
        prompt,
        contains(
          '| High-Level Design | highLevelDesign, communicationClarity, overall |',
        ),
      );
      expect(
        prompt,
        contains(
          '| Deep Dive | deepDiveQuality, communicationClarity, overall |',
        ),
      );
      expect(
        prompt,
        contains(
          '| Scaling | scalingAwareness, communicationClarity, overall |',
        ),
      );
    });
  });

  group('PromptBuilder.buildUserPrompt single-stage drill', () {
    test('single-stage requirementGathering lists exact dimensions', () {
      final prompt = builder.buildUserPrompt(
        problem: problem,
        notes: notes,
        isSingleStage: true,
        focusStage: InterviewStage.requirementGathering,
      );
      expect(prompt, contains('requirementsGathering'));
      expect(prompt, contains('communicationClarity'));
      expect(prompt, contains('overall'));
      expect(prompt, contains('Score ONLY these dimensions'));
      expect(prompt, isNot(contains('estimationQuality')));
    });

    test('single-stage backOfEnvelopeEstimation lists estimationQuality', () {
      final prompt = builder.buildUserPrompt(
        problem: problem,
        notes: notes,
        isSingleStage: true,
        focusStage: InterviewStage.backOfEnvelopeEstimation,
      );
      expect(prompt, contains('estimationQuality'));
      expect(prompt, contains('communicationClarity'));
      expect(prompt, contains('overall'));
      expect(prompt, isNot(contains('requirementsGathering')));
    });

    test('single-stage highLevelDesign lists highLevelDesign', () {
      final prompt = builder.buildUserPrompt(
        problem: problem,
        notes: notes,
        isSingleStage: true,
        focusStage: InterviewStage.highLevelDesign,
      );
      expect(prompt, contains('highLevelDesign'));
      expect(prompt, contains('communicationClarity'));
      expect(prompt, contains('overall'));
    });

    test('single-stage deepDive lists deepDiveQuality', () {
      final prompt = builder.buildUserPrompt(
        problem: problem,
        notes: notes,
        isSingleStage: true,
        focusStage: InterviewStage.deepDive,
      );
      expect(prompt, contains('deepDiveQuality'));
      expect(prompt, contains('communicationClarity'));
      expect(prompt, contains('overall'));
    });

    test('single-stage scalingAndBottlenecks lists scalingAwareness', () {
      final prompt = builder.buildUserPrompt(
        problem: problem,
        notes: notes,
        isSingleStage: true,
        focusStage: InterviewStage.scalingAndBottlenecks,
      );
      expect(prompt, contains('scalingAwareness'));
      expect(prompt, contains('communicationClarity'));
      expect(prompt, contains('overall'));
    });

    test('full session does not include single-stage instructions', () {
      final prompt = builder.buildUserPrompt(
        problem: problem,
        notes: notes,
        isSingleStage: false,
      );
      expect(prompt, isNot(contains('Score ONLY these dimensions')));
      expect(prompt, isNot(contains('single-stage drill')));
    });
  });
}
