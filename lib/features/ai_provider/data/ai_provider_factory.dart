import 'package:prepare_with_atlas/features/ai_provider/data/providers/anthropic_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/gemini_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/ollama_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/openai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/openrouter_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';

/// Returns a concrete [AiProvider] for the given [config].
///
/// Extracted so features outside of [AiProviderController] (such as
/// re-evaluation, where the user picks a provider per-run instead of using
/// the currently active one) can build provider instances on demand.
AiProvider buildAiProviderFromConfig(AiProviderConfig config) =>
    switch (config) {
      ApiKeyConfig(
        :final providerName,
        :final apiKey,
        :final modelOverride,
      ) =>
        switch (providerName) {
          'anthropic' => AnthropicProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
            ),
          'gemini' => GeminiProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
            ),
          'openrouter' => OpenRouterProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
            ),
          _ => OpenAiProvider(
              apiKey: apiKey,
              modelOverride: modelOverride,
            ),
        },
      OAuthConfig(:final accessToken, :final modelOverride) => OpenAiProvider(
          apiKey: accessToken,
          modelOverride: modelOverride,
        ),
      OllamaConfig(:final baseUrl, :final modelName) => OllamaProvider(
          modelName: modelName,
          baseUrl: baseUrl,
        ),
    };

/// Returns the canonical provider name for the given [config] (e.g. `'openai'`,
/// `'anthropic'`, `'ollama'`).
String providerNameFromConfig(AiProviderConfig config) => switch (config) {
      ApiKeyConfig(:final providerName) => providerName,
      OAuthConfig(:final providerName) => providerName,
      OllamaConfig() => 'ollama',
    };
