import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_state.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';
import 'package:prepare_with_atlas/features/settings/presentation/widgets/all_providers_form.dart';
import 'package:prepare_with_atlas/features/settings/presentation/widgets/gemini_model_picker.dart';
import 'package:prepare_with_atlas/features/settings/presentation/widgets/ollama_settings_form.dart';
import 'package:prepare_with_atlas/features/settings/presentation/widgets/openai_oauth_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings screen for configuring the active AI provider.
///
/// Displays all supported providers, lets the user enter credentials, and
/// tests the connection using [aiProviderControllerProvider].
class AiSettingsScreen extends ConsumerStatefulWidget {
  /// Creates an [AiSettingsScreen].
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  String _selectedProvider = 'openai';
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _ollamaUrlController = TextEditingController(
    text: 'http://localhost:11434',
  );

  // Per-capability model overrides
  final _textModelController = TextEditingController();
  final _visionModelController = TextEditingController();
  final _audioModelController = TextEditingController();
  bool _showCapabilityModels = false;

  String? _selectedOllamaModel;

  // "All" consolidated model picker selections (parent-owned because the
  // save handler builds the config from them; the picker itself lives in
  // [AllProvidersForm]).
  String _selectedTextModel = '';
  String _selectedVisionModel = '';
  String _selectedAudioModel = '';

  // Gemini model picker selection (the picker widget owns its own loading
  // state machine; the parent only retains the user's last selection so it
  // survives navigation away from the gemini provider tab).
  String? _selectedGeminiModel;

  bool _apiKeyObscured = true;

