import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_state.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Possible states for the Gemini model picker.
enum _GeminiPickerState { initial, loading, loaded, error }

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

  // Ollama model discovery state
  // null  = not yet attempted
  // []    = server reachable but no models installed
  // [...] = models available
  List<String>? _ollamaModels;
  bool _isLoadingModels = false;
  // Non-null only when Ollama is unreachable (distinct from empty models list).
  String? _ollamaModelsError;
  String? _selectedOllamaModel;

  // Gemini model picker state
  _GeminiPickerState _geminiPickerState = _GeminiPickerState.initial;
  List<String> _geminiModels = [];
  String? _selectedGeminiModel;
  String? _geminiPickerError;

  bool _apiKeyObscured = true;

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
          if (id != 'gemini') {
            _geminiPickerState = _GeminiPickerState.initial;
            _geminiModels = [];
            _selectedGeminiModel = null;
            _geminiPickerError = null;
          }
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
        _buildGeminiModelPicker()
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
        OutlinedButton.icon(
          onPressed: _onSignInWithChatGpt,
          icon: const Icon(Icons.login),
          label: const Text('Sign in with ChatGPT'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AtlasColors.textSecondary,
            side: const BorderSide(color: AtlasColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
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

  Widget _buildOllamaForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel('Ollama Server URL'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ollamaUrlController,
              style: const TextStyle(color: AtlasColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'http://localhost:11434',
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
              onSubmitted: (_) => unawaited(_loadOllamaModels()),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Reload models',
            icon: const Icon(Icons.refresh, color: AtlasColors.textSecondary),
            onPressed: () => unawaited(_loadOllamaModels()),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _fieldLabel('Model'),
      const SizedBox(height: 8),
      _buildModelPicker(),
      if (_ollamaModels != null && _ollamaModels!.isNotEmpty) ...[
        const SizedBox(height: 12),
        _buildCloudModelsNote(),
      ],
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _selectedOllamaModel != null ? _onSaveAndTest : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AtlasColors.accent,
          foregroundColor: AtlasColors.textPrimary,
          disabledBackgroundColor: AtlasColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Save & Test Connection'),
      ),
    ],
  );

  Widget _buildModelPicker() {
    if (_isLoadingModels) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Loading models…',
            style: TextStyle(color: AtlasColors.textSecondary),
          ),
        ],
      );
    }

    final models = _ollamaModels;

    // Not yet attempted — show load button.
    if (models == null) {
      return OutlinedButton.icon(
        onPressed: () => unawaited(_loadOllamaModels()),
        icon: const Icon(Icons.search),
        label: const Text('Load available models'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AtlasColors.textSecondary,
          side: const BorderSide(color: AtlasColors.border),
        ),
      );
    }

    // Server unreachable or no models installed.
    if (models.isEmpty) {
      final isError = _ollamaModelsError != null;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AtlasColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AtlasColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.info_outline,
                  color: isError ? AtlasColors.danger : AtlasColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isError ? 'Cannot reach Ollama' : 'No models installed',
                  style: const TextStyle(
                    color: AtlasColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (isError) ...[
              const SizedBox(height: 6),
              Text(
                _ollamaModelsError!,
                style: const TextStyle(
                  color: AtlasColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Run these commands in your terminal to install'
              ' local or cloud models:',
              style: TextStyle(color: AtlasColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AtlasColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AtlasColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Local model:',
                    style: TextStyle(
                      color: AtlasColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  SelectableText(
                    'ollama pull <model-name>',
                    style: TextStyle(
                      color: AtlasColors.textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Cloud model:',
                    style: TextStyle(
                      color: AtlasColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  SelectableText(
                    'ollama run <model-name>:cloud',
                    style: TextStyle(
                      color: AtlasColors.textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                GestureDetector(
                  onTap: () => unawaited(
                    launchUrl(Uri.parse('https://ollama.com/library')),
                  ),
                  child: const Text(
                    'Browse library →',
                    style: TextStyle(
                      color: AtlasColors.accent,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => unawaited(
                    launchUrl(Uri.parse('https://ollama.com/search?c=cloud')),
                  ),
                  child: const Text(
                    'Browse cloud models →',
                    style: TextStyle(
                      color: AtlasColors.accent,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => unawaited(
                    launchUrl(Uri.parse('https://www.canirun.ai/')),
                  ),
                  child: const Text(
                    'Check if model runs on your PC →',
                    style: TextStyle(
                      color: AtlasColors.accent,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => unawaited(_loadOllamaModels()),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Check again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AtlasColors.textSecondary,
                side: const BorderSide(color: AtlasColors.border),
              ),
            ),
          ],
        ),
      );
    }

    // Models available — show dropdown.
    return DropdownButtonFormField<String>(
      initialValue: _selectedOllamaModel,
      dropdownColor: AtlasColors.surface,
      style: const TextStyle(color: AtlasColors.textPrimary),
      decoration: InputDecoration(
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
      hint: const Text(
        'Select a model',
        style: TextStyle(color: AtlasColors.textMuted),
      ),
      items: models
          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
          .toList(),
      onChanged: (value) => setState(() => _selectedOllamaModel = value),
    );
  }

  Widget _buildCloudModelsNote() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Run these commands in your terminal to install'
          ' local or cloud models:',
          style: TextStyle(color: AtlasColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AtlasColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AtlasColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Local model:',
                style: TextStyle(
                  color: AtlasColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              SelectableText(
                'ollama pull <model-name>',
                style: TextStyle(
                  color: AtlasColors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Cloud model:',
                style: TextStyle(
                  color: AtlasColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              SelectableText(
                'ollama run <model-name>:cloud',
                style: TextStyle(
                  color: AtlasColors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            GestureDetector(
              onTap: () => unawaited(
                launchUrl(Uri.parse('https://ollama.com/search?c=cloud')),
              ),
              child: const Text(
                'Browse cloud models →',
                style: TextStyle(
                  color: AtlasColors.accent,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  unawaited(launchUrl(Uri.parse('https://www.canirun.ai/'))),
              child: const Text(
                'Check if model runs on your PC →',
                style: TextStyle(
                  color: AtlasColors.accent,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadOllamaModels() async {
    setState(() {
      _isLoadingModels = true;
      _ollamaModelsError = null;
    });
    try {
      final url = _ollamaUrlController.text.trim();
      final models = await ref
          .read(aiProviderControllerProvider.notifier)
          .fetchOllamaModels(url);
      if (!mounted) return;
      setState(() {
        _ollamaModels = models;
        _isLoadingModels = false;
        if (models.isNotEmpty) {
          _selectedOllamaModel ??= models.first;
        }
      });
    } on AiProviderException catch (e) {
      if (!mounted) return;
      setState(() {
        _ollamaModels = [];
        _isLoadingModels = false;
        _ollamaModelsError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ollamaModels = [];
        _isLoadingModels = false;
        _ollamaModelsError = 'Could not connect to Ollama. Is it running?';
      });
    }
  }

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
      final models = await ref
          .read(aiProviderControllerProvider.notifier)
          .fetchGeminiModels(apiKey);
      if (!mounted) return;
      setState(() {
        _geminiModels = models;
        _geminiPickerState = models.isEmpty
            ? _GeminiPickerState.error
            : _GeminiPickerState.loaded;
        _geminiPickerError = models.isEmpty
            ? 'No models found for this API key.'
            : null;
      });
    } on AiProviderException catch (e) {
      if (!mounted) return;
      setState(() {
        _geminiPickerState = _GeminiPickerState.error;
        _geminiPickerError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _geminiPickerState = _GeminiPickerState.error;
        _geminiPickerError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _buildGeminiModelPicker() {
    return switch (_geminiPickerState) {
      _GeminiPickerState.initial => OutlinedButton.icon(
        onPressed: () => unawaited(_loadGeminiModels()),
        icon: const Icon(Icons.search, size: 18),
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
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Loading models…',
            style: TextStyle(color: AtlasColors.textSecondary),
          ),
        ],
      ),
      _GeminiPickerState.loaded => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Model'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedGeminiModel,
            dropdownColor: AtlasColors.surface,
            style: const TextStyle(color: AtlasColors.textPrimary),
            decoration: InputDecoration(
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
            hint: const Text(
              'Select a model',
              style: TextStyle(color: AtlasColors.textMuted),
            ),
            items: _geminiModels
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _selectedGeminiModel = v),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => unawaited(_loadGeminiModels()),
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
            _geminiPickerError ?? 'Failed to load Gemini models.',
            style: const TextStyle(color: AtlasColors.danger, fontSize: 13),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => unawaited(_loadGeminiModels()),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AtlasColors.textSecondary,
              side: const BorderSide(color: AtlasColors.border),
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

  Future<void> _onSignInWithChatGpt() async {
    final notifier = ref.read(aiProviderControllerProvider.notifier);
    await notifier.signInWithOpenAiOAuth();
    if (!mounted) return;
    final error = ref.read(aiProviderControllerProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Signed in with ChatGPT successfully.'),
        backgroundColor: error != null
            ? AtlasColors.danger
            : AtlasColors.success,
      ),
    );
  }

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
