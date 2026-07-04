# Spec 05: AI Provider System — spec.md

## Summary

A pluggable AI provider system that lets users connect to their preferred AI service. Supports API key authentication for OpenAI, Anthropic, Google Gemini, and OpenRouter. Supports OAuth 2.1/PKCE for OpenAI (ChatGPT Plus/Pro subscriptions). Supports local Ollama via URL configuration. Each provider implements a common interface for text+image completions.

## User Stories

- **US-05.1**: As a user, I can configure my AI provider by entering an API key for OpenAI, Anthropic, Gemini, or OpenRouter.
- **US-05.2**: As a user, I can sign in with my ChatGPT Plus/Pro subscription via OAuth to use OpenAI without an API key.
- **US-05.3**: As a user, I can connect to a local Ollama instance by providing its URL.
- **US-05.4**: As a user, I can test my AI connection to verify it works before starting an interview.
- **US-05.5**: As a user, I can switch between configured providers.
- **US-05.6**: As a user, my API keys are stored securely and not visible in plain text.
- **US-05.7**: As a user, I can configure separate models for text evaluation, vision (diagrams), and audio transcription — allowing me to use a fast/cheap model for transcription while using a more capable model for full evaluation.

## Acceptance Criteria

- [ ] AI Settings screen shows provider picker with all 5 providers
- [ ] API key input field with obscured text and "Show/Hide" toggle
- [ ] "Test Connection" button sends a minimal prompt and shows success/failure result
- [ ] OpenAI OAuth flow opens system browser, handles redirect callback, stores tokens
- [ ] Ollama configuration accepts custom URL; "Load available models" button queries `/api/tags` and populates a model dropdown
- [ ] When no models are installed, shows actionable empty state with `ollama pull llama3` copyable command and link to ollama.com/library
- [ ] When Ollama server is unreachable, shows a distinct error state (separate from no-models state)
- [ ] "Save & Test Connection" button is disabled until a model is selected from the dropdown
- [ ] Only one provider is active at a time; switching deactivates the previous one
- [ ] API keys are encrypted in the database using macOS Keychain-backed encryption
- [ ] Each provider correctly translates prompts to its API format (including multimodal image support)
- [ ] AI Settings screen shows model dropdowns for each capability: "Model for text evaluation", "Model for vision (diagrams)", "Model for audio transcription" — each populated by the model's discovery flow; defaults are pre-selected
- [ ] All tests pass

## Functional Requirements

- **FR-05.1**: `AIProvider` abstract class with methods: `complete(systemPrompt, userPrompt, imageBytes?, imageMimeType?)`, `testConnection()`, `providerName` getter, `currentModel` getter, `supportsVision` getter, `supportsAudioTranscription` getter, `supportsNativeAudio` getter.
- **FR-05.2**: `AIProviderConfig` sealed union with variants: `ApiKeyConfig`, `OAuthConfig`, `OllamaConfig`.
- **FR-05.3**: Provider implementations translate to each API's format:
  - OpenAI: `POST /v1/chat/completions` with `gpt-4o` default
  - Anthropic: `POST /v1/messages` with `claude-sonnet-4-20250514` default
  - Gemini: `POST /v1/models/{model}:generateContent` with `gemini-2.0-flash` default
  - OpenRouter: `POST /api/v1/chat/completions` (OpenAI-compatible format)
  - Ollama: `POST /api/chat` with user-selected model