  static const _providers = [
    ('openai', 'OpenAI', Icons.auto_awesome),
    ('anthropic', 'Anthropic', Icons.psychology),
    ('gemini', 'Google Gemini', Icons.star),
    ('openrouter', 'OpenRouter', Icons.hub),
    ('ollama', 'Ollama', Icons.computer),
    ('all', 'All', Icons.select_all),
  ];

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _ollamaUrlController.dispose();
    _textModelController.dispose();
    _visionModelController.dispose();
    _audioModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiProviderControllerProvider);
    final activeProviderName = switch (aiState.activeConfig) {
      ApiKeyConfig(:final providerName) => providerName,
      OAuthConfig(:final providerName) => providerName,
      OllamaConfig() => 'ollama',
      null => null,
    };

    return Scaffold(
      backgroundColor: AtlasColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBreadcrumb(),
            const SizedBox(height: 8),
            _buildTitle(),
            const SizedBox(height: 4),
            _buildSubtitle(),
            const SizedBox(height: 32),
            _buildProviderPicker(activeProviderName),
            const SizedBox(height: 24),
            _buildConfigForm(),
            const SizedBox(height: 24),
            _buildTestResult(aiState),
            const SizedBox(height: 24),
            _buildSecurityCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() => const Text(
    'Settings / AI Provider',
    style: TextStyle(color: AtlasColors.textMuted, fontSize: 13),
  );

  Widget _buildTitle() => const Text(
    'AI Provider',
    style: TextStyle(
      color: AtlasColors.textPrimary,
      fontSize: 28,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _buildSubtitle() => const Text(
    'Configure how PrepareWithAtlas evaluates your interviews.',
    style: TextStyle(color: AtlasColors.textSecondary, fontSize: 14),
  );

  Widget _buildProviderPicker(String? activeProviderName) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: _providers.map((p) {
      final (id, name, icon) = p;
      final isSelected = _selectedProvider == id;
      final isActive = activeProviderName == id;
      return GestureDetector(
        onTap: () => setState(() {
          _selectedProvider = id;
          if (id != 'gemini' && id != 'all') {
            // The picker widget resets its internal state on rebuild;
            // we only need to clear the parent-owned selection.
            _selectedGeminiModel = null;
          }
          // The "All" form auto-loads its catalogs in initState; no parent
          // bookkeeping is needed when the user switches to it.
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AtlasColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AtlasColors.accent : AtlasColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AtlasColors.accent
                    : AtlasColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  color: isSelected
                      ? AtlasColors.textPrimary
                      : AtlasColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AtlasColors.success,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }).toList(),
  );

  Widget _buildConfigForm() {
    if (_selectedProvider == 'ollama') {
      return _buildOllamaForm();
    }
    if (_selectedProvider == 'all') {
      return AllProvidersForm(
        ollamaUrlController: _ollamaUrlController,
        selectedTextModel: _selectedTextModel,
        selectedVisionModel: _selectedVisionModel,
        selectedAudioModel: _selectedAudioModel,
        onTextModelSelected: (v) => setState(() => _selectedTextModel = v),
        onVisionModelSelected: (v) =>
            setState(() => _selectedVisionModel = v),
        onAudioModelSelected: (v) => setState(() => _selectedAudioModel = v),
        onSave: _onSaveAllModels,
      );
    }
    return _buildApiKeyForm();
  }

  Widget _buildApiKeyForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel('API Key'),
      const SizedBox(height: 8),
      TextField(
        controller: _apiKeyController,
        obscureText: _apiKeyObscured,
        style: const TextStyle(color: AtlasColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Enter your API key',
          hintStyle: const TextStyle(color: AtlasColors.textMuted),
          filled: true,
          fillColor: AtlasColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AtlasColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AtlasColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AtlasColors.accent),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _apiKeyObscured ? Icons.visibility_off : Icons.visibility,
              color: AtlasColors.textMuted,
            ),
            onPressed: () => setState(() => _apiKeyObscured = !_apiKeyObscured),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (_selectedProvider == 'gemini')
        GeminiModelPicker(
          apiKeyController: _apiKeyController,
          selectedModel: _selectedGeminiModel,
          onModelSelected: (model) =>
              setState(() => _selectedGeminiModel = model),
        )
      else ...[
        _fieldLabel('Model Override (optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _modelController,
          style: const TextStyle(color: AtlasColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Leave empty to use provider default',
            hintStyle: const TextStyle(color: AtlasColors.textMuted),
            filled: true,
            fillColor: AtlasColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AtlasColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AtlasColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AtlasColors.accent),
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      if (_selectedProvider == 'openai') ...[
        const OpenAiOAuthButton(),
        const SizedBox(height: 12),
      ],
      _buildCapabilityModelsSection(),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _onSaveAndTest,
        style: ElevatedButton.styleFrom(
          backgroundColor: AtlasColors.accent,
          foregroundColor: AtlasColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Save & Test Connection'),
      ),
    ],
  );

  Widget _buildOllamaForm() => OllamaSettingsForm(
    ollamaUrlController: _ollamaUrlController,
    selectedOllamaModel: _selectedOllamaModel,
    onModelSelected: (model) => setState(() => _selectedOllamaModel = model),
    onSaveAndTest: _onSaveAndTest,
    textModelController: _textModelController,
    visionModelController: _visionModelController,
    audioModelController: _audioModelController,
    buildCapabilityModelsSection: _buildCapabilityModelsSection,
  );

  Future<String?> _getStoredApiKey(String provider) async {
    // Read stored config from the controller's state
    final aiState = ref.read(aiProviderControllerProvider);
    final config = aiState.activeConfig;
    if (config == null) return null;
    return switch (config) {
      ApiKeyConfig(:final providerName, :final apiKey)
          when providerName == provider => apiKey,
      _ => null,
    };
  }

  Future<void> _onSaveAllModels() async {
    // Collect all three per-capability selections
    final textParts = _selectedTextModel.split('/');
    final visionParts = _selectedVisionModel.split('/');
    final audioParts = _selectedAudioModel.split('/');

    if (textParts.length != 2 && visionParts.length != 2 && audioParts.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one model to save.')),
      );
      return;
    }

    // If any selection is from Ollama, use the Ollama URL; otherwise use the first available API key
    String? providerName;
    String? apiKey;
    if (textParts.length == 2) {
      providerName = textParts[0];
    } else if (visionParts.length == 2) {
      providerName = visionParts[0];
    } else if (audioParts.length == 2) {
      providerName = audioParts[0];
    }

    if (providerName != 'ollama') {
      apiKey = await _getStoredApiKey(providerName ?? 'openai');
    }

    AiProviderConfig config;
    if (providerName == 'ollama') {
      config = AiProviderConfig.ollama(
        baseUrl: _ollamaUrlController.text.trim(),
        modelName: textParts.length == 2 ? textParts[1] : 'llama3',
        textModelOverride: textParts.length == 2 ? textParts[1] : null,
        visionModelOverride: visionParts.length == 2 ? visionParts[1] : null,
        audioModelOverride: audioParts.length == 2 ? audioParts[1] : null,
      );
    } else {
      config = AiProviderConfig.apiKey(
        providerName: providerName ?? 'openai',
        apiKey: apiKey ?? '',
        modelOverride: textParts.length == 2 ? textParts[1] : '',
        textModelOverride: textParts.length == 2 ? textParts[1] : null,
        visionModelOverride: visionParts.length == 2 ? visionParts[1] : null,
        audioModelOverride: audioParts.length == 2 ? audioParts[1] : null,
      );
    }

    final notifier = ref.read(aiProviderControllerProvider.notifier);
    await notifier.setProvider(config);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved per-capability models.'),
        backgroundColor: AtlasColors.success,
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: AtlasColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _buildTestResult(AiProviderState aiState) {
    if (aiState.isTesting) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Testing connection...',
            style: TextStyle(color: AtlasColors.textSecondary),
          ),
        ],
      );
    }

    final success = aiState.testSuccess;
    final message = aiState.testResultMessage;
    if (success == null || message == null) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(
          success ? Icons.check_circle : Icons.cancel,
          color: success ? AtlasColors.success : AtlasColors.danger,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: success ? AtlasColors.success : AtlasColors.danger,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AtlasColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AtlasColors.border),
    ),
    child: const Row(
      children: [
        Icon(Icons.shield_outlined, color: AtlasColors.success, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Your API key is encrypted with macOS Keychain-backed '
            'AES-256 and never transmitted outside the app.',
            style: TextStyle(color: AtlasColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Future<void> _onSaveAndTest() async {
    final config = _buildConfig();
    if (config == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }
    final notifier = ref.read(aiProviderControllerProvider.notifier);
    await notifier.setProvider(config);

    // Check whether setProvider succeeded before testing.
    // On failure (e.g. Keychain unavailable) activeProvider stays null
    // and state.errorMessage carries the real error.
    final stateAfterSave = ref.read(aiProviderControllerProvider);
    if (stateAfterSave.activeProvider == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stateAfterSave.errorMessage ?? 'Failed to save provider config.',
          ),
          backgroundColor: AtlasColors.danger,
        ),
      );
      return;
    }

    final testResult = await notifier.runTestConnection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(testResult.message),
        backgroundColor: testResult.success
            ? AtlasColors.success
            : AtlasColors.danger,
      ),
    );
  }

  AiProviderConfig? _buildConfig() {
    if (_selectedProvider == 'ollama') {
      final model = _selectedOllamaModel;
      if (model == null || model.isEmpty) return null;
      return AiProviderConfig.ollama(
        baseUrl: _ollamaUrlController.text.trim(),
        modelName: model,
        textModelOverride: _textModelController.text.trim().isEmpty
            ? null
            : _textModelController.text.trim(),
        visionModelOverride: _visionModelController.text.trim().isEmpty
            ? null
            : _visionModelController.text.trim(),
        audioModelOverride: _audioModelController.text.trim().isEmpty
            ? null
            : _audioModelController.text.trim(),
      );
    }
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return null;
    if (_selectedProvider == 'gemini') {
      final model = _selectedGeminiModel;
      if (model == null) return null;
      return AiProviderConfig.apiKey(
        providerName: _selectedProvider,
        apiKey: key,
        modelOverride: model,
        textModelOverride: _textModelController.text.trim().isEmpty
            ? null
            : _textModelController.text.trim(),
        visionModelOverride: _visionModelController.text.trim().isEmpty
            ? null
            : _visionModelController.text.trim(),
        audioModelOverride: _audioModelController.text.trim().isEmpty
            ? null
            : _audioModelController.text.trim(),
      );
    }
    return AiProviderConfig.apiKey(
      providerName: _selectedProvider,
      apiKey: key,
      modelOverride: _modelController.text.trim(),
      textModelOverride: _textModelController.text.trim().isEmpty
          ? null
          : _textModelController.text.trim(),
      visionModelOverride: _visionModelController.text.trim().isEmpty
          ? null
          : _visionModelController.text.trim(),
      audioModelOverride: _audioModelController.text.trim().isEmpty
          ? null
          : _audioModelController.text.trim(),
    );
  }

  Widget _buildCapabilityModelsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _showCapabilityModels = !_showCapabilityModels),
            child: Row(
              children: [
                Icon(
                  _showCapabilityModels
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: AtlasColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  'Per-Capability Models',
                  style: TextStyle(
                    color: _showCapabilityModels
                        ? AtlasColors.textPrimary
                        : AtlasColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AtlasColors.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Advanced',
                    style: TextStyle(
                      color: AtlasColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showCapabilityModels) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AtlasColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AtlasColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Override models for specific tasks. '
                    'Leave empty to use the default model above.',
                    style: TextStyle(
                      color: AtlasColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CapabilityModelRow(
                    icon: Icons.text_fields,
                    label: 'Text Evaluation',
                    hint: 'e.g. claude-sonnet-4-20250514',
                    controller: _textModelController,
                    description: 'Full evaluation, reasoning, narrative',
                  ),
                  const SizedBox(height: 10),
                  _CapabilityModelRow(
                    icon: Icons.image,
                    label: 'Vision',
                    hint: 'e.g. gpt-4o',
                    controller: _visionModelController,
                    description: 'Whiteboard diagram analysis',
                  ),
                  const SizedBox(height: 10),
                  _CapabilityModelRow(
                    icon: Icons.mic,
                    label: 'Audio Transcription',
                    hint: 'e.g. whisper-1',
                    controller: _audioModelController,
                    description: 'FLAC audio → text',
                  ),
                ],
              ),
            ),
          ],
        ],
      );
}

/// A row widget for entering a per-capability model override.
class _CapabilityModelRow extends StatelessWidget {
  /// Creates a [_CapabilityModelRow].
  const _CapabilityModelRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AtlasColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AtlasColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: AtlasColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: controller,
                style: const TextStyle(
                  color: AtlasColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: AtlasColors.textMuted),
                  filled: true,
                  fillColor: AtlasColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AtlasColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AtlasColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AtlasColors.accent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
