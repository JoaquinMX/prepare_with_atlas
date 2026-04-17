import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';

void main() {
  group('ApiKeyConfig', () {
    test('creates correctly with required fields', () {
      const config = AiProviderConfig.apiKey(
        providerName: 'openai',
        apiKey: 'sk-test-key',
      );

      expect(config, isA<ApiKeyConfig>());
      const c = config as ApiKeyConfig;
      expect(c.providerName, 'openai');
      expect(c.apiKey, 'sk-test-key');
      expect(c.modelOverride, '');
    });

    test('creates with model override', () {
      const config = AiProviderConfig.apiKey(
        providerName: 'anthropic',
        apiKey: 'sk-ant-key',
        modelOverride: 'claude-opus-4',
      );
      const c = config as ApiKeyConfig;
      expect(c.modelOverride, 'claude-opus-4');
    });

    test('toJson/fromJson round-trip works', () {
      const config = AiProviderConfig.apiKey(
        providerName: 'openai',
        apiKey: 'sk-test-key',
        modelOverride: 'gpt-4o-mini',
      );

      final json = config.toJson();
      final restored = AiProviderConfig.fromJson(json);

      expect(restored, equals(config));
      final r = restored as ApiKeyConfig;
      expect(r.providerName, 'openai');
      expect(r.apiKey, 'sk-test-key');
      expect(r.modelOverride, 'gpt-4o-mini');
    });
  });

  group('OAuthConfig', () {
    test('creates with future expiry date', () {
      final expiry = DateTime.now().add(const Duration(hours: 1));
      final config = AiProviderConfig.oauth(
        providerName: 'openai',
        accessToken: 'access-tok',
        refreshToken: 'refresh-tok',
        expiresAt: expiry,
      );

      expect(config, isA<OAuthConfig>());
      final c = config as OAuthConfig;
      expect(c.providerName, 'openai');
      expect(c.accessToken, 'access-tok');
      expect(c.refreshToken, 'refresh-tok');
      expect(c.expiresAt.isAfter(DateTime.now()), isTrue);
      expect(c.modelOverride, '');
    });

    test('toJson/fromJson round-trip works', () {
      final expiry = DateTime.utc(2026, 12, 31);
      final config = AiProviderConfig.oauth(
        providerName: 'openai',
        accessToken: 'access-tok',
        refreshToken: 'refresh-tok',
        expiresAt: expiry,
      );

      final json = config.toJson();
      final restored = AiProviderConfig.fromJson(json);

      expect(restored, equals(config));
    });
  });

  group('OllamaConfig', () {
    test('defaults to http://localhost:11434', () {
      const config = AiProviderConfig.ollama(
        modelName: 'llama3',
      );

      expect(config, isA<OllamaConfig>());
      const c = config as OllamaConfig;
      expect(c.baseUrl, 'http://localhost:11434');
      expect(c.modelName, 'llama3');
    });

    test('can override base URL', () {
      const config = AiProviderConfig.ollama(
        modelName: 'mistral',
        baseUrl: 'http://192.168.1.5:11434',
      );
      const c = config as OllamaConfig;
      expect(c.baseUrl, 'http://192.168.1.5:11434');
    });

    test('toJson/fromJson round-trip works', () {
      const config = AiProviderConfig.ollama(
        modelName: 'llama3',
      );

      final json = config.toJson();
      final restored = AiProviderConfig.fromJson(json);

      expect(restored, equals(config));
    });
  });

  group('Pattern matching on sealed class', () {
    test('switch works on all cases', () {
      final configs = <AiProviderConfig>[
        const AiProviderConfig.apiKey(
          providerName: 'openai',
          apiKey: 'key',
        ),
        AiProviderConfig.oauth(
          providerName: 'openai',
          accessToken: 'tok',
          refreshToken: 'ref',
          expiresAt: DateTime(2027),
        ),
        const AiProviderConfig.ollama(modelName: 'llama3'),
      ];

      final names = configs.map((c) => switch (c) {
            ApiKeyConfig(:final providerName) => 'apikey:$providerName',
            OAuthConfig(:final providerName) => 'oauth:$providerName',
            OllamaConfig(:final modelName) => 'ollama:$modelName',
          });

      expect(
        names.toList(),
        ['apikey:openai', 'oauth:openai', 'ollama:llama3'],
      );
    });
  });
}
