import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// A form widget for configuring Ollama as an AI provider.
///
/// Handles server URL entry, model discovery, and selection with
/// capability-specific overrides.
class OllamaSettingsForm extends ConsumerStatefulWidget {
  /// Creates an [OllamaSettingsForm].
  const OllamaSettingsForm({
    required this.ollamaUrlController,
    required this.onModelSelected,
    required this.onSaveAndTest,
    required this.selectedOllamaModel,
    required this.textModelController,
    required this.visionModelController,
    required this.audioModelController,
    required this.buildCapabilityModelsSection,
    super.key,
  });

  /// Controller for the Ollama server URL.
  final TextEditingController ollamaUrlController;

  /// Callback when a model is selected.
  final Function(String? model) onModelSelected;

  /// Callback to save and test the configuration.
  final VoidCallback onSaveAndTest;

  /// Currently selected Ollama model.
  final String? selectedOllamaModel;

  /// Controller for text model override.
  final TextEditingController textModelController;

  /// Controller for vision model override.
  final TextEditingController visionModelController;

  /// Controller for audio model override.
  final TextEditingController audioModelController;

  /// Widget builder for capability-specific model overrides section.
  final Widget Function() buildCapabilityModelsSection;

  @override
  ConsumerState<OllamaSettingsForm> createState() => _OllamaSettingsFormState();
}

class _OllamaSettingsFormState extends ConsumerState<OllamaSettingsForm> {
  // Ollama model discovery state
  // null  = not yet attempted
  // []    = server reachable but no models installed
  // [...] = models available
  List<String>? _ollamaModels;
  bool _isLoadingModels = false;
  // Non-null only when Ollama is unreachable (distinct from empty models list).
  String? _ollamaModelsError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Ollama Server URL'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.ollamaUrlController,
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
        widget.buildCapabilityModelsSection(),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: widget.selectedOllamaModel != null ? widget.onSaveAndTest : null,
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
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: AtlasColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
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
      initialValue: widget.selectedOllamaModel,
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
      onChanged: widget.onModelSelected,
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
      final url = widget.ollamaUrlController.text.trim();
      final models = await ref
          .read(aiProviderControllerProvider.notifier)
          .fetchOllamaModels(url);
      if (!mounted) return;
      setState(() {
        _ollamaModels = models;
        _isLoadingModels = false;
        if (models.isNotEmpty) {
          // Auto-select first model if none selected yet
          if (widget.selectedOllamaModel == null) {
            widget.onModelSelected(models.first);
          }
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
}
