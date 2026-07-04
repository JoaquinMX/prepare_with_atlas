import 'dart:typed_data';

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

  /// Whether this provider supports audio transcription (speech-to-text).
  bool get supportsAudioTranscription;

  /// Whether this provider supports native audio input in chat completions.
  bool get supportsNativeAudio;

  /// Sends [messages] to the AI and returns a completion.
  ///
  /// Throws [AiProviderException] on error.
  Future<AiCompletionResult> complete(List<AiMessage> messages);

  /// Transcribes [audioBytes] to text using the provider's transcription API.
  ///
  /// [audioBytes] should be PCM/WAV format. [mimeType] should be the
  /// audio format (e.g. 'audio/flac', 'audio/wav').
  ///
  /// Throws [AiProviderException] if transcription is not supported
  /// by this provider.
  Future<String> transcribe(
    Uint8List audioBytes, {
    required String mimeType,
  });

  /// Sends [messages] with native audio input to the AI.
  ///
  /// [audioBytes] should be the raw audio data. [mimeType] should be
  /// the audio format.
  ///
  /// Throws [AiProviderException] if native audio is not supported
  /// by this provider.
  Future<AiCompletionResult> completeWithAudio(
    List<AiMessage> messages,
    Uint8List audioBytes, {
    required String mimeType,
  });

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
