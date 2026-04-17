import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/settings/domain/app_preferences.dart';

void main() {
  group('AppPreferences', () {
    test('construction with defaults', () {
      const prefs = AppPreferences();

      expect(prefs.isLightTheme, isFalse);
      expect(prefs.timerSoundEnabled, isTrue);
      expect(prefs.defaultTimerBehavior, TimerBehavior.softWarning);
    });

    test('construction with custom values', () {
      const prefs = AppPreferences(
        isLightTheme: true,
        timerSoundEnabled: false,
        defaultTimerBehavior: TimerBehavior.hardStop,
      );

      expect(prefs.isLightTheme, isTrue);
      expect(prefs.timerSoundEnabled, isFalse);
      expect(prefs.defaultTimerBehavior, TimerBehavior.hardStop);
    });

    test('JSON serialization round-trip with defaults', () {
      const original = AppPreferences();
      final json = original.toJson();
      final restored = AppPreferences.fromJson(json);

      expect(restored.isLightTheme, original.isLightTheme);
      expect(restored.timerSoundEnabled, original.timerSoundEnabled);
      expect(restored.defaultTimerBehavior, original.defaultTimerBehavior);
    });

    test('JSON serialization round-trip with custom values', () {
      const original = AppPreferences(
        isLightTheme: true,
        timerSoundEnabled: false,
        defaultTimerBehavior: TimerBehavior.warningAutoAdvance,
      );
      final json = original.toJson();
      final restored = AppPreferences.fromJson(json);

      expect(restored.isLightTheme, original.isLightTheme);
      expect(restored.timerSoundEnabled, original.timerSoundEnabled);
      expect(restored.defaultTimerBehavior, original.defaultTimerBehavior);
    });

    test('copyWith produces updated instance', () {
      const original = AppPreferences();
      final updated = original.copyWith(isLightTheme: true);

      expect(updated.isLightTheme, isTrue);
      expect(updated.timerSoundEnabled, isTrue);
    });

    test('equality holds for identical instances', () {
      const a = AppPreferences();
      const b = AppPreferences();
      expect(a, equals(b));
    });
  });
}
