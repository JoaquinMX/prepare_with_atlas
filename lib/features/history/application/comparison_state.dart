import 'package:prepare_with_atlas/features/history/domain/progress_diff.dart';

/// Base class for all comparison controller states.
sealed class ComparisonState {
  /// Creates a [ComparisonState].
  const ComparisonState();
}

/// The controller has not yet started a comparison.
final class ComparisonIdle extends ComparisonState {
  /// Creates a [ComparisonIdle].
  const ComparisonIdle();
}

/// A comparison is being loaded.
final class ComparisonLoading extends ComparisonState {
  /// Creates a [ComparisonLoading].
  const ComparisonLoading();
}

/// The comparison loaded successfully.
final class ComparisonSuccess extends ComparisonState {
  /// Creates a [ComparisonSuccess].
  const ComparisonSuccess({required this.diff});

  /// The computed progress difference.
  final ProgressDiff diff;
}

/// The comparison failed with an error.
final class ComparisonError extends ComparisonState {
  /// Creates a [ComparisonError].
  const ComparisonError({required this.message});

  /// Human-readable description of the error.
  final String message;
}
