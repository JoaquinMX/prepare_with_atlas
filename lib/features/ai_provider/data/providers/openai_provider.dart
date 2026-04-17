import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_completion_result.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';

/// OpenAI chat-completions provider.
///
/// Supports both GPT-4o and vision models via the
/// `https://api.openai.com/v1/chat/completions` endpoint.
class OpenAiProvider implements AiProvider {
  /// Creates an [OpenAiProvider] with the given [apiKey].
  ///
  /// Optionally override the default model via [modelOverride].
  /// A custom [dio] instance may be injected for testing.
  OpenAiProvider({
    required String apiKey,
    String modelOverride = '',
    Dio? dio,
  })  : _apiKey = apiKey,
        _model =
            modelOverride.isNotEmpty ? modelOverride : 'gpt-4o',
        _dio = dio ?? _buildDio();

  final String _apiKey;
  final String _model;
  final Dio _dio;

  static const _baseUrl = 'https://api.openai.com/v1';

  static Dio _buildDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

  @override
  String get providerName => 'openai';

  @override
  String get currentModel => _model;

  @override
  bool get supportsVision => true;

  @override
  Future<AiCompletionResult> complete(
    List<AiMessage> messages,
  ) async {
    final body = {
      'model': _model,
      'messages': messages.map(_messageToMap).toList(),
      'max_tokens': 4096,
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/chat/completions',
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data!;
      final choices = data['choices'] as List<dynamic>;
      final message =
          choices[0] as Map<String, dynamic>;
      final msgContent =
          message['message'] as Map<String, dynamic>;
      final usage = data['usage'] as Map<String, dynamic>;
      return AiCompletionResult(
        content: msgContent['content'] as String,
        providerName: providerName,
        modelUsed: data['model'] as String? ?? _model,
        promptTokens: usage['prompt_tokens'] as int,
        completionTokens: usage['completion_tokens'] as int,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<bool> testConnection() async {
    await complete([
      const AiMessage(role: 'user', content: 'Hello'),
    ]);
    return true;
  }

  Map<String, dynamic> _messageToMap(AiMessage msg) {
    if (msg.imageBytes != null && msg.imageBytes!.isNotEmpty) {
      final base64Image = base64Encode(msg.imageBytes!);
      final mimeType = msg.imageMimeType ?? 'image/png';
      return {
        'role': msg.role,
        'content': [
          {'type': 'text', 'text': msg.content},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:$mimeType;base64,$base64Image',
            },
          },
        ],
      };
    }
    return {'role': msg.role, 'content': msg.content};
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
