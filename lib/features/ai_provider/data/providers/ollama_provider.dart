import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_completion_result.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';

/// Local Ollama provider.
///
/// Communicates with a locally running Ollama server.
/// No API key or authentication is required.
class OllamaProvider implements AiProvider {
  /// Creates an [OllamaProvider].
  ///
  /// [modelName] is required (e.g. 'llama3', 'mistral').
  /// [baseUrl] defaults to `http://localhost:11434`.
  /// Per-capability overrides ([textModelOverride], [visionModelOverride],
  /// [audioModelOverride]) take precedence over [modelName] for their
  /// respective operations.
  /// A custom [dio] instance may be injected for testing.
  OllamaProvider({
    required String modelName,
    String baseUrl = 'http://localhost:11434',
    String? textModelOverride,
    String? visionModelOverride,
    String? audioModelOverride,
    Dio? dio,
  })  : _baseUrl = baseUrl,
        _modelName = modelName,
        _textModel = textModelOverride ?? modelName,
        _visionModel = visionModelOverride ?? modelName,
        _audioModel = audioModelOverride ?? modelName,
        _dio = dio ?? _buildDio();

  final String _baseUrl;
  final String _modelName;
  final String _textModel;
  final String _visionModel;
  final String _audioModel;
  final Dio _dio;

  static Dio _buildDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

  @override
  String get providerName => 'ollama';

  @override
  String get currentModel => _modelName;

  @override
  bool get supportsVision => false;

  @override
  bool get supportsAudioTranscription => true;

  @override
  bool get supportsNativeAudio => true;

  @override
  Future<AiCompletionResult> complete(
    List<AiMessage> messages,
  ) async {
    final hasImage = messages.any(
      (m) => m.imageBytes != null && m.imageBytes!.isNotEmpty,
    );
    final model = hasImage
        ? (_visionModel.isNotEmpty ? _visionModel : _modelName)
        : (_textModel.isNotEmpty ? _textModel : _modelName);

    final body = {
      'model': model,
      'messages': messages
          .where((m) => m.imageBytes == null || m.imageBytes!.isEmpty)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList(),
      'stream': false,
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/api/chat',
        data: body,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );
      final data = response.data!;
      final message =
          data['message'] as Map<String, dynamic>;
      return AiCompletionResult(
        content: message['content'] as String,
        providerName: providerName,
        modelUsed: data['model'] as String? ?? _modelName,
        promptTokens:
            data['prompt_eval_count'] as int? ?? 0,
        completionTokens: data['eval_count'] as int? ?? 0,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      await _dio.get<dynamic>('$_baseUrl/api/tags');
      await complete([
        const AiMessage(role: 'user', content: 'Hello'),
      ]);
      return true;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<String> transcribe(
    Uint8List audioBytes, {
    required String mimeType,
  }) async {
    // Determine file extension from mime type for Ollama transcription API
    final extension = mimeType.contains('flac')
        ? 'flac'
        : mimeType.contains('wav') || mimeType.contains('wave')
            ? 'wav'
            : 'mp3';

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        audioBytes,
        filename: 'audio.$extension',
        contentType: DioMediaType.parse(mimeType),
      ),
      'model': _audioModel.isNotEmpty ? _audioModel : _modelName,
    });

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/v1/audio/transcriptions',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      return (response.data!['text'] as String?) ?? '';
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<AiCompletionResult> completeWithAudio(
    List<AiMessage> messages,
    Uint8List audioBytes, {
    required String mimeType,
  }) async {
    // Ollama audio in chat completions is not standardized.
    // Use transcribe() for audio-to-text, then include the transcript
    // in the text messages for evaluation.
    throw AiProviderException(
      'Ollama does not support native audio in chat completions. '
      'Use transcribe() to convert audio to text.',
    );
  }

  /// Lists all model names available in the local Ollama server.
  ///
  /// Fetches from `GET /api/tags` and parses `models[*].name`.
  Future<List<String>> listModels() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/tags',
      );
      final data = response.data!;
      final models = data['models'] as List<dynamic>? ?? [];
      return models
          .map(
            (m) =>
                (m as Map<String, dynamic>)['name'] as String,
          )
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Fetches available model names from an Ollama server at [baseUrl].
  ///
  /// Does not require a model to be pre-configured; intended for
  /// populating a model picker before the user has chosen a model.
  /// Throws [AiProviderException] if the server is unreachable.
  static Future<List<String>> fetchModels(
    String baseUrl, {
    Dio? dio,
  }) async {
    final d = dio ?? _buildDio();
    try {
      final response = await d.get<Map<String, dynamic>>(
        '$baseUrl/api/tags',
      );
      final data = response.data!;
      final models = data['models'] as List<dynamic>? ?? [];
      return models
          .map(
            (m) =>
                (m as Map<String, dynamic>)['name'] as String,
          )
          .toList();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw AiProviderException(
          'Cannot reach Ollama at $baseUrl. Is it running?',
        );
      }
      throw AiProviderException(
        'Cannot reach Ollama at $baseUrl.',
        statusCode: code,
      );
    }
  }

  AiProviderException _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return AiProviderException(
        'Invalid API key or unauthorized.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 429) {
      return const AiProviderException(
        'Rate limit exceeded. Please wait before retrying.',
        statusCode: 429,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const AiProviderException(
        'Request timed out. Check your network connection.',
      );
    }
    final errorData =
        (e.response?.data as Map<String, dynamic>?)?['error']
            as Map<String, dynamic>?;
    final message =
        errorData?['message'] as String? ?? 'Unknown error';
    return AiProviderException(message, statusCode: statusCode);
  }
}
