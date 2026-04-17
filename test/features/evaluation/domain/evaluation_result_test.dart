import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';

void main() {
  final createdAt = DateTime(2026, 4, 9, 12);

  const requiredKeys = [
    'requirementsGathering',
    'estimationQuality',
    'highLevelDesign',
    'deepDiveQuality',
    'scalingAwareness',
    'communicationClarity',
    'overall',
  ];

  EvaluationResult makeResult({
    Map<String, int>? scorecard,
    int overallScore = 7,
  }) =>
      EvaluationResult(
        id: 'eval-1',
        sessionId: 'session-42',
        scorecard: scorecard ??
            {
              'requirementsGathering': 8,
              'estimationQuality': 6,
              'highLevelDesign': 7,
              'deepDiveQuality': 7,
              'scalingAwareness': 6,
              'communicationClarity': 8,
              'overall': 7,
            },
        overallScore: overallScore,
        strengths: const ['Good requirements', 'Clear communication'],
        improvements: const ['Improve scaling discussion'],
        narrative: '## Overall\nSolid performance.',
        providerUsed: 'anthropic',
        modelUsed: 'claude-3-5-sonnet',
        createdAt: createdAt,
      );

  group('EvaluationResult', () {
    test('creates with all required fields', () {
      final result = makeResult();
      expect(result.id, 'eval-1');
      expect(result.sessionId, 'session-42');
      expect(result.overallScore, 7);
      expect(result.strengths, hasLength(2));
      expect(result.improvements, hasLength(1));
      expect(result.narrative, contains('## Overall'));
      expect(result.providerUsed, 'anthropic');
      expect(result.modelUsed, 'claude-3-5-sonnet');
      expect(result.createdAt, createdAt);
      expect(result.referenceComparison, isNull);
      expect(result.rawResponse, isNull);
    });

    test('optional fields can be set', () {
      final result = makeResult().copyWith(
        referenceComparison: 'Compare to reference...',
        rawResponse: '{"raw": true}',
      );
      expect(result.referenceComparison, 'Compare to reference...');
      expect(result.rawResponse, '{"raw": true}');
    });

    test('scorecard contains all 7 required dimension keys', () {
      final result = makeResult();
      for (final key in requiredKeys) {
        expect(
          result.scorecard.containsKey(key),
          isTrue,
          reason: 'Missing key: $key',
        );
      }
    });

    test('overallScore at 0 is valid', () {
      final result = makeResult(overallScore: 0);
      expect(result.overallScore, 0);
    });

    test('overallScore at 10 is valid', () {
      final result = makeResult(overallScore: 10);
      expect(result.overallScore, 10);
    });

    test('JSON serialization round-trip preserves all fields', () {
      final result = makeResult().copyWith(
        referenceComparison: 'Some comparison',
        rawResponse: '{"key":"val"}',
      );
      final json = result.toJson();
      final restored = EvaluationResult.fromJson(json);

      expect(restored.id, result.id);
      expect(restored.sessionId, result.sessionId);
      expect(restored.scorecard, result.scorecard);
      expect(restored.overallScore, result.overallScore);
      expect(restored.strengths, result.strengths);
      expect(restored.improvements, result.improvements);
      expect(restored.narrative, result.narrative);
      expect(restored.referenceComparison, result.referenceComparison);
      expect(restored.providerUsed, result.providerUsed);
      expect(restored.modelUsed, result.modelUsed);
      expect(restored.rawResponse, result.rawResponse);
      expect(restored.createdAt, result.createdAt);
    });

    test('scorecard values are preserved in JSON round-trip', () {
      final result = makeResult();
      final json = result.toJson();
      final restored = EvaluationResult.fromJson(json);

      for (final key in requiredKeys) {
        expect(restored.scorecard[key], result.scorecard[key]);
      }
    });

    test('copyWith produces updated model', () {
      final result = makeResult();
      final updated = result.copyWith(overallScore: 9);
      expect(updated.overallScore, 9);
      expect(updated.id, result.id);
    });
  });
}
