import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/anthropic_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';

import 'anthropic_provider_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio mockDio;
  late AnthropicProvider sut;
  const apiKey = 'sk-ant-test-key';

  setUp(() {
    mockDio = MockDio();
    sut = AnthropicProvider(apiKey: apiKey, dio: mockDio);
  });

  Map<String, dynamic> successResponse() => {
        'model': 'claude-sonnet-4-20250514',
        'content': [
          {'type': 'text', 'text': 'Hello back!'},
        ],
        'usage': {
          'input_tokens': 10,
          'output_tokens': 5,
        },
      };

  RequestOptions opts() => RequestOptions();

  group('AnthropicProvider', () {
    test('providerName is anthropic', () {
      expect(sut.providerName, 'anthropic');
    });

    test('sends x-api-key header', () async {
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
      expect(options.headers?['x-api-key'], apiKey);
    });

    test('sends anthropic-version: 2023-06-01 header', () async {
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
      expect(options.headers?['anthropic-version'], '2023-06-01');
    });

    test('separates system message correctly', () async {
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
        const AiMessage(role: 'system', content: 'System prompt'),
        const AiMessage(role: 'user', content: 'User message'),
      ]);

      final captured = verify(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: captureAnyNamed('data'),
          options: anyNamed('options'),
        ),
      ).captured;

      final body = captured.first as Map<String, dynamic>;
      expect(body['system'], 'System prompt');
      final messages = body['messages'] as List<dynamic>;
      expect(messages.length, 1);
      final msg = messages[0] as Map<String, dynamic>;
      expect(msg['role'], 'user');
    });

    test('multimodal includes image in content blocks', () async {
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

      final imageBytes = [137, 80, 78, 71];
      await sut.complete([
        AiMessage(
          role: 'user',
          content: 'What is this?',
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
      expect(imageBlock['type'], 'image');
    });

    test('401 throws AiProviderException', () {
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
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });
}
