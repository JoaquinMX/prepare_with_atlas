import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/openai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';

import 'openai_provider_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio mockDio;
  late OpenAiProvider sut;
  const apiKey = 'sk-test-openai-key';

  setUp(() {
    mockDio = MockDio();
    sut = OpenAiProvider(apiKey: apiKey, dio: mockDio);
  });

  Map<String, dynamic> successResponse({
    String content = 'Hello back!',
    String model = 'gpt-4o',
  }) =>
      {
        'model': model,
        'choices': [
          {
            'message': {'role': 'assistant', 'content': content},
          },
        ],
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 5,
        },
      };

  RequestOptions opts() => RequestOptions();

  group('OpenAiProvider', () {
    test('providerName is openai', () {
      expect(sut.providerName, 'openai');
    });

    test('supportsVision is true', () {
      expect(sut.supportsVision, isTrue);
    });

    test('default model is gpt-4o', () {
      expect(sut.currentModel, 'gpt-4o');
    });

    test('complete sends Authorization Bearer header', () async {
      when(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: successResponse(),
          statusCode: 200,
          requestOptions: opts(),
        ),
      );

      await sut.complete([const AiMessage(role: 'user', content: 'Hi')]);

      final captured = verify(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: anyNamed('data'),
          options: captureAnyNamed('options'),
        ),
      ).captured;

      final options = captured.first as Options;
      expect(
        options.headers?['Authorization'],
        'Bearer $apiKey',
      );
    });

    test('complete sends messages in OpenAI format', () async {
      when(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: successResponse(),
          statusCode: 200,
          requestOptions: opts(),
        ),
      );

      await sut.complete([
        const AiMessage(role: 'system', content: 'Be helpful'),
        const AiMessage(role: 'user', content: 'Hello'),
      ]);

      final captured = verify(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: captureAnyNamed('data'),
          options: anyNamed('options'),
        ),
      ).captured;

      final body = captured.first as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      expect(messages.length, 2);
      final first = messages[0] as Map<String, dynamic>;
      expect(first['role'], 'system');
      expect(first['content'], 'Be helpful');
    });

    test('complete with imageBytes sends base64 image in content', () async {
      when(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: successResponse(),
          statusCode: 200,
          requestOptions: opts(),
        ),
      );

      final imageBytes = [137, 80, 78, 71]; // PNG header bytes
      await sut.complete([
        AiMessage(
          role: 'user',
          content: 'Describe this',
          imageBytes: imageBytes,
          imageMimeType: 'image/png',
        ),
      ]);

      final captured = verify(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: captureAnyNamed('data'),
          options: anyNamed('options'),
        ),
      ).captured;

      final body = captured.first as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      final msg = messages[0] as Map<String, dynamic>;
      final content = msg['content'] as List<dynamic>;
      expect(content.length, 2);
      final imageBlock = content[1] as Map<String, dynamic>;
      expect(imageBlock['type'], 'image_url');
    });

    test('401 response throws AiProviderException with statusCode 401',
        () async {
      when(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: opts(),
          response: Response(
            statusCode: 401,
            data: <String, dynamic>{
              'error': {'message': 'Invalid auth'},
            },
            requestOptions: opts(),
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => sut.complete([const AiMessage(role: 'user', content: 'Hi')]),
        throwsA(
          isA<AiProviderException>()
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('429 response throws AiProviderException with statusCode 429',
        () async {
      when(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: opts(),
          response: Response(
            statusCode: 429,
            data: <String, dynamic>{},
            requestOptions: opts(),
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => sut.complete([const AiMessage(role: 'user', content: 'Hi')]),
        throwsA(
          isA<AiProviderException>()
              .having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
    });

    test('testConnection returns true on 200', () async {
      when(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: successResponse(),
          statusCode: 200,
          requestOptions: opts(),
        ),
      );

      final result = await sut.testConnection();
      expect(result, isTrue);
    });
  });
}
