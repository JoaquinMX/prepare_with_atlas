import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_controller.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_state.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';

/// The settings screen for configuring the active AI provider.
///
/// Allows the user to select a provider, enter credentials, and test
/// the connection. Credentials are stored encrypted via
/// Keychain-backed AES-256.
class AiSettingsScreen extends ConsumerStatefulWidget {
  /// Creates an [AiSettingsScreen].
  const AiSettingsScreen({required this.controller, super.key});

  /// The [AiProviderController] notifier to use for state management.
  final AiProviderController controller;

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

/// Possible states for the Gemini model picker.
enum _GeminiPickerState { initial, loading, loaded, error }

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  String _selectedProvider = 'openai';
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _ollamaUrlController =
      TextEditingController(text: 'http://localhost:11434');
  final _ollamaModelController = TextEditingController();
  bool _apiKeyObscured = true;

  // Gemini model picker state
  _GeminiPickerState _geminiPickerState = _GeminiPickerState.initial;
  List<String> _geminiModels = [];
  String? _selectedGeminiModel;
  String? _geminiPickerError;

  static const _providers = [
    ('openai', 'OpenAI', Icons.auto_awesome),
    ('anthropic', 'Anthropic', Icons.psychology),
    ('gemini', 'Google Gemini', Icons.star),
    ('openrouter', 'OpenRouter', Icons.hub),
    ('ollama', 'Ollama', Icons.computer),
  ];

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _ollamaUrlController.dispose();
    _ollamaModelController.dispose();
    super.dispose();
  }

  // ── Gemini model loading ──────────────────────────────────────────────────

  Future<void> _loadGeminiModels() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your Gemini API key first.')),
      );
      return;
    }
    setState(() {
      _geminiPickerState = _GeminiPickerState.loading;
      _geminiModels = [];
      _selectedGeminiModel = null;
      _geminiPickerError = null;
    });
    try {
      final models = await widget.controller.fetchGeminiModels(apiKey);
      if (!mounted) return;
      setState(() {
        _geminiModels = models;
        _geminiPickerState = models.isEmpty
            ? _GeminiPickerState.error
            : _GeminiPickerState.loaded;
        _geminiPickerError =
            models.isEmpty ? 'No models found for this API key.' : null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _geminiPickerState = _GeminiPickerState.error;
        _geminiPickerError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
          _buildProviderPicker(),
          const SizedBox(height: 24),
          _buildConfigForm(),
          const SizedBox(height: 24),
          _buildTestResult(),
          const SizedBox(height: 24),
          _buildSecurityCard(),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() => const Text(
        'Settings / AI Provider',
        style: TextStyle(
          color: AtlasColors.textMuted,
          fontSize: 13,
        ),
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
        'Configure how PrepareWithAtlas evaluates your interviews',
        style: TextStyle(
          color: AtlasColors.textSecondary,
          fontSize: 14,
        ),
      );

  Widget _buildProviderPicker() => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _providers.map((p) {
          final (id, name, icon) = p;
          final isSelected = _selectedProvider == id;
          return GestureDetector(
            onTap: () => setState(() {
                  _selectedProvider = id;
                  if (id != 'gemini') {
                    _geminiPickerState = _GeminiPickerState.initial;
                    _geminiModels = [];
                    _selectedGeminiModel = null;
                    _geminiPickerError = null;
                  }
                }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AtlasColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AtlasColors.accent
                      : AtlasColors.border,
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
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
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
              hintStyle:
                  const TextStyle(color: AtlasColors.textMuted),
              filled: true,
              fillColor: AtlasColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AtlasColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AtlasColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AtlasColors.accent),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _apiKeyObscured
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: AtlasColors.textMuted,
                ),
                onPressed: () =>
                    setState(() => _apiKeyObscured = !_apiKeyObscured),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedProvider == 'gemini')
            _buildGeminiModelPicker()
          else ...[
            _fieldLabel('Model Override (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _modelController,
              style: const TextStyle(color: AtlasColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Leave empty to use provider default',
                hintStyle:
                    const TextStyle(color: AtlasColors.textMuted),
                filled: true,
                fillColor: AtlasColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AtlasColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AtlasColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AtlasColors.accent),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_selectedProvider == 'openai') ...[
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ChatGPT OAuth sign-in is coming in V1.1.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign in with ChatGPT'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AtlasColors.textSecondary,
                side: const BorderSide(color: AtlasColors.border),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _onSaveAndTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AtlasColors.accent,
              foregroundColor: AtlasColors.textPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save & Test Connection'),
          ),
        ],
      );

  Widget _buildOllamaForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Ollama Server URL'),
          const SizedBox(height: 8),
          TextField(
            controller: _ollamaUrlController,
            style: const TextStyle(color: AtlasColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'http://localhost:11434',
              hintStyle:
                  const TextStyle(color: AtlasColors.textMuted),
              filled: true,
              fillColor: AtlasColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AtlasColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AtlasColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AtlasColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Model Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _ollamaModelController,
            style: const TextStyle(color: AtlasColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. llama3, mistral',
              hintStyle:
                  const TextStyle(color: AtlasColors.textMuted),
              filled: true,
              fillColor: AtlasColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AtlasColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AtlasColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AtlasColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _onSaveAndTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AtlasColors.accent,
              foregroundColor: AtlasColors.textPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save & Test Connection'),
          ),
        ],
      );

  Widget _buildGeminiModelPicker() {
    return switch (_geminiPickerState) {
      _GeminiPickerState.initial => OutlinedButton.icon(
          onPressed: _loadGeminiModels,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Load available models'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AtlasColors.textSecondary,
            side: const BorderSide(color: AtlasColors.border),
          ),
        ),
      _GeminiPickerState.loading => const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AtlasColors.accent,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading models...',
              style: TextStyle(color: AtlasColors.textSecondary),
            ),
          ],
        ),
      _GeminiPickerState.loaded => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Model'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AtlasColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AtlasColors.border),
              ),
              child: DropdownButton<String>(
                value: _selectedGeminiModel,
                isExpanded: true,
                dropdownColor: AtlasColors.surface,
                underline: const SizedBox.shrink(),
                hint: const Text(
                  'Select a model',
                  style: TextStyle(color: AtlasColors.textMuted),
                ),
                style: const TextStyle(color: AtlasColors.textPrimary),
                items: _geminiModels
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedGeminiModel = v),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadGeminiModels,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh list'),
              style: TextButton.styleFrom(
                foregroundColor: AtlasColors.textMuted,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      _GeminiPickerState.error => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _geminiPickerError ?? 'Failed to load models.',
              style: const TextStyle(
                color: AtlasColors.danger,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadGeminiModels,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try again'),
              style: TextButton.styleFrom(
                foregroundColor: AtlasColors.textSecondary,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
    };
  }

  Widget _fieldLabel(String label) => Text(
        label,
        style: const TextStyle(
          color: AtlasColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _buildTestResult() {
    // This widget displays test results from the controller state.
    // In a real implementation, this would watch a provider.
    // For now it's a placeholder that shows after save.
    return const SizedBox.shrink();
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
            Icon(
              Icons.shield_outlined,
              color: AtlasColors.success,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your API key is encrypted with macOS Keychain-backed '
                'AES-256 and never transmitted outside the app.',
                style: TextStyle(
                  color: AtlasColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _onSaveAndTest() async {
    final config = _buildConfig();
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.'),
        ),
      );
      return;
    }
    await widget.controller.setProvider(config);
    final testPassed = await widget.controller.runTestConnection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          testPassed.message,
        ),
        backgroundColor: testPassed.success
            ? AtlasColors.success
            : AtlasColors.danger,
      ),
    );
  }

  AiProviderConfig? _buildConfig() {
    if (_selectedProvider == 'ollama') {
      final model = _ollamaModelController.text.trim();
      if (model.isEmpty) return null;
      return AiProviderConfig.ollama(
        baseUrl: _ollamaUrlController.text.trim(),
        modelName: model,
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
      );
    }
    return AiProviderConfig.apiKey(
      providerName: _selectedProvider,
      apiKey: key,
      modelOverride: _modelController.text.trim(),
    );
  }
}

/// A test-result row widget used below the config form.
class AiProviderTestResultRow extends StatelessWidget {
  /// Creates an [AiProviderTestResultRow].
  const AiProviderTestResultRow({required this.state, super.key});

  /// The current [AiProviderState] to display.
  final AiProviderState state;

  @override
  Widget build(BuildContext context) {
    if (state.isTesting) {
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

    final success = state.testSuccess;
    final message = state.testResultMessage;
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
              color:
                  success ? AtlasColors.success : AtlasColors.danger,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
