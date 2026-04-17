import 'package:prepare_with_atlas/features/ai_provider/domain/ai_completion_result.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';

/// Abstract port for AI provider implementations.
///
/// All callers (evaluation, problem generation) use this interface
/// and never know which concrete provider is active.
abstract class AiProvider {
  /// The canonical name of this provider.
  String get providerName;

  /// The model identifier currently in use.
  String get currentModel;

  /// Whether this provider supports image (multimodal) input.
  bool get supportsVision;

  /// Sends [messages] to the AI and returns a completion.
  ///
  /// Throws [AiProviderException] on error.
  Future<AiCompletionResult> complete(List<AiMessage> messages);

  /// Sends a minimal prompt to verify the provider is correctly configured.
  ///
  /// Returns `true` on success. Throws [AiProviderException] on failure.
  Future<bool> testConnection();
}

/// Exception thrown by AI provider operations.
class AiProviderException implements Exception {
  /// Creates an [AiProviderException] with [message] and optional [statusCode].
  const AiProviderException(this.message, {this.statusCode});

  /// Human-readable error description.
  final String message;

  /// HTTP status code if applicable.
  final int? statusCode;

  @override
  String toString() => 'AiProviderException($statusCode): $message';
}
