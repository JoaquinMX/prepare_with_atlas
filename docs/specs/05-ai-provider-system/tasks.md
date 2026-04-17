# Spec 05: AI Provider System — tasks.md

## Phase 1: Domain Layer (TDD)

- **T001**: Write tests for `AIProviderConfig` sealed union — verify: `ApiKeyConfig` creation + serialization, `OAuthConfig` creation with token expiry, `OllamaConfig` creation with default URL.
- **T002**: Implement `AIProviderConfig` freezed sealed class with 3 variants.
- **T003**: Define `AIProvider` abstract class with `complete()`, `testConnection()`, `providerName`.
- **T004**: Define `AIMessage` model for structured prompt/response pairs.

## Phase 2: Security (TDD)

- **T005**: Write tests for `KeyEncryptionService` — verify: encrypt then decrypt returns original, different plaintexts produce different ciphertexts, decryption with wrong key fails.
- **T006**: Implement `KeyEncryptionService` using AES-256-GCM with key from `flutter_secure_storage`.
- **T007**: Write tests for `SecureConfigRepository` — verify: save config encrypts API key before storage, load config decrypts, delete removes from DB and Keychain.
- **T008**: Implement `SecureConfigRepository` wrapping `DriftAiProviderConfigRepository` with encryption.

## Phase 3: Provider Implementations (TDD)

- **T009**: Write tests for `OpenAIProvider` — verify: complete() sends correct request format to `/v1/chat/completions`, multimodal request includes base64 image, testConnection() sends minimal prompt, error responses throw appropriate exceptions.
- **T010**: Implement `OpenAIProvider` using dio.
- **T011**: Write tests for `AnthropicProvider` — verify: correct `/v1/messages` format, `anthropic-version` header, multimodal with base64 image in content blocks.
- **T012**: Implement `AnthropicProvider`.
- **T013**: Write tests for `GeminiProvider` — verify: correct `generateContent` format, inline image data.
- **T014**: Implement `GeminiProvider`.
- **T015**: Write tests for `OpenRouterProvider` — verify: OpenAI-compatible format with `HTTP-Referer` and `X-Title` headers.
- **T016**: Implement `OpenRouterProvider`.
- **T017**: Write tests for `OllamaProvider` — verify: correct `/api/chat` format, model listing via `/api/tags`, graceful handling of non-vision models.
- **T018**: Implement `OllamaProvider`.
- **T018a**: Write tests for `OllamaProvider.fetchModels(baseUrl, {Dio? dio})` static method — verify: returns model names from `/api/tags`, returns empty list when models array absent, throws `AiProviderException` on connection error. ✅ Done
- **T018b**: Implement `OllamaProvider.fetchModels` static method and `AiProviderController.fetchOllamaModels` delegate. ✅ Done

## Phase 4: Controller + Presentation (TDD)

- **T019**: Write tests for `AIProviderController` — verify: setActiveProvider saves and encrypts config, getActiveProvider loads and decrypts, switchProvider deactivates old + activates new, testConnection delegates to provider.
- **T020**: Implement `AIProviderController` (StateNotifier).
- **T021**: Write widget tests for `AISettingsScreen` — verify: provider picker shows all 5 options, selecting provider shows correct config form, API key input is obscured, "Test Connection" button triggers test and shows result.
- **T022**: Implement `AISettingsScreen` with provider picker and dynamic config forms.
- **T023**: Implement `ProviderConfigForm` variants: API key input (with show/hide), Ollama URL + model picker, OAuth button (OpenAI only).
- **T023a**: Write widget tests for Ollama model picker in `AISettingsScreen` — verify: "Load available models" button shown initially; after tap shows dropdown when models exist; shows "No models installed" empty state with `ollama pull llama3` and "Check again" when no models; shows error state when Ollama unreachable. ✅ Done
- **T023b**: Implement Ollama model picker with 4 states: initial, loading, dropdown (models found), empty-state (no models or unreachable). Disable save button until model selected. ✅ Done
- **T023c**: Implement `GeminiProvider.fetchModels(apiKey, {Dio? dio})` static method and `AiProviderController.fetchGeminiModels(apiKey)` delegate. ✅ Done
- **T023d**: Implement Gemini model picker in `AiSettingsScreen` with 4 states: initial ("Load available models" button), loading (spinner), loaded (dropdown), error (message + "Try again"). Disable "Save & Test Connection" until model selected. Reset picker state when switching away from Gemini. ✅ Done

## Phase 5: OAuth (TDD)

- **T024**: Write tests for `OpenAIOAuthService` — verify: generates PKCE code_verifier and code_challenge, builds correct authorization URL, exchanges code for tokens, refreshes expired tokens. ✅ Done
- **T025**: Implement `OpenAIOAuthService` with PKCE flow — `exchangeCodeForTokens`, `refreshTokens`, `authenticate` using `Completer<String>` + MethodChannel. ✅ Done
- **T026**: Register custom URI scheme `com.joaquinmx.preparewithatlas` in `macos/Runner/Info.plist` (`CFBundleURLTypes`). ✅ Done
- **T027**: Implement OAuth callback handler in `macos/Runner/AppDelegate.swift` — override `application(_:open:)` to forward URL to Flutter via `FlutterMethodChannel("com.joaquinmx.preparewithatlas/oauth")`. ✅ Done
- **T028**: Implement proactive token refresh in `AiProviderController` — `Timer.periodic(5 min)` checks expiry, refreshes silently when < 10 min remaining, cancelled via `ref.onDispose`. ✅ Done
- **T028a**: Wire "Sign in with ChatGPT" button in `AISettingsScreen` to call `signInWithOpenAiOAuth()`. ✅ Done
- **T029**: Integration test: full OAuth flow with mock auth server.
