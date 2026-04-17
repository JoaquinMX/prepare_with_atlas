import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

void main() {
  group('TimerConfig', () {
    test('has default warningThresholdSeconds of 60', () {
      const config = TimerConfig();
      expect(config.warningThresholdSeconds, 60);
    });

    test('has default gracePeriodSeconds of 30', () {
      const config = TimerConfig();
      expect(config.gracePeriodSeconds, 30);
    });

    test('durationFor highLevelDesign returns 720 with no override', () {
      const config = TimerConfig();
      expect(config.durationFor(InterviewStage.highLevelDesign), 720);
    });

    test('durationFor highLevelDesign returns 600 when override provided', () {
      const config = TimerConfig(
        stageDurationsSeconds: {'highLevelDesign': 600},
      );
      expect(config.durationFor(InterviewStage.highLevelDesign), 600);
    });
  });
}
