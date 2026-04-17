import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_controller.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config_repository.dart';
import 'package:prepare_with_atlas/features/settings/presentation/ai_settings_screen.dart';

import 'ai_settings_screen_test.mocks.dart';

/// Fake controller that overrides [fetchOllamaModels] for widget tests.
class _FakeAiProviderController extends AiProviderController {
  _FakeAiProviderController(this._models);

  final List<String> _models;

  @override
  Future<List<String>> fetchOllamaModels(String baseUrl) async => _models;
}

@GenerateMocks([AiProviderConfigRepository])
void main() {
  late MockAiProviderConfigRepository mockRepo;

  setUp(() {
    mockRepo = MockAiProviderConfigRepository();
    when(mockRepo.getActive()).thenAnswer((_) async => null);
    when(mockRepo.save(any)).thenAnswer((_) async {});
    when(mockRepo.setActive(any)).thenAnswer((_) async {});
    when(mockRepo.getAll()).thenAnswer((_) async => []);
    when(mockRepo.delete(any)).thenAnswer((_) async {});
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        aiProviderConfigRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: const MaterialApp(home: Scaffold(body: AiSettingsScreen())),
    );
  }

  Widget buildSubjectWithOllamaModels(List<String> models) {
    return ProviderScope(
      overrides: [
        aiProviderConfigRepositoryProvider.overrideWithValue(mockRepo),
        aiProviderControllerProvider.overrideWith(
          () => _FakeAiProviderController(models),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: AiSettingsScreen())),
    );
  }

  Future<void> selectOllama(WidgetTester tester) async {
    await tester.tap(find.text('Ollama'));
    await tester.pumpAndSettle();
  }

  group('AiSettingsScreen', () {
    testWidgets('shows OpenAI provider option', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('OpenAI'), findsOneWidget);
    });

    testWidgets('shows Anthropic provider option', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Anthropic'), findsOneWidget);
    });

    testWidgets('shows Google Gemini provider option', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Google Gemini'), findsOneWidget);
    });

    testWidgets('shows OpenRouter provider option', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('OpenRouter'), findsOneWidget);
    });

    testWidgets('shows Ollama provider option', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Ollama'), findsOneWidget);
    });

    testWidgets('shows all 5 provider options', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.text('Anthropic'), findsOneWidget);
      expect(find.text('Google Gemini'), findsOneWidget);
      expect(find.text('OpenRouter'), findsOneWidget);
      expect(find.text('Ollama'), findsOneWidget);
    });

    testWidgets('shows Save & Test Connection button', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Save & Test Connection'), findsOneWidget);
    });

    testWidgets('shows Active badge when a provider is configured', (
      tester,
    ) async {
      when(mockRepo.getActive()).thenAnswer(
        (_) async => const AiProviderConfig.apiKey(
          providerName: 'anthropic',
          apiKey: 'sk-ant-test',
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('shows Sign in with ChatGPT button for OpenAI provider', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // OpenAI is selected by default, so OAuth button should be present.
      expect(find.text('Sign in with ChatGPT'), findsOneWidget);
    });

    testWidgets('Save & Test Connection button is tappable', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final saveButton = find.text('Save & Test Connection');
      expect(saveButton, findsOneWidget);
      // Tapping with empty fields shows a snackbar — does not crash.
      await tester.tap(saveButton);
      await tester.pump();
    });

    group('Ollama form', () {
      testWidgets('shows server URL field when Ollama is selected', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        await selectOllama(tester);

        expect(find.text('Ollama Server URL'), findsOneWidget);
      });

      testWidgets('shows Load available models button before any fetch', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        await selectOllama(tester);

        expect(find.text('Load available models'), findsOneWidget);
      });

      testWidgets('shows model dropdown when models are available', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubjectWithOllamaModels(['llama3', 'mistral']),
        );
        await tester.pumpAndSettle();
        await selectOllama(tester);
        await tester.tap(find.text('Load available models'));
        await tester.pumpAndSettle();

        expect(find.text('llama3'), findsWidgets);
      });

      testWidgets('shows no-models-installed empty state', (tester) async {
        await tester.pumpWidget(buildSubjectWithOllamaModels([]));
        await tester.pumpAndSettle();
        await selectOllama(tester);
        await tester.tap(find.text('Load available models'));
        await tester.pumpAndSettle();

        expect(find.text('No models installed'), findsOneWidget);
      });

      testWidgets('shows install command in empty state', (tester) async {
        await tester.pumpWidget(buildSubjectWithOllamaModels([]));
        await tester.pumpAndSettle();
        await selectOllama(tester);
        await tester.tap(find.text('Load available models'));
        await tester.pumpAndSettle();

        expect(find.text('ollama pull <model-name>'), findsOneWidget);
      });

      testWidgets('shows Check again button in empty state', (tester) async {
        await tester.pumpWidget(buildSubjectWithOllamaModels([]));
        await tester.pumpAndSettle();
        await selectOllama(tester);
        await tester.tap(find.text('Load available models'));
        await tester.pumpAndSettle();

        expect(find.text('Check again'), findsOneWidget);
      });
    });
  });
}
