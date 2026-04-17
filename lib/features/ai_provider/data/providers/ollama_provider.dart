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
  /// A custom [dio] instance may be injected for testing.
  OllamaProvider({
    required String modelName,
    String baseUrl = 'http://localhost:11434',
    Dio? dio,
  })  : _baseUrl = baseUrl,
        _modelName = modelName,
        _dio = dio ?? _buildDio();

  final String _baseUrl;
  final String _modelName;
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
  Future<AiCompletionResult> complete(
    List<AiMessage> messages,
  ) async {
    final body = {
      'model': _modelName,
      'messages': messages
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
