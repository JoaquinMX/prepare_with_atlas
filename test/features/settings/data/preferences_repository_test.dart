import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/settings/data/preferences_repository.dart';
import 'package:prepare_with_atlas/features/settings/domain/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PreferencesRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load() returns defaults when nothing is stored', () async {
      final sharedPrefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(sharedPrefs);

      final prefs = await repo.load();

      expect(prefs, const AppPreferences());
    });

    test('save() then load() returns the saved value', () async {
      final sharedPrefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(sharedPrefs);

      const toSave = AppPreferences(
        isLightTheme: true,
        timerSoundEnabled: false,
        defaultTimerBehavior: TimerBehavior.hardStop,
      );
      await repo.save(toSave);
      final loaded = await repo.load();

      expect(loaded.isLightTheme, isTrue);
      expect(loaded.timerSoundEnabled, isFalse);
      expect(loaded.defaultTimerBehavior, TimerBehavior.hardStop);
    });

    test('save() then load() correctly persists warningAutoAdvance', () async {
      final sharedPrefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(sharedPrefs);

      const toSave = AppPreferences(
        defaultTimerBehavior: TimerBehavior.warningAutoAdvance,
      );
      await repo.save(toSave);
      final loaded = await repo.load();

      expect(loaded.defaultTimerBehavior, TimerBehavior.warningAutoAdvance);
    });

    test('corrupted JSON in storage returns defaults without crash', () async {
      SharedPreferences.setMockInitialValues({
        'app_preferences': 'not-valid-json{{{',
      });
      final sharedPrefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(sharedPrefs);

      final prefs = await repo.load();

      expect(prefs, const AppPreferences());
    });
  });
}
