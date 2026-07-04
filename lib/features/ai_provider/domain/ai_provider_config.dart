import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_provider_config.freezed.dart';
part 'ai_provider_config.g.dart';

/// Sealed union of AI provider authentication configurations.
@freezed
sealed class AiProviderConfig with _$AiProviderConfig {
  /// API key based authentication.
  const factory AiProviderConfig.apiKey({
    /// The canonical provider name (e.g. 'openai', 'anthropic').
    required String providerName,

    /// The API key, stored encrypted and decrypted in memory only.
    required String apiKey,

    /// Optional model override; empty string means use provider default.
    @Default('') String modelOverride,

    /// Per-capability model override for multi-model evaluation.
    /// Format: 'providerName:modelName' (e.g., 'openai:gpt-4o').
    @Default(null) String? visionModelOverride,
    @Default(null) String? audioModelOverride,
    @Default(null) String? textModelOverride,
  }) = ApiKeyConfig;

  /// OAuth 2.1/PKCE based authentication (OpenAI only).
  const factory AiProviderConfig.oauth({
    /// The canonical provider name (always 'openai' for OAuth).
    required String providerName,

    /// The short-lived access token.
    required String accessToken,

    /// The refresh token for obtaining new access tokens.
    required String refreshToken,

    /// The UTC date/time when [accessToken] expires.
    required DateTime expiresAt,

    /// Optional model override; empty string means use provider default.
    @Default('') String modelOverride,

    /// Per-capability model override for multi-model evaluation.
    @Default(null) String? visionModelOverride,
    @Default(null) String? audioModelOverride,
    @Default(null) String? textModelOverride,
  }) = OAuthConfig;

  /// Local Ollama configuration.
  const factory AiProviderConfig.ollama({
    /// The name of the model to use (e.g. 'llama3').
    required String modelName,

    /// The base URL of the local Ollama server.
    @Default('http://localhost:11434') String baseUrl,

    /// Per-capability model override for multi-model evaluation.
    @Default(null) String? visionModelOverride,
    @Default(null) String? audioModelOverride,
    @Default(null) String? textModelOverride,
  }) = OllamaConfig;

  /// Deserializes an [AiProviderConfig] from [json].
  factory AiProviderConfig.fromJson(Map<String, dynamic> json) =>
      _$AiProviderConfigFromJson(json);
}
