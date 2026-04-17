import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_completion_result.freezed.dart';

/// The result of an AI text completion call.
@freezed
abstract class AiCompletionResult with _$AiCompletionResult {
  /// Creates an [AiCompletionResult].
  const factory AiCompletionResult({
    /// The generated text content from the AI.
    required String content,

    /// The canonical name of the provider that generated this result.
    required String providerName,

    /// The model identifier used for this completion.
    required String modelUsed,

    /// The number of tokens in the prompt.
    required int promptTokens,

    /// The number of tokens in the completion.
    required int completionTokens,
  }) = _AiCompletionResult;
}
