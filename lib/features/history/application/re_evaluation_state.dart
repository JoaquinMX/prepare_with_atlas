import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';

/// Per-session status of a re-evaluation request triggered from Session
/// History.
///
/// The [ReEvaluationController] holds a `Map<int, ReEvaluationStatus>` keyed
/// by session id so that requests run independently and the user can
/// navigate away from the detail screen without interrupting them.
sealed class ReEvaluationStatus {
  const ReEvaluationStatus();
}

/// No re-evaluation is in flight for the session.
class ReEvaluationIdle extends ReEvaluationStatus {
  const ReEvaluationIdle();
}

/// A re-evaluation is currently running against [providerName] / [modelUsed].
class ReEvaluationRunning extends ReEvaluationStatus {
  const ReEvaluationRunning({
    required this.providerName,
    required this.modelUsed,
  });

  /// Canonical name of the AI provider the user picked.
  final String providerName;

  /// Model identifier used for the re-evaluation.
  final String modelUsed;
}

/// The re-evaluation finished and a new [result] was persisted alongside the
/// original evaluation.
class ReEvaluationSuccess extends ReEvaluationStatus {
  const ReEvaluationSuccess({required this.result});

  /// The freshly persisted evaluation.
  final EvaluationResult result;
}

/// The re-evaluation failed against [providerName] with [message].
class ReEvaluationError extends ReEvaluationStatus {
  const ReEvaluationError({
    required this.providerName,
    required this.message,
  });

  /// Canonical name of the provider that failed.
  final String providerName;

  /// Human-readable error message.
  final String message;
}
