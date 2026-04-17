import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';

part 'evaluation_state.freezed.dart';

/// The state managed by `EvaluationController`.
@freezed
sealed class EvaluationState with _$EvaluationState {
  /// No evaluation is in progress or has been loaded.
  const factory EvaluationState.idle() = EvaluationIdle;

  /// An evaluation request is currently in progress.
  const factory EvaluationState.loading({
    /// Human-readable status message to display to the user.
    @Default('Assembling your evaluation...') String statusText,
  }) = EvaluationLoading;

  /// An evaluation completed successfully.
  const factory EvaluationState.success(
    /// The completed evaluation result.
    EvaluationResult result,
  ) = EvaluationSuccess;

  /// An evaluation failed.
  const factory EvaluationState.error(
    /// Human-readable error message.
    String message, {

    /// Whether the user can retry the evaluation.
    @Default(true) bool canRetry,
  }) = EvaluationError;
}
