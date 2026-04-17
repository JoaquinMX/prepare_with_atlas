import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/history/domain/progress_diff.dart';

void main() {
  final baseScorecard = <String, int>{
    'requirementsGathering': 6,
    'estimationQuality': 5,
    'highLevelDesign': 7,
    'deepDiveQuality': 4,
    'scalingAwareness': 5,
    'communicationClarity': 6,
    'overall': 6,
  };

  EvaluationResult makeEval({
    required String id,
    required Map<String, int> scorecard,
    int overall = 6,
  }) =>
      EvaluationResult(
        id: id,
        sessionId: '1',
        scorecard: scorecard,
        overallScore: overall,
        strengths: const [],
        improvements: const [],
        narrative: '',
        providerUsed: 'anthropic',
        modelUsed: 'claude-3-5-sonnet',
        createdAt: DateTime(2026, 4, 9),
      );

  group('ProgressDiff.from', () {
    test('computes positive delta for each improved dimension', () {
      final prior = makeEval(id: 'e1', scorecard: baseScorecard);
      final current = makeEval(
        id: 'e2',
        scorecard: {
          'requirementsGathering': 8,
          'estimationQuality': 7,
          'highLevelDesign': 9,
          'deepDiveQuality': 6,
          'scalingAwareness': 8,
          'communicationClarity': 9,
          'overall': 8,
        },
        overall: 8,
      );

      final diff = ProgressDiff.from(prior, current);

      expect(diff.scorecardDeltas['requirementsGathering'], 2);
      expect(diff.scorecardDeltas['estimationQuality'], 2);
      expect(diff.scorecardDeltas['highLevelDesign'], 2);
      expect(diff.scorecardDeltas['deepDiveQuality'], 2);
      expect(diff.scorecardDeltas['scalingAwareness'], 3);
      expect(diff.scorecardDeltas['communicationClarity'], 3);
    });

    test('computes negative delta for declined dimensions', () {
      final prior = makeEval(id: 'e1', scorecard: baseScorecard);
      final current = makeEval(
        id: 'e2',
        scorecard: {
          'requirementsGathering': 4,
          'estimationQuality': 3,
          'highLevelDesign': 5,
          'deepDiveQuality': 2,
          'scalingAwareness': 3,
          'communicationClarity': 4,
          'overall': 4,
        },
        overall: 4,
      );

      final diff = ProgressDiff.from(prior, current);

      expect(diff.scorecardDeltas['requirementsGathering'], -2);
      expect(diff.scorecardDeltas['overall'], -2);
    });

    test('delta is null for dimension absent in prior evaluation', () {
      final priorScorecard = Map<String, int>.from(baseScorecard)
        ..remove('scalingAwareness');
      final prior = makeEval(id: 'e1', scorecard: priorScorecard);
      final current = makeEval(id: 'e2', scorecard: baseScorecard, overall: 7);

      final diff = ProgressDiff.from(prior, current);

      expect(diff.scorecardDeltas['scalingAwareness'], isNull);
    });

    test('overallDelta is computed correctly', () {
      final prior = makeEval(id: 'e1', scorecard: baseScorecard);
      final current = makeEval(
        id: 'e2',
        scorecard: {
          ...baseScorecard,
          'overall': 9,
        },
        overall: 9,
      );

      final diff = ProgressDiff.from(prior, current);

      expect(diff.overallDelta, 3);
    });

    test('overallDelta is null when prior lacks overall score', () {
      final priorScorecard = Map<String, int>.from(baseScorecard)
        ..remove('overall');
      final prior = makeEval(id: 'e1', scorecard: priorScorecard);
      final current = makeEval(id: 'e2', scorecard: baseScorecard, overall: 8);

      final diff = ProgressDiff.from(prior, current);

      expect(diff.overallDelta, isNull);
    });

    test('improvedDimensions counts dimensions with delta > 0', () {
      final prior = makeEval(id: 'e1', scorecard: baseScorecard);
      final current = makeEval(
        id: 'e2',
        scorecard: {
          'requirementsGathering': 8, // +2
          'estimationQuality': 5, // 0
          'highLevelDesign': 6, // -1
          'deepDiveQuality': 5, // +1
          'scalingAwareness': 5, // 0
          'communicationClarity': 7, // +1
          'overall': 7, // +1
        },
        overall: 7,
      );

      final diff = ProgressDiff.from(prior, current);

      expect(diff.improvedDimensions, 4); // rg, dd, cc, overall
    });

    test('declinedDimensions counts dimensions with delta < 0', () {
      final prior = makeEval(id: 'e1', scorecard: baseScorecard);
      final current = makeEval(
        id: 'e2',
        scorecard: {
          'requirementsGathering': 4, // -2
          'estimationQuality': 3, // -2
          'highLevelDesign': 7, // 0
          'deepDiveQuality': 4, // 0
          'scalingAwareness': 4, // -1
          'communicationClarity': 6, // 0
          'overall': 5, // -1
        },
        overall: 5,
      );

      final diff = ProgressDiff.from(prior, current);

      expect(diff.declinedDimensions, 4); // rg, eq, sa, overall
    });

    test('references prior and current evaluations', () {
      final prior = makeEval(id: 'e1', scorecard: baseScorecard);
      final current = makeEval(id: 'e2', scorecard: baseScorecard, overall: 7);

      final diff = ProgressDiff.from(prior, current);

      expect(diff.priorEvaluation.id, 'e1');
      expect(diff.currentEvaluation.id, 'e2');
    });
  });
}
