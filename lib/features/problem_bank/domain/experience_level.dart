/// Represents the three experience tiers in the Problem Bank.
///
/// Each level maps to a difficulty key stored in the database and
/// carries its own display copy. Metadata (difficulty) is kept
/// internal to prevent spoilers in the UI.
enum ExperienceLevel {
  /// Problems rated 'easy' — designed to build foundations.
  warmUp,

  /// Problems rated 'medium' — complex trade-offs and scaling.
  advanced,

  /// Problems rated 'hard' — ambiguous, cutting-edge challenges.
  expert;

  /// Maps a raw difficulty string from the database to an [ExperienceLevel].
  ///
  /// Throws [ArgumentError] if [difficulty] is not 'easy', 'medium', or 'hard'.
  static ExperienceLevel fromDifficulty(String difficulty) {
    return switch (difficulty) {
      'easy' => warmUp,
      'medium' => advanced,
      'hard' => expert,
      _ => throw ArgumentError('Unknown difficulty: $difficulty'),
    };
  }

  /// Human-readable section label shown in the UI.
  String get displayLabel => switch (this) {
        warmUp => 'Warm-up Classics',
        advanced => 'Advanced Systems',
        expert => 'Expert Challenges',
      };

  /// Supporting subtitle shown beneath the section header.
  String get subtitle => switch (this) {
        warmUp =>
          'Recommended first — build foundations with familiar systems',
        advanced =>
          'For skilled developers — complex trade-offs and scaling',
        expert =>
          'For expert developers — ambiguous, cutting-edge problems',
      };

  /// The raw difficulty key stored in the database.
  String get difficultyKey => switch (this) {
        warmUp => 'easy',
        advanced => 'medium',
        expert => 'hard',
      };
}
