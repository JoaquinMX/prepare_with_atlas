import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_completion_result.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';

/// Google Gemini provider using the Generative Language REST API.
class GeminiProvider implements AiProvider {
  /// Creates a [GeminiProvider] with the given [apiKey].
  ///
  /// Optionally override the default model via [modelOverride].
  /// A custom [dio] instance may be injected for testing.
  GeminiProvider({
    required String apiKey,
    String modelOverride = '',
    Dio? dio,
  })  : _apiKey = apiKey,
        _model =
            modelOverride.isNotEmpty ? modelOverride : 'gemini-2.0-flash',
        _dio = dio ?? _buildDio();

  final String _apiKey;
  final String _model;
  final Dio _dio;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static Dio _buildDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

  @override
  String get providerName => 'gemini';

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
    final userMessages =
        messages.where((m) => m.role != 'system').toList();

    final systemText =
        systemMessages.map((m) => m.content).join('\n').trim();

    final contents = userMessages
        .map((m) => {
              'role': m.role == 'assistant' ? 'model' : 'user',
              'parts': _messageParts(m),
            })
        .toList();

    final body = <String, dynamic>{
      'contents': contents,
    };

    if (systemText.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemText},
        ],
      };
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/$_model:generateContent?key=$_apiKey',
        data: body,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );
      final data = response.data!;
      final candidates = data['candidates'] as List<dynamic>;
      final candidate =
          candidates[0] as Map<String, dynamic>;
      final content =
          candidate['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List<dynamic>;
      final firstPart =
          parts[0] as Map<String, dynamic>;
      final usageMeta =
          data['usageMetadata'] as Map<String, dynamic>? ?? {};
      return AiCompletionResult(
        content: firstPart['text'] as String,
        providerName: providerName,
        modelUsed: _model,
        promptTokens:
            usageMeta['promptTokenCount'] as int? ?? 0,
        completionTokens:
            usageMeta['candidatesTokenCount'] as int? ?? 0,
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

  List<Map<String, dynamic>> _messageParts(AiMessage msg) {
    final parts = <Map<String, dynamic>>[
      {'text': msg.content},
    ];
    if (msg.imageBytes != null && msg.imageBytes!.isNotEmpty) {
      parts.add({
        'inlineData': {
          'mimeType': msg.imageMimeType ?? 'image/png',
          'data': base64Encode(msg.imageBytes!),
        },
      });
    }
    return parts;
  }

  /// Fetches model names available for the given [apiKey] that support
  /// `generateContent`.
  ///
  /// Strips the `"models/"` prefix so names are ready to use as model IDs
  /// (e.g. `"gemini-2.0-flash"`).
  ///
  /// Throws [AiProviderException] on HTTP or connectivity errors.
  static Future<List<String>> fetchModels(
    String apiKey, {
    Dio? dio,
  }) async {
    final d = dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
    try {
      final response = await d.get<Map<String, dynamic>>(
        '$_baseUrl?key=$apiKey',
      );
      final models =
          (response.data!['models'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
      return models
          .where(
            (m) => (m['supportedGenerationMethods'] as List<dynamic>?)
                    ?.contains('generateContent') ??
                false,
          )
          .map((m) {
            final name = m['name'] as String;
            // Strip "models/" prefix: "models/gemini-2.0-flash" → "gemini-2.0-flash"
            return name.startsWith('models/')
                ? name.substring('models/'.length)
                : name;
          })
          .toList();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 400 || code == 401 || code == 403) {
        throw const AiProviderException(
          'Invalid API key. Check your Gemini API key and try again.',
          statusCode: 401,
        );
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const AiProviderException(
          'Cannot reach Gemini. Check your network connection.',
        );
      }
      throw AiProviderException(
        'Failed to load Gemini models.',
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
