import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';

part 'app_preferences.freezed.dart';
part 'app_preferences.g.dart';

/// Persisted user-level preferences for PrepareWithAtlas.
@freezed
abstract class AppPreferences with _$AppPreferences {
  /// Creates an [AppPreferences] with the given fields.
  const factory AppPreferences({
    /// Whether the app is currently in light mode.
    @Default(false) bool isLightTheme,

    /// Whether timer sound effects are enabled.
    @Default(true) bool timerSoundEnabled,

    /// The default timer behavior applied to new interview sessions.
    @Default(TimerBehavior.softWarning) TimerBehavior defaultTimerBehavior,
  }) = _AppPreferences;

  /// Deserializes an [AppPreferences] from [json].
  factory AppPreferences.fromJson(Map<String, dynamic> json) =>
      _$AppPreferencesFromJson(json);
}
