import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/settings/application/preferences_controller.dart';
import 'package:prepare_with_atlas/features/settings/data/preferences_repository.dart';
import 'package:prepare_with_atlas/features/settings/domain/app_preferences.dart';

import 'preferences_controller_test.mocks.dart';

@GenerateMocks([PreferencesRepository])
void main() {
  late MockPreferencesRepository mockRepo;

  setUp(() {
    mockRepo = MockPreferencesRepository();
    when(mockRepo.load()).thenAnswer((_) async => const AppPreferences());
    when(mockRepo.save(any)).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer({AppPreferences? loadResult}) {
    if (loadResult != null) {
      when(mockRepo.load()).thenAnswer((_) async => loadResult);
    }
    final container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    // Trigger the notifier build.
    container.read(preferencesControllerProvider);
    return container;
  }

  group('PreferencesController', () {
    test('initial state has default values before load completes', () {
      final container = makeContainer();
      final state = container.read(preferencesControllerProvider);

      // Before the microtask resolves, state is the default.
      expect(state.isLightTheme, isFalse);
      expect(state.timerSoundEnabled, isTrue);
      expect(state.defaultTimerBehavior, TimerBehavior.softWarning);
    });

    test('state is loaded from repository after build', () async {
      const stored = AppPreferences(
        isLightTheme: true,
        timerSoundEnabled: false,
        defaultTimerBehavior: TimerBehavior.hardStop,
      );
      final container = makeContainer(loadResult: stored);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(preferencesControllerProvider);
      expect(state.isLightTheme, isTrue);
      expect(state.timerSoundEnabled, isFalse);
      expect(state.defaultTimerBehavior, TimerBehavior.hardStop);
    });

    test('setLightTheme(true) updates state and saves to repo', () async {
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);

      await container
          .read(preferencesControllerProvider.notifier)
          .setLightTheme(value: true);

      final state = container.read(preferencesControllerProvider);
      expect(state.isLightTheme, isTrue);
      verify(mockRepo.save(any)).called(1);
    });

    test('setTimerSoundEnabled(false) updates state and saves to repo',
        () async {
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);

      await container
          .read(preferencesControllerProvider.notifier)
          .setTimerSoundEnabled(value: false);

      final state = container.read(preferencesControllerProvider);
      expect(state.timerSoundEnabled, isFalse);
      verify(mockRepo.save(any)).called(1);
    });

    test(
        'setDefaultTimerBehavior(hardStop) updates state and saves to repo',
        () async {
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);

      await container
          .read(preferencesControllerProvider.notifier)
          .setDefaultTimerBehavior(TimerBehavior.hardStop);

      final state = container.read(preferencesControllerProvider);
      expect(state.defaultTimerBehavior, TimerBehavior.hardStop);
      verify(mockRepo.save(any)).called(1);
    });
  });
}