- **FR-05.4**: Multimodal support: OpenAI, Anthropic, Gemini, and OpenRouter support image input. Ollama support depends on model (gracefully degrade if model doesn't support vision).
- **FR-05.5**: API keys encrypted with AES-256-GCM; encryption key stored in macOS Keychain via `flutter_secure_storage`.
- **FR-05.6**: OpenAI OAuth 2.1/PKCE: custom URI scheme (`preparewith-atlas://oauth/callback`), browser-based auth, token storage with auto-refresh. **Note:** OpenAI does not expose a public OAuth endpoint for ChatGPT Plus/Pro subscriptions to third-party apps; the "Sign in with ChatGPT" button is wired to `signInWithOpenAiOAuth()` but the flow does not complete in practice. Full support is deferred to V1.1.
- **FR-05.7**: `AIProviderController` manages: active provider, config persistence, provider switching, connection testing.
- **FR-05.8**: Ollama model discovery: when the Ollama provider is selected in AI Settings, the user taps "Load available models" to query `GET /api/tags` and populate a dropdown of installed model names. The dropdown replaces the free-text model name field. The user must select a model before the "Save & Test Connection" button is enabled.
- **FR-05.9**: Ollama empty state: if the Ollama server responds with an empty models list, show an actionable install instructions panel with: the text "No models installed", a copyable `ollama pull llama3` command, and a link to `ollama.com/library`. A "Check again" button re-triggers model discovery.
- **FR-05.10**: Ollama unreachable state: if the Ollama server cannot be reached at the configured URL, show a distinct error state ("Cannot reach Ollama at {url}. Is it running?") — separate from the empty-models state. The user can correct the URL and try again.
- **FR-05.11**: `OllamaProvider.fetchModels(baseUrl, {Dio? dio})` is a static method that queries `/api/tags` and returns `List<String>` of model names. Throws `AiProviderException` on connection errors. `AiProviderController.fetchOllamaModels(baseUrl)` delegates to it.
- **FR-05.12**: Gemini model discovery: when the Gemini provider is selected in AI Settings, the user taps "Load available models" to call the Gemini REST API (`GET /v1beta/models?key=...`), filtered to models supporting `generateContent`. The resulting list populates a dropdown; the "Save & Test Connection" button is disabled until a model is selected.
- **FR-05.13**: `GeminiProvider.fetchModels(apiKey, {Dio? dio})` is a static method that queries `GET /v1beta/models?key=apiKey`, filters by `supportedGenerationMethods.contains("generateContent")`, strips the `"models/"` prefix, and returns `List<String>`. Throws `AiProviderException` on HTTP or connectivity errors. `GeminiProvider.fetchModels` (used by the controller) delegates to it.
- **FR-05.14**: Multi-capability model routing: each AI call site specifies a `Capability` (`text`, `vision`, or `audio`) rather than a provider name. `EvaluationController` resolves the best available model for each capability from the active provider config: text → `modelForText`, vision → `modelForVision`, audio transcription → `modelForAudio`. If no separate model is configured for a capability, the default model is used. This allows e.g. using Haiku for fast transcription while using Sonnet for full evaluation.

## Non-Functional Requirements

- **NFR-05.1**: Connection test completes in < 10 seconds.
- **NFR-05.2**: API key encryption/decryption < 50ms.
- **NFR-05.3**: OAuth token refresh happens proactively (before expiry), not on-demand during evaluation.
- **NFR-05.4**: No API keys logged or exposed in debug output.

## Edge Cases

- **EC-05.1**: Invalid API key → testConnection returns clear error message: "Invalid API key. Please check your key and try again."
- **EC-05.2**: Network timeout during AI call → throw timeout exception with retry option.
- **EC-05.3**: Ollama not running at configured URL → "Load available models" shows the unreachable error state: "Cannot reach Ollama at {url}. Is it running?" User can update URL and retry.
- **EC-05.3a**: Ollama running but no models installed → shows empty-state panel with `ollama pull llama3` instruction and "Check again" button. "Save & Test Connection" remains disabled.
- **EC-05.3b**: User hasn't tapped "Load available models" yet → "Save & Test Connection" is disabled; model dropdown is not shown.
- **EC-05.4**: OAuth redirect fails (user cancels or browser blocks) → show error, fall back to API key option.
- **EC-05.5**: OAuth token expired and refresh fails → prompt user to re-authenticate.
- **EC-05.6**: Rate limit hit → return error with provider-specific rate limit message.
- **EC-05.7**: Provider API changes format → version the API calls, log unexpected responses.
- **EC-05.8**: Gemini selected but API key field is empty when "Load available models" is tapped → show snackbar "Enter your Gemini API key first." and do not make a network call.
- **EC-05.9**: Gemini API key invalid or unauthorized when loading models (HTTP 400/401/403) → picker shows error state with "Invalid API key. Check your Gemini API key and try again." and a "Try again" button. "Save & Test Connection" remains disabled.
- **EC-05.10**: Gemini model list returns empty → picker shows error state with "No models found for this API key." "Save & Test Connection" remains disabled.
- **EC-05.11**: User switches away from Gemini to another provider → Gemini picker state resets to `initial`; previously loaded model list and selection are cleared.
