/// Governs what happens when a stage timer reaches zero.
enum TimerBehavior {
  /// Timer continues into overtime; candidate decides when to move on.
  softWarning,

  /// A grace-period countdown starts; stage auto-advances when it expires.
  warningAutoAdvance,

  /// Timer stops immediately and the stage is marked ended.
  hardStop;

  /// Stable string identifier for serialisation.
  String get key => switch (this) {
        softWarning => 'soft_warning',
        warningAutoAdvance => 'warning_auto_advance',
        hardStop => 'hard_stop',
      };

  /// Deserialises a [key] back to a [TimerBehavior].
  static TimerBehavior fromKey(String key) =>
      TimerBehavior.values.firstWhere((b) => b.key == key);
}
