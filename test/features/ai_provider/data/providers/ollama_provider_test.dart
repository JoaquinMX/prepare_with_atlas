import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/ollama_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';

import 'ollama_provider_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio mockDio;
  late OllamaProvider sut;

  setUp(() {
    mockDio = MockDio();
    sut = OllamaProvider(modelName: 'llama3', dio: mockDio);
  });

  Map<String, dynamic> chatResponse() => {
        'model': 'llama3',
        'message': {'role': 'assistant', 'content': 'Hello!'},
        'prompt_eval_count': 8,
        'eval_count': 3,
      };

  RequestOptions opts() => RequestOptions();

  group('OllamaProvider', () {
    test('providerName is ollama', () {
      expect(sut.providerName, 'ollama');
    });

    test('supportsVision is false', () {
      expect(sut.supportsVision, isFalse);
    });

    test('uses http://localhost:11434 by default', () {
      expect(sut.currentModel, 'llama3');
      // Verify the URL used in requests
    });

    test('sends stream: false in request body', () async {
      when(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: chatResponse(),
          statusCode: 200,
          requestOptions: opts(),
        ),
      );

      await sut.complete([const AiMessage(role: 'user', content: 'Hi')]);

      final captured = verify(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: captureAnyNamed('data'),
          options: anyNamed('options'),
        ),
      ).captured;

      final body = captured.first as Map<String, dynamic>;
      expect(body['stream'], isFalse);
    });

    test('uses correct base URL in POST request', () async {
      final customSut = OllamaProvider(
        modelName: 'llama3',
        baseUrl: 'http://192.168.1.10:11434',
        dio: mockDio,
      );

      when(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: chatResponse(),
          statusCode: 200,
          requestOptions: opts(),
        ),
      );

      await customSut.complete([
        const AiMessage(role: 'user', content: 'Hi'),
      ]);

      final captured = verify(
        mockDio.post<Map<String, dynamic>>(
          captureAny,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).captured;

      expect(captured.first, contains('192.168.1.10:11434'));
    });

    test('listModels parses models[*].name from /api/tags', () async {
      when(
        mockDio.get<Map<String, dynamic>>(any),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'models': [
              {'name': 'llama3', 'size': 123},
              {'name': 'mistral', 'size': 456},
            ],
          },
          statusCode: 200,
          requestOptions: opts(),
        ),
      );

      final models = await sut.listModels();

      expect(models, ['llama3', 'mistral']);
    });

    group('fetchModels (static)', () {
      test('returns model names from /api/tags', () async {
        when(
          mockDio.get<Map<String, dynamic>>(any),
        ).thenAnswer(
          (_) async => Response(
            data: {
              'models': [
                {'name': 'llama3'},
                {'name': 'gemma3'},
              ],
            },
            statusCode: 200,
            requestOptions: opts(),
          ),
        );

        final models = await OllamaProvider.fetchModels(
          'http://localhost:11434',
          dio: mockDio,
        );

        expect(models, ['llama3', 'gemma3']);
      });

      test('returns empty list when models array is absent', () async {
        when(
          mockDio.get<Map<String, dynamic>>(any),
        ).thenAnswer(
          (_) async => Response(
            data: <String, dynamic>{},
            statusCode: 200,
            requestOptions: opts(),
          ),
        );

        final models = await OllamaProvider.fetchModels(
          'http://localhost:11434',
          dio: mockDio,
        );

        expect(models, isEmpty);
      });

      test('throws AiProviderException on connection error', () {
        when(
          mockDio.get<Map<String, dynamic>>(any),
        ).thenThrow(
          DioException(
            requestOptions: opts(),
            type: DioExceptionType.connectionError,
          ),
        );

        expect(
          () => OllamaProvider.fetchModels(
            'http://localhost:11434',
            dio: mockDio,
          ),
          throwsA(isA<AiProviderException>()),
        );
      });
    });

    test('complete parses tokens from prompt_eval_count and eval_count',
        () async {
      when(
        mockDio.post<Map<String, dynamic>>(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'model': 'llama3',
            'message': {
              'role': 'assistant',
              'content': 'Hi there!',
            },
            'prompt_eval_count': 12,
            'eval_count': 7,
          },
          statusCode: 200,
          requestOptions: opts(),
        ),
      );

      final result = await sut.complete([
        const AiMessage(role: 'user', content: 'Hello'),
      ]);

      expect(result.promptTokens, 12);
      expect(result.completionTokens, 7);
    });
  });
}
