import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_completion_result.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';

/// Anthropic Messages API provider.
///
/// Uses the `https://api.anthropic.com/v1/messages` endpoint.
/// Anthropic blocked third-party OAuth April 4, 2026 — API key only.
class AnthropicProvider implements AiProvider {
  /// Creates an [AnthropicProvider] with the given [apiKey].
  ///
  /// Optionally override the default model via [modelOverride].
  /// A custom [dio] instance may be injected for testing.
  AnthropicProvider({
    required String apiKey,
    String modelOverride = '',
    Dio? dio,
  })  : _apiKey = apiKey,
        _model = modelOverride.isNotEmpty
            ? modelOverride
            : 'claude-sonnet-4-20250514',
        _dio = dio ?? _buildDio();

  final String _apiKey;
  final String _model;
  final Dio _dio;

  static const _baseUrl = 'https://api.anthropic.com/v1';
  static const _anthropicVersion = '2023-06-01';

  static Dio _buildDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

  @override
  String get providerName => 'anthropic';

  @override
  String get currentModel => _model;

  @override
  bool get supportsVision => true;

  @override
  Future<AiCompletionResult> complete(
    List<AiMessage> messages,
  ) async {
    final systemMessages =
        messages.where((m) => m.role == 'system').toList();
    final nonSystemMessages =
        messages.where((m) => m.role != 'system').toList();

    final systemText =
        systemMessages.map((m) => m.content).join('\n').trim();

    final body = <String, dynamic>{
      'model': _model,
      'max_tokens': 4096,
      'messages': nonSystemMessages.map(_messageToMap).toList(),
    };

    if (systemText.isNotEmpty) {
      body['system'] = systemText;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/messages',
        data: body,
        options: Options(
          headers: {
            'x-api-key': _apiKey,
            'anthropic-version': _anthropicVersion,
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data!;
      final content = data['content'] as List<dynamic>;
      final firstBlock =
          content[0] as Map<String, dynamic>;
      final usage = data['usage'] as Map<String, dynamic>;
      return AiCompletionResult(
        content: firstBlock['text'] as String,
        providerName: providerName,
        modelUsed: data['model'] as String? ?? _model,
        promptTokens: usage['input_tokens'] as int,
        completionTokens: usage['output_tokens'] as int,
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
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mimeType,
              'data': base64Image,
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
