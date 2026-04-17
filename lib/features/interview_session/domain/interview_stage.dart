/// The five stages of a system design interview.
///
/// Each stage carries ONLY display name and duration bounds.
/// No topics, techniques, or insights — real interviews don't provide them.
enum InterviewStage {
  /// Stage 1: clarify functional and non-functional requirements.
  requirementGathering,

  /// Stage 2: rough capacity and traffic estimates.
  backOfEnvelopeEstimation,

  /// Stage 3: sketch the major components and data flow.
  highLevelDesign,

  /// Stage 4: dive into the trickiest subsystem.
  deepDive,

  /// Stage 5: discuss bottlenecks and scaling strategies.
  scalingAndBottlenecks;

  /// Human-readable name shown in the UI.
  String get displayName => switch (this) {
        requirementGathering => 'Requirements',
        backOfEnvelopeEstimation => 'Estimation',
        highLevelDesign => 'High-Level Design',
        deepDive => 'Deep Dive',
        scalingAndBottlenecks => 'Scaling',
      };

  /// Default stage duration in minutes.
  int get defaultDurationMinutes => switch (this) {
        requirementGathering => 7,
        backOfEnvelopeEstimation => 5,
        highLevelDesign => 12,
        deepDive => 17,
        scalingAndBottlenecks => 7,
      };

  /// Minimum allowed duration in minutes.
  int get minDurationMinutes => switch (this) {
        requirementGathering => 5,
        backOfEnvelopeEstimation => 3,
        highLevelDesign => 10,
        deepDive => 15,
        scalingAndBottlenecks => 5,
      };

  /// Maximum allowed duration in minutes.
  int get maxDurationMinutes => switch (this) {
        requirementGathering => 10,
        backOfEnvelopeEstimation => 5,
        highLevelDesign => 15,
        deepDive => 20,
        scalingAndBottlenecks => 10,
      };

  /// Stable string identifier for serialisation.
  String get key => name;

  /// Deserialises a [key] back to an [InterviewStage].
  static InterviewStage fromKey(String key) =>
      InterviewStage.values.firstWhere((s) => s.key == key);
}
