import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/application/stage_timer_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/timer_state.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/presentation/timer_display.dart';

class _RunningTimerController extends StageTimerController {
  @override
  TimerState build() => const TimerState.running(
        stage: InterviewStage.requirementGathering,
        remainingSeconds: 420,
        totalSeconds: 420,
      );
}

class _OvertimeTimerController extends StageTimerController {
  @override
  TimerState build() => const TimerState.overtime(
        stage: InterviewStage.requirementGathering,
        overtimeSeconds: 90,
      );
}

void main() {
  group('TimerDisplay', () {
    testWidgets('renders 07:00 for TimerRunning with 420 seconds', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stageTimerControllerProvider.overrideWith(
              _RunningTimerController.new,
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: TimerDisplay())),
        ),
      );
      expect(find.text('07:00'), findsOneWidget);
    });

    testWidgets('renders -01:30 for TimerOvertime with 90 overtime seconds', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stageTimerControllerProvider.overrideWith(
              _OvertimeTimerController.new,
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: TimerDisplay())),
        ),
      );
      expect(find.text('-01:30'), findsOneWidget);
    });
  });
}
