import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_controller.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config_repository.dart';

import 'ai_provider_controller_test.mocks.dart';

@GenerateMocks([AiProviderConfigRepository, AiProvider])
void main() {
  late MockAiProviderConfigRepository mockRepo;

  setUp(() {
    mockRepo = MockAiProviderConfigRepository();
    when(mockRepo.getActive()).thenAnswer((_) async => null);
    when(mockRepo.save(any)).thenAnswer((_) async {});
    when(mockRepo.setActive(any)).thenAnswer((_) async {});
  });

  /// Creates a [ProviderContainer] backed by the given [repo] and returns
  /// both the container and the live controller instance.
  (ProviderContainer, AiProviderController) setup({
    AiProviderConfigRepository? repo,
  }) {
    final r = repo ?? mockRepo;
    final container = ProviderContainer(
      overrides: [
        aiProviderConfigRepositoryProvider.overrideWithValue(r),
      ],
    );
    addTearDown(container.dispose);
    // Read to trigger build.
    container.read(aiProviderControllerProvider);
    final controller =
        container.read(aiProviderControllerProvider.notifier);
    return (container, controller);
  }

  group('AiProviderController', () {
    test('initial state has isLoading=true', () {
      final (_, controller) = setup();
      expect(controller.state.isLoading, isTrue);
    });

    test('after build completes with no active config, state has '
        'no active provider', () async {
      final (_, controller) = setup();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.activeProvider, isNull);
      expect(controller.state.isLoading, isFalse);
    });

    test('setProvider updates activeConfig in state', () async {
      final (_, controller) = setup();
      await Future<void>.delayed(Duration.zero);

      const config = AiProviderConfig.apiKey(
        providerName: 'openai',
        apiKey: 'sk-test',
      );

      await controller.setProvider(config);

      expect(controller.state.activeConfig, config);
    });

    test('setProvider sets activeProvider to non-null', () async {
      final (_, controller) = setup();
      await Future<void>.delayed(Duration.zero);

      const config = AiProviderConfig.apiKey(
        providerName: 'anthropic',
        apiKey: 'sk-ant-test',
      );

      await controller.setProvider(config);

      expect(controller.state.activeProvider, isNotNull);
    });

    test(
        'testConnection with no provider sets testSuccess=false and '
        'message contains "No AI provider"', () async {
      final (_, controller) = setup();
      await Future<void>.delayed(Duration.zero);

      await controller.testConnection();

      expect(controller.state.testSuccess, isFalse);
      expect(
        controller.state.testResultMessage,
        contains('No AI provider'),
      );
    });

    test('getActiveProvider throws when no provider configured', () async {
      final (_, controller) = setup();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.getActiveProvider,
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.message,
            'message',
            contains('No AI provider configured'),
          ),
        ),
      );
    });

    test('getActiveProvider returns provider after setProvider', () async {
      final (_, controller) = setup();
      await Future<void>.delayed(Duration.zero);

      const config = AiProviderConfig.apiKey(
        providerName: 'openai',
        apiKey: 'sk-test',
      );
      await controller.setProvider(config);

      expect(controller.getActiveProvider, returnsNormally);
      expect(controller.getActiveProvider(), isA<AiProvider>());
    });

    test('runTestConnection returns AiTestResult with no-provider message',
        () async {
      final (_, controller) = setup();
      await Future<void>.delayed(Duration.zero);

      final result = await controller.runTestConnection();

      expect(result, isA<AiTestResult>());
      expect(result.success, isFalse);
      expect(result.message, isNotEmpty);
    });

    test('testConnection sets isTesting=false after resolving', () async {
      final (_, controller) = setup();
      await Future<void>.delayed(Duration.zero);

      await controller.testConnection();

      // isTesting must be false after the call resolves
      expect(controller.state.isTesting, isFalse);
    });
  });
}
