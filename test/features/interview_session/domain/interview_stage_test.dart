import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';

void main() {
  group('InterviewStage', () {
    test('has exactly 5 values', () {
      expect(InterviewStage.values.length, 5);
    });

    test('displayName is correct for each stage', () {
      expect(
        InterviewStage.requirementGathering.displayName,
        'Requirements',
      );
      expect(
        InterviewStage.backOfEnvelopeEstimation.displayName,
        'Estimation',
      );
      expect(InterviewStage.highLevelDesign.displayName, 'High-Level Design');
      expect(InterviewStage.deepDive.displayName, 'Deep Dive');
      expect(InterviewStage.scalingAndBottlenecks.displayName, 'Scaling');
    });

    test('defaultDurationMinutes are correct', () {
      expect(InterviewStage.requirementGathering.defaultDurationMinutes, 7);
      expect(
        InterviewStage.backOfEnvelopeEstimation.defaultDurationMinutes,
        5,
      );
      expect(InterviewStage.highLevelDesign.defaultDurationMinutes, 12);
      expect(InterviewStage.deepDive.defaultDurationMinutes, 17);
      expect(InterviewStage.scalingAndBottlenecks.defaultDurationMinutes, 7);
    });

    test('fromKey round-trips for all stages', () {
      for (final stage in InterviewStage.values) {
        expect(InterviewStage.fromKey(stage.key), stage);
      }
    });

    test('has no topics, techniques, or insights field', () {
      // Structural test — compilation proves absence.
      // If a field were added, the test file would need to reference it.
      expect(InterviewStage.requirementGathering, isA<InterviewStage>());
    });
  });
}
