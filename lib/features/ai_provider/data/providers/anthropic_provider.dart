import 'dart:convert';
import 'dart:typed_data';

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
  /// Per-capability overrides ([textModelOverride], [visionModelOverride],
  /// [audioModelOverride]) take precedence over [modelOverride] for their
  /// respective operations.
  /// A custom [dio] instance may be injected for testing.
  AnthropicProvider({
    required String apiKey,
    String modelOverride = '',
    String? textModelOverride,
    String? visionModelOverride,
    String? audioModelOverride,
    Dio? dio,
  })  : _apiKey = apiKey,
        _model = modelOverride.isNotEmpty
            ? modelOverride
            : 'claude-sonnet-4-20250514',
        _textModel = textModelOverride ?? modelOverride,
        _visionModel = visionModelOverride ?? modelOverride,
        _audioModel = audioModelOverride,
        _dio = dio ?? _buildDio();

  final String _apiKey;
  final String _model;
  final String _textModel;
  final String _visionModel;
  final String? _audioModel;
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
  bool get supportsAudioTranscription => false;

  @override
  bool get supportsNativeAudio => false;

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

    final hasImage = nonSystemMessages.any(
      (m) => m.imageBytes != null && m.imageBytes!.isNotEmpty,
    );
    final model = hasImage
        ? (_visionModel.isNotEmpty ? _visionModel : _model)
        : (_textModel.isNotEmpty ? _textModel : _model);

    final body = <String, dynamic>{
      'model': model,
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
        modelUsed: data['model'] as String? ?? model,
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

  @override
  Future<String> transcribe(
    Uint8List audioBytes, {
    required String mimeType,
  }) async {
    if (_audioModel == null || _audioModel.isEmpty) {
      throw const AiProviderException(
        'Anthropic does not support audio transcription.',
      );
    }
    throw const AiProviderException(
      'Anthropic does not support audio transcription.',
    );
  }

  @override
  Future<AiCompletionResult> completeWithAudio(
    List<AiMessage> messages,
    Uint8List audioBytes, {
    required String mimeType,
  }) async {
    throw const AiProviderException(
      'Anthropic does not support native audio input.',
    );
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
