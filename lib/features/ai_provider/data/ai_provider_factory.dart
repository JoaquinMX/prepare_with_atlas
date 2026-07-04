import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/anthropic_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/gemini_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/ollama_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/openai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/openrouter_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';

/// Returns a concrete [AiProvider] for the given [config].
AiProvider buildAiProviderFromConfig(AiProviderConfig config) =>
    switch (config) {
      ApiKeyConfig(
        :final providerName,
        :final apiKey,
        :final modelOverride,
        :final textModelOverride,
        :final visionModelOverride,
        :final audioModelOverride,
      ) =>
        switch (providerName) {
          'anthropic' => AnthropicProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
              textModelOverride: textModelOverride,
              visionModelOverride: visionModelOverride,
              audioModelOverride: audioModelOverride,
            ),
          'gemini' => GeminiProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
              textModelOverride: textModelOverride,
              visionModelOverride: visionModelOverride,
              audioModelOverride: audioModelOverride,
            ),
          'openrouter' => OpenRouterProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
              textModelOverride: textModelOverride,
              visionModelOverride: visionModelOverride,
              audioModelOverride: audioModelOverride,
            ),
          _ => OpenAiProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
              textModelOverride: textModelOverride,
              visionModelOverride: visionModelOverride,
              audioModelOverride: audioModelOverride,
            ),
        },
      OAuthConfig(
        :final accessToken,
        :final modelOverride,
        :final textModelOverride,
        :final visionModelOverride,
        :final audioModelOverride,
      ) =>
        OpenAiProvider(
          apiKey: accessToken,
          modelOverride: modelOverride,
          textModelOverride: textModelOverride,
          visionModelOverride: visionModelOverride,
          audioModelOverride: audioModelOverride,
        ),
      OllamaConfig(
        :final baseUrl,
        :final modelName,
        :final textModelOverride,
        :final visionModelOverride,
        :final audioModelOverride,
      ) =>
        OllamaProvider(
          modelName: modelName,
          baseUrl: baseUrl,
          textModelOverride: textModelOverride,
          visionModelOverride: visionModelOverride,
          audioModelOverride: audioModelOverride,
        ),
    };

/// Returns a concrete [AiProvider] for the given [config], using [modelOverride]
/// instead of the config's default model.
AiProvider buildAiProviderFromConfigWithModel(
  AiProviderConfig config,
  String modelOverride,
) =>
    switch (config) {
      ApiKeyConfig(
        :final providerName,
        :final apiKey,
        :final textModelOverride,
        :final visionModelOverride,
        :final audioModelOverride,
      ) =>
        switch (providerName) {
          'anthropic' => AnthropicProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
              textModelOverride: textModelOverride,
              visionModelOverride: visionModelOverride,
              audioModelOverride: audioModelOverride,
            ),
          'gemini' => GeminiProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
              textModelOverride: textModelOverride,
              visionModelOverride: visionModelOverride,
              audioModelOverride: audioModelOverride,
            ),
          'openrouter' => OpenRouterProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
              textModelOverride: textModelOverride,
              visionModelOverride: visionModelOverride,
              audioModelOverride: audioModelOverride,
            ),
          _ => OpenAiProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
              textModelOverride: textModelOverride,
              visionModelOverride: visionModelOverride,
              audioModelOverride: audioModelOverride,
            ),
        },
      OAuthConfig(
        :final accessToken,
        :final textModelOverride,
        :final visionModelOverride,
        :final audioModelOverride,
      ) =>
        OpenAiProvider(
          apiKey: accessToken,
          modelOverride: modelOverride,
          textModelOverride: textModelOverride,
          visionModelOverride: visionModelOverride,
          audioModelOverride: audioModelOverride,
        ),
      OllamaConfig(
        :final baseUrl,
        :final textModelOverride,
        :final visionModelOverride,
        :final audioModelOverride,
      ) =>
        OllamaProvider(
          modelName: modelOverride,
          baseUrl: baseUrl,
          textModelOverride: textModelOverride,
          visionModelOverride: visionModelOverride,
          audioModelOverride: audioModelOverride,
        ),
    };

/// Returns the canonical provider name for the given [config] (e.g. `'openai'`,
/// `'anthropic'`, `'ollama'`).
String providerNameFromConfig(AiProviderConfig config) => switch (config) {
      ApiKeyConfig(:final providerName) => providerName,
      OAuthConfig(:final providerName) => providerName,
      OllamaConfig() => 'ollama',
    };

/// A injectable version of [buildAiProviderFromConfig].
/// In production, this simply calls [buildAiProviderFromConfig].
/// In tests, override this provider to inject a mock [AiProvider].
final aiProviderBuilderProvider =
    Provider<AiProvider Function(AiProviderConfig)>((ref) {
  return buildAiProviderFromConfig;
});

/// A injectable version of [buildAiProviderFromConfigWithModel].
final aiProviderBuilderWithModelProvider =
    Provider<AiProvider Function(AiProviderConfig, String)>((ref) {
  return buildAiProviderFromConfigWithModel;
});
