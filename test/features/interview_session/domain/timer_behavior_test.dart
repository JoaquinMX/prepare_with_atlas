import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';

void main() {
  group('TimerBehavior', () {
    test('has exactly 3 values', () {
      expect(TimerBehavior.values.length, 3);
    });

    test('fromKey round-trips for all behaviors', () {
      for (final behavior in TimerBehavior.values) {
        expect(TimerBehavior.fromKey(behavior.key), behavior);
      }
    });

    test('keys are snake_case strings', () {
      expect(TimerBehavior.softWarning.key, 'soft_warning');
      expect(TimerBehavior.warningAutoAdvance.key, 'warning_auto_advance');
      expect(TimerBehavior.hardStop.key, 'hard_stop');
    });
  });
}
