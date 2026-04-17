import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/application/stage_timer_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/timer_state.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

void main() {
  group('StageTimerController', () {
    late ProviderContainer container;
    late StageTimerController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(stageTimerControllerProvider.notifier);
    });
    tearDown(() => container.dispose());

    test('initial state is idle', () {
      expect(container.read(stageTimerControllerProvider), isA<TimerIdle>());
    });

    test('startStage sets running state with correct remaining', () {
      controller.startStage(
        InterviewStage.requirementGathering,
        const TimerConfig(),
        TimerBehavior.softWarning,
      );
      final s =
          container.read(stageTimerControllerProvider) as TimerRunning;
      expect(s.remainingSeconds, 420); // 7 min * 60
    });

    test('onTick decrements remaining', () {
      controller
        ..startStage(
          InterviewStage.requirementGathering,
          const TimerConfig(),
          TimerBehavior.softWarning,
        )
        ..onTick();
      final s =
          container.read(stageTimerControllerProvider) as TimerRunning;
      expect(s.remainingSeconds, 419);
    });

    test('transitions to warning at threshold', () {
      const config = TimerConfig(
        warningThresholdSeconds: 5,
        stageDurationsSeconds: {'requirementGathering': 10},
      );
      controller.startStage(
        InterviewStage.requirementGathering,
        config,
        TimerBehavior.softWarning,
      );
      // tick 5 times: 10 → 9 → 8 → 7 → 6 → 5 (warning threshold)
      for (var i = 0; i < 5; i++) {
        controller.onTick();
      }
      expect(
        container.read(stageTimerControllerProvider),
        isA<TimerWarning>(),
      );
    });

    test('soft warning: goes to overtime at 0', () {
      const config = TimerConfig(
        stageDurationsSeconds: {'requirementGathering': 2},
      );
      controller
        ..startStage(
          InterviewStage.requirementGathering,
          config,
          TimerBehavior.softWarning,
        )
        ..onTick() // 2→1
        ..onTick(); // 1→0 → overtime
      expect(
        container.read(stageTimerControllerProvider),
        isA<TimerOvertime>(),
      );
    });

    test('hard stop: stage ends at 0', () {
      const config = TimerConfig(
        stageDurationsSeconds: {'requirementGathering': 1},
      );
      controller
        ..startStage(
          InterviewStage.requirementGathering,
          config,
          TimerBehavior.hardStop,
        )
        ..onTick(); // 1→0 → stageEnded
      expect(
        container.read(stageTimerControllerProvider),
        isA<TimerStageEnded>(),
      );
    });

    test('auto advance: grace period starts at 0', () {
      const config = TimerConfig(
        gracePeriodSeconds: 3,
        stageDurationsSeconds: {'requirementGathering': 1},
      );
      controller
        ..startStage(
          InterviewStage.requirementGathering,
          config,
          TimerBehavior.warningAutoAdvance,
        )
        ..onTick(); // → gracePeriod(3)
      expect(
        container.read(stageTimerControllerProvider),
        isA<TimerGracePeriod>(),
      );
    });

    test('auto advance: grace period ticks to stageEnded', () {
      const config = TimerConfig(
        gracePeriodSeconds: 2,
        stageDurationsSeconds: {'requirementGathering': 1},
      );
      controller
        ..startStage(
          InterviewStage.requirementGathering,
          config,
          TimerBehavior.warningAutoAdvance,
        )
        ..onTick() // → gracePeriod(2)
        ..onTick() // → gracePeriod(1)
        ..onTick(); // → stageEnded
      expect(
        container.read(stageTimerControllerProvider),
        isA<TimerStageEnded>(),
      );
    });

    test('pause stops decrementing', () {
      const config = TimerConfig(
        stageDurationsSeconds: {'requirementGathering': 10},
      );
      controller
        ..startStage(
          InterviewStage.requirementGathering,
          config,
          TimerBehavior.softWarning,
        )
        ..onTick() // 10→9
        ..pause()
        ..onTick(); // should be no-op while paused
      expect(
        container.read(stageTimerControllerProvider),
        isA<TimerPaused>(),
      );
      final s =
          container.read(stageTimerControllerProvider) as TimerPaused;
      expect(s.remainingSeconds, 9); // still 9
    });

    test('resume after pause continues decrementing', () {
      // Use 200s duration and 5s threshold so 1 tick stays in Running state.
      const config = TimerConfig(
        warningThresholdSeconds: 5,
        stageDurationsSeconds: {'requirementGathering': 200},
      );
      controller
        ..startStage(
          InterviewStage.requirementGathering,
          config,
          TimerBehavior.softWarning,
        )
        ..onTick() // 200→199 (still Running)
        ..pause()
        ..resume()
        ..onTick(); // 199→198
      final s =
          container.read(stageTimerControllerProvider) as TimerRunning;
      expect(s.remainingSeconds, 198);
    });

    test('skipStage sets stageEnded', () {
      controller
        ..startStage(
          InterviewStage.highLevelDesign,
          const TimerConfig(),
          TimerBehavior.softWarning,
        )
        ..skipStage();
      expect(
        container.read(stageTimerControllerProvider),
        isA<TimerStageEnded>(),
      );
    });

    test('reset returns to idle', () {
      controller
        ..startStage(
          InterviewStage.highLevelDesign,
          const TimerConfig(),
          TimerBehavior.softWarning,
        )
        ..reset();
      expect(
        container.read(stageTimerControllerProvider),
        isA<TimerIdle>(),
      );
    });
  });
}
