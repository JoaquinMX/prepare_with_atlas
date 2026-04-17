import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_state.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/ai_provider_config_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/openai_oauth_service.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/anthropic_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/gemini_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/ollama_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/openai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/providers/openrouter_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config_repository.dart';

/// The outcome of an AI provider connection test.
class AiTestResult {
  /// Creates an [AiTestResult].
  const AiTestResult({
    required this.success,
    required this.message,
  });

  /// Whether the test succeeded.
  final bool success;

  /// Human-readable result message.
  final String message;
}

/// Riverpod [Notifier] that manages the active AI provider.
///
/// On [build], loads the previously saved active config from the repository
/// and constructs the corresponding [AiProvider] instance. When an
/// [OAuthConfig] is active, a periodic timer proactively refreshes the
/// access token before it expires.
class AiProviderController extends Notifier<AiProviderState> {
  Timer? _refreshTimer;

  AiProviderConfigRepository get _repository =>
      ref.read(aiProviderConfigRepositoryProvider);

  @override
  AiProviderState build() {
    ref.onDispose(() => _refreshTimer?.cancel());
    Future.microtask(_loadActive);
    return const AiProviderState(isLoading: true);
  }

  Future<void> _loadActive() async {
    try {
      final config = await _repository.getActive();
      if (config != null) {
        final provider = _buildProvider(config);
        dev.log(
          '_loadActive: loaded provider=${_providerNameOf(config)}',
          name: 'AiProviderController',
        );
        state = AiProviderState(
          activeProvider: provider,
          activeConfig: config,
        );
        if (config is OAuthConfig) {
          _scheduleTokenRefresh(config);
        }
      } else {
        dev.log(
          '_loadActive: no active provider found',
          name: 'AiProviderController',
        );
        state = const AiProviderState();
      }
    } catch (e) {
      dev.log(
        '_loadActive: failed to load provider — $e',
        name: 'AiProviderController',
        level: 1000, // SEVERE
      );
      state = AiProviderState(errorMessage: e.toString());
    }
  }

  /// Saves [config] as the active provider and rebuilds the provider instance.
  Future<void> setProvider(AiProviderConfig config) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.save(config);
      await _repository.setActive(_providerNameOf(config));
      final provider = _buildProvider(config);
      state = AiProviderState(
        activeProvider: provider,
        activeConfig: config,
      );
      if (config is OAuthConfig) {
        _scheduleTokenRefresh(config);
      } else {
        _refreshTimer?.cancel();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Initiates the OpenAI OAuth 2.1/PKCE browser flow.
  ///
  /// Opens the system browser, waits for the redirect callback, then
  /// stores the resulting [OAuthConfig] as the active provider.
  /// An optional [oauthService] may be injected for testing.
  Future<void> signInWithOpenAiOAuth({
    OpenAiOAuthService? oauthService,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final config = await (oauthService ?? OpenAiOAuthService())
          .authenticate();
      await setProvider(config);
    } on AiProviderException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Tests the connection for the currently active provider.
  ///
  /// Updates [AiProviderState.isTesting], [AiProviderState.testSuccess],
  /// and [AiProviderState.testResultMessage].
  Future<void> testConnection() async {
    final provider = state.activeProvider;
    if (provider == null) {
      state = state.copyWith(
        testSuccess: false,
        testResultMessage:
            'No AI provider configured. Go to Settings.',
      );
      return;
    }

    state = state.copyWith(
      isTesting: true,
      testResultMessage: null,
      testSuccess: null,
    );

    try {
      await provider.testConnection();
      state = state.copyWith(
        isTesting: false,
        testSuccess: true,
        testResultMessage: 'Connection successful.',
      );
    } on AiProviderException catch (e) {
      state = state.copyWith(
        isTesting: false,
        testSuccess: false,
        testResultMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isTesting: false,
        testSuccess: false,
        testResultMessage: e.toString(),
      );
    }
  }

  /// Tests the connection and returns an [AiTestResult] with the outcome.
  ///
  /// Also updates the notifier state with the result.
  Future<AiTestResult> runTestConnection() async {
    await testConnection();
    final s = state;
    return AiTestResult(
      success: s.testSuccess ?? false,
      message: s.testResultMessage ?? 'Unknown result',
    );
  }

  /// Returns the currently active [AiProvider].
  ///
  /// Throws [AiProviderException] if no provider has been configured.
  AiProvider getActiveProvider() {
    final provider = state.activeProvider;
    if (provider == null) {
      throw const AiProviderException(
        'No AI provider configured. Go to Settings.',
      );
    }
    return provider;
  }

  // ── Ollama model discovery ───────────────────────────────────────

  /// Returns installed model names from the Ollama server at [baseUrl].
  ///
  /// Throws [AiProviderException] if the server is unreachable.
  Future<List<String>> fetchOllamaModels(String baseUrl) =>
      OllamaProvider.fetchModels(baseUrl);

  /// Returns Gemini model names that support `generateContent` for [apiKey].
  ///
  /// Throws [AiProviderException] if the key is invalid or unreachable.
  Future<List<String>> fetchGeminiModels(String apiKey) =>
      GeminiProvider.fetchModels(apiKey);

  // ── Token refresh ────────────────────────────────────────────────

  void _scheduleTokenRefresh(OAuthConfig config) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _maybeRefreshToken(),
    );
  }

  Future<void> _maybeRefreshToken() async {
    final config = state.activeConfig;
    if (config is! OAuthConfig) {
      _refreshTimer?.cancel();
      return;
    }

    final timeToExpiry =
        config.expiresAt.difference(DateTime.now());
    if (timeToExpiry > const Duration(minutes: 10)) return;

    try {
      final refreshed =
          await OpenAiOAuthService().refreshTokens(config);
      await _repository.save(refreshed);
      await _repository.setActive('openai');
      state = state.copyWith(
        activeConfig: refreshed,
        activeProvider: _buildProvider(refreshed),
      );
    } catch (_) {
      // Silent failure — next 5-min tick will retry.
    }
  }

  // ── Provider factory ─────────────────────────────────────────────

  AiProvider _buildProvider(AiProviderConfig config) =>
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
        OAuthConfig(:final accessToken, :final modelOverride) =>
          OpenAiProvider(
            apiKey: accessToken,
            modelOverride: modelOverride,
          ),
        OllamaConfig(:final baseUrl, :final modelName) =>
          OllamaProvider(
            modelName: modelName,
            baseUrl: baseUrl,
          ),
      };

  String _providerNameOf(AiProviderConfig config) => switch (config) {
        ApiKeyConfig(:final providerName) => providerName,
        OAuthConfig(:final providerName) => providerName,
        OllamaConfig() => 'ollama',
      };
}
