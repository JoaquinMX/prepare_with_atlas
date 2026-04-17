import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/evaluation/application/response_parser.dart';

void main() {
  late ResponseParser parser;

  const sessionId = 'session-42';
  const providerUsed = 'anthropic';
  const modelUsed = 'claude-3-5-sonnet';

  const validJson = r'''
{
  "scorecard": {
    "requirementsGathering": 8,
    "estimationQuality": 6,
    "highLevelDesign": 7,
    "deepDiveQuality": 7,
    "scalingAwareness": 5,
    "communicationClarity": 8,
    "overall": 7
  },
  "strengths": ["Clear requirements", "Good high-level design"],
  "improvements": ["Improve estimation", "More detail in deep dive"],
  "narrative": "## Overall Assessment\n\nSolid performance overall.",
  "referenceComparison": null
}
''';

  setUp(() {
    parser = ResponseParser();
  });

  group('ResponseParser valid JSON', () {
    test('parses valid JSON string into EvaluationResult', () {
      final result = parser.parse(
        raw: validJson,
        sessionId: sessionId,
        providerUsed: providerUsed,
        modelUsed: modelUsed,
      );
      expect(result.sessionId, sessionId);
      expect(result.providerUsed, providerUsed);
      expect(result.modelUsed, modelUsed);
      expect(result.scorecard['requirementsGathering'], 8);
      expect(result.scorecard['estimationQuality'], 6);
      expect(result.scorecard['highLevelDesign'], 7);
      expect(result.overallScore, 7);
      expect(result.strengths, hasLength(2));
      expect(result.improvements, hasLength(2));
      expect(result.narrative, contains('Solid performance'));
      expect(result.referenceComparison, isNull);
      expect(result.rawResponse, validJson);
    });

    test('parses referenceComparison when present', () {
      const jsonWithRef = '''
{
  "scorecard": {
    "requirementsGathering": 8,
    "estimationQuality": 6,
    "highLevelDesign": 7,
    "deepDiveQuality": 7,
    "scalingAwareness": 5,
    "communicationClarity": 8,
    "overall": 7
  },
  "strengths": ["Good"],
  "improvements": ["Better"],
  "narrative": "Narrative",
  "referenceComparison": "Compared to reference..."
}
''';
      final result = parser.parse(
        raw: jsonWithRef,
        sessionId: sessionId,
        providerUsed: providerUsed,
        modelUsed: modelUsed,
      );
      expect(result.referenceComparison, 'Compared to reference...');
    });

    test('scores outside 0-10 are clamped', () {
      const jsonWithBadScores = '''
{
  "scorecard": {
    "requirementsGathering": 15,
    "estimationQuality": -2,
    "highLevelDesign": 7,
    "deepDiveQuality": 7,
    "scalingAwareness": 5,
    "communicationClarity": 8,
    "overall": 20
  },
  "strengths": ["Good"],
  "improvements": ["Better"],
  "narrative": "Narrative",
  "referenceComparison": null
}
''';
      final result = parser.parse(
        raw: jsonWithBadScores,
        sessionId: sessionId,
        providerUsed: providerUsed,
        modelUsed: modelUsed,
      );
      expect(result.scorecard['requirementsGathering'], 10);
      expect(result.scorecard['estimationQuality'], 0);
      expect(result.overallScore, 10);
    });

    test('missing scorecard dimensions are omitted (shown as N/A)', () {
      const jsonMissingDimension = '''
{
  "scorecard": {
    "requirementsGathering": 8,
    "estimationQuality": 6,
    "highLevelDesign": 7,
    "deepDiveQuality": 7,
    "overall": 7
  },
  "strengths": ["Good"],
  "improvements": ["Better"],
  "narrative": "Narrative",
  "referenceComparison": null
}
''';
      final result = parser.parse(
        raw: jsonMissingDimension,
        sessionId: sessionId,
        providerUsed: providerUsed,
        modelUsed: modelUsed,
      );
      // Absent dimensions are omitted from the map so ScoreCardWidget shows N/A
      expect(result.scorecard.containsKey('scalingAwareness'), isFalse);
      expect(result.scorecard.containsKey('communicationClarity'), isFalse);
      // Present dimensions are still parsed correctly
      expect(result.scorecard['requirementsGathering'], 8);
    });

    test('extra scorecard dimensions are ignored', () {
      const jsonWithExtra = '''
{
  "scorecard": {
    "requirementsGathering": 8,
    "estimationQuality": 6,
    "highLevelDesign": 7,
    "deepDiveQuality": 7,
    "scalingAwareness": 5,
    "communicationClarity": 8,
    "overall": 7,
    "extraDimension": 9,
    "anotherExtra": 3
  },
  "strengths": ["Good"],
  "improvements": ["Better"],
  "narrative": "Narrative",
  "referenceComparison": null
}
''';
      final result = parser.parse(
        raw: jsonWithExtra,
        sessionId: sessionId,
        providerUsed: providerUsed,
        modelUsed: modelUsed,
      );
      expect(result.scorecard.containsKey('extraDimension'), isFalse);
      expect(result.scorecard.containsKey('anotherExtra'), isFalse);
    });
  });

  group('ResponseParser with JSON wrapped in markdown', () {
    test('parses JSON wrapped in markdown code fence', () {
      const wrappedJson = '''
Here is my evaluation:

```json
{
  "scorecard": {
    "requirementsGathering": 8,
    "estimationQuality": 6,
    "highLevelDesign": 7,
    "deepDiveQuality": 7,
    "scalingAwareness": 5,
    "communicationClarity": 8,
    "overall": 7
  },
  "strengths": ["Good"],
  "improvements": ["Better"],
  "narrative": "Narrative",
  "referenceComparison": null
}
```
''';
      final result = parser.parse(
        raw: wrappedJson,
        sessionId: sessionId,
        providerUsed: providerUsed,
        modelUsed: modelUsed,
      );
      expect(result.scorecard['requirementsGathering'], 8);
    });
  });

  group('ResponseParser regex fallback', () {
    test('regex fallback extracts "key: N" pattern', () {
      const malformedWithHints = '''
I evaluated the candidate and here are the scores:

requirementsGathering: 7
estimationQuality: 5
highLevelDesign: 8
deepDiveQuality: 6
scalingAwareness: 4
communicationClarity: 7
overall: 6

Strengths: Good design sense.
Improvements: Need more depth.
''';
      final result = parser.parse(
        raw: malformedWithHints,
        sessionId: sessionId,
        providerUsed: providerUsed,
        modelUsed: modelUsed,
      );
      expect(result.scorecard['requirementsGathering'], 7);
      expect(result.scorecard['highLevelDesign'], 8);
      expect(result.overallScore, 6);
    });

    test('regex fallback extracts "Requirements Gathering: N/10" pattern', () {
      const naturalLanguageScores = '''
Requirements Gathering: 8/10
Estimation Quality: 6/10
High Level Design: 7/10
Deep Dive Quality: 7/10
Scaling Awareness: 5/10
Communication Clarity: 8/10
Overall: 7/10
''';
      final result = parser.parse(
        raw: naturalLanguageScores,
        sessionId: sessionId,
        providerUsed: providerUsed,
        modelUsed: modelUsed,
      );
      // The overall score should be extracted
      expect(result.overallScore, inInclusiveRange(0, 10));
    });
  });

  group('ResponseParser total failure', () {
    test('completely unparseable input throws EvaluationParseException', () {
      expect(
        () => parser.parse(
          raw: 'This is just random text with no scores anywhere.',
          sessionId: sessionId,
          providerUsed: providerUsed,
          modelUsed: modelUsed,
        ),
        throwsA(isA<EvaluationParseException>()),
      );
    });
  });
}
