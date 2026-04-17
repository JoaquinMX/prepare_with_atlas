import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/settings/data/preferences_repository.dart';
import 'package:prepare_with_atlas/features/settings/domain/app_preferences.dart';

/// Manages [AppPreferences] state and coordinates persistence via
/// [PreferencesRepository].
class PreferencesController extends Notifier<AppPreferences> {
  @override
  AppPreferences build() {
    Future.microtask(_load);
    return const AppPreferences();
  }

  Future<void> _load() async {
    state = await ref.read(preferencesRepositoryProvider).load();
  }

  /// Toggles the light-theme flag and persists the change.
  Future<void> setLightTheme({required bool value}) async {
    state = state.copyWith(isLightTheme: value);
    await ref.read(preferencesRepositoryProvider).save(state);
  }

  /// Toggles the timer-sound flag and persists the change.
  Future<void> setTimerSoundEnabled({required bool value}) async {
    state = state.copyWith(timerSoundEnabled: value);
    await ref.read(preferencesRepositoryProvider).save(state);
  }

  /// Updates the default [TimerBehavior] and persists the change.
  Future<void> setDefaultTimerBehavior(TimerBehavior value) async {
    state = state.copyWith(defaultTimerBehavior: value);
    await ref.read(preferencesRepositoryProvider).save(state);
  }
}

/// Provides the singleton [PreferencesController] and its [AppPreferences]
/// state.
final preferencesControllerProvider =
    NotifierProvider<PreferencesController, AppPreferences>(
  PreferencesController.new,
);
