import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';

/// Form widget for the "All providers" mode where the user picks one model
/// per capability (text / vision / audio) from any configured provider.
///
/// Selection state for the three per-capability picks lives in the parent
/// (because the parent's save handler needs to read it to build the config),
/// so this widget exposes them via constructor + callbacks. Everything else
/// — the loading state, fetched model lists, and which capability tab is
/// active — is local to this widget.
class AllProvidersForm extends ConsumerStatefulWidget {
  /// Creates an [AllProvidersForm].
  const AllProvidersForm({
    required this.ollamaUrlController,
    required this.selectedTextModel,
    required this.selectedVisionModel,
    required this.selectedAudioModel,
    required this.onTextModelSelected,
    required this.onVisionModelSelected,
    required this.onAudioModelSelected,
    required this.onSave,
    super.key,
  });

  /// The Ollama server URL controller, shared with the Ollama form. Used to
  /// fetch the local Ollama model list when probing for available providers.
  final TextEditingController ollamaUrlController;

  /// Currently selected `provider/model` string for the text capability.
  final String selectedTextModel;

  /// Currently selected `provider/model` string for the vision capability.
  final String selectedVisionModel;

  /// Currently selected `provider/model` string for the audio capability.
  final String selectedAudioModel;

  /// Fired when the user picks a text model.
  final ValueChanged<String> onTextModelSelected;

  /// Fired when the user picks a vision model.
  final ValueChanged<String> onVisionModelSelected;

  /// Fired when the user picks an audio model.
  final ValueChanged<String> onAudioModelSelected;

  /// Fired when the user taps "Save Configuration".
  final VoidCallback onSave;

  @override
  ConsumerState<AllProvidersForm> createState() => _AllProvidersFormState();
}

class _AllProvidersFormState extends ConsumerState<AllProvidersForm> {
  bool _isLoading = false;
  String? _loadError;
  String _selectedCapability = 'text';

  /// Models available per provider for text/vision capabilities.
  /// Map: provider name → list of model names.
  Map<String, List<String>> _textModels = const {};

  /// Models available per provider for audio capability.
  Map<String, List<String>> _audioModels = const {};

  bool _initialisedFromConfig = false;

  @override
  void initState() {
    super.initState();
    // Auto-load on first mount so the user sees options without an extra tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadModels());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Initialise selected models from the active provider config the first
    // time the form is built, but only if the parent has nothing pinned.
    if (!_initialisedFromConfig &&
        widget.selectedTextModel.isEmpty &&
        widget.selectedVisionModel.isEmpty &&
        widget.selectedAudioModel.isEmpty) {
      _initialisedFromConfig = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initSelectedModelsFromConfig();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AtlasColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AtlasColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select models by capability from any configured provider. '
                'All three capabilities are evaluated independently.',
                style:
                    TextStyle(color: AtlasColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildCapabilityTabs(),
              const SizedBox(height: 16),
              _buildModelsList(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: widget.onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AtlasColors.accent,
            foregroundColor: AtlasColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save Configuration'),
        ),
      ],
    );
  }

  Widget _buildCapabilityTabs() => Row(
        children: [
          _capabilityTab('text', 'Text', Icons.text_fields),
          const SizedBox(width: 8),
          _capabilityTab('vision', 'Vision', Icons.image),
          const SizedBox(width: 8),
          _capabilityTab('audio', 'Audio', Icons.mic),
        ],
      );

  Widget _capabilityTab(String capability, String label, IconData icon) {
    final isSelected = _selectedCapability == capability;
    final hasSelection = _hasSelectionFor(capability);
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCapability = capability;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AtlasColors.accent : AtlasColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AtlasColors.accent : AtlasColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color:
                    isSelected ? Colors.white : AtlasColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AtlasColors.textSecondary,
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (hasSelection && !isSelected) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AtlasColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            if (isSelected && hasSelection) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, size: 12, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasSelectionFor(String capability) => switch (capability) {
        'text' => widget.selectedTextModel.isNotEmpty,
        'vision' => widget.selectedVisionModel.isNotEmpty,
        'audio' => widget.selectedAudioModel.isNotEmpty,
        _ => false,
      };

  String _currentSelectionFor(String capability) => switch (capability) {
        'text' => widget.selectedTextModel,
        'vision' => widget.selectedVisionModel,
        'audio' => widget.selectedAudioModel,
        _ => '',
      };

  void _selectModel(String capability, String value) {
    switch (capability) {
      case 'text':
        widget.onTextModelSelected(value);
      case 'vision':
        widget.onVisionModelSelected(value);
      case 'audio':
        widget.onAudioModelSelected(value);
    }
  }

  Widget _buildModelsList() {
    if (_isLoading) {
      return const Row(
        children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Loading models...',
              style: TextStyle(color: AtlasColors.textSecondary)),
        ],
      );
    }

    if (_loadError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AtlasColors.danger.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AtlasColors.danger.withAlpha(50)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AtlasColors.danger, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _loadError!,
                style:
                    const TextStyle(color: AtlasColors.danger, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final models = _modelsForCapability(_selectedCapability);
    if (models.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AtlasColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AtlasColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No models available. Configure at least one provider to see '
              'models here.',
              style:
                  TextStyle(color: AtlasColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => unawaited(_loadModels()),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AtlasColors.textSecondary,
                side: const BorderSide(color: AtlasColors.border),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AtlasColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: models.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AtlasColors.border),
        itemBuilder: (context, index) {
          final entry = models[index];
          final providerName = entry['provider']!;
          final modelName = entry['model']!;
          final value = '$providerName/$modelName';
          final currentSelection = _currentSelectionFor(_selectedCapability);
          final isSelected = currentSelection == value;
          return InkWell(
            onTap: () => _selectModel(_selectedCapability, value),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color:
                  isSelected ? AtlasColors.accent.withAlpha(20) : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          modelName,
                          style: TextStyle(
                            color: isSelected
                                ? AtlasColors.accent
                                : AtlasColors.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          providerName,
                          style: const TextStyle(
                            color: AtlasColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check,
                        color: AtlasColors.accent, size: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, String>> _modelsForCapability(String capability) {
    final result = <Map<String, String>>[];
    if (capability == 'text' || capability == 'vision') {
      for (final entry in _textModels.entries) {
        for (final model in entry.value) {
          result.add({'provider': entry.key, 'model': model});
        }
      }
    } else if (capability == 'audio') {
      for (final entry in _audioModels.entries) {
        for (final model in entry.value) {
          result.add({'provider': entry.key, 'model': model});
        }
      }
    }
    return result;
  }

  void _initSelectedModelsFromConfig() {
    final aiState = ref.read(aiProviderControllerProvider);
    final config = aiState.activeConfig;
    if (config == null) return;

    switch (config) {
      case ApiKeyConfig(
          :final providerName,
          :final textModelOverride,
          :final visionModelOverride,
          :final audioModelOverride,
        ):
        if (textModelOverride != null && textModelOverride.isNotEmpty) {
          widget.onTextModelSelected('$providerName/$textModelOverride');
        }
        if (visionModelOverride != null && visionModelOverride.isNotEmpty) {
          widget.onVisionModelSelected('$providerName/$visionModelOverride');
        }
        if (audioModelOverride != null && audioModelOverride.isNotEmpty) {
          widget.onAudioModelSelected('$providerName/$audioModelOverride');
        }
      case OAuthConfig(
          :final textModelOverride,
          :final visionModelOverride,
          :final audioModelOverride,
        ):
        // OAuth always uses OpenAI provider.
        if (textModelOverride != null && textModelOverride.isNotEmpty) {
          widget.onTextModelSelected('openai/$textModelOverride');
        }
        if (visionModelOverride != null && visionModelOverride.isNotEmpty) {
          widget.onVisionModelSelected('openai/$visionModelOverride');
        }
        if (audioModelOverride != null && audioModelOverride.isNotEmpty) {
          widget.onAudioModelSelected('openai/$audioModelOverride');
        }
      case OllamaConfig(
          :final textModelOverride,
          :final visionModelOverride,
          :final audioModelOverride,
        ):
        if (textModelOverride != null && textModelOverride.isNotEmpty) {
          widget.onTextModelSelected('ollama/$textModelOverride');
        }
        if (visionModelOverride != null && visionModelOverride.isNotEmpty) {
          widget.onVisionModelSelected('ollama/$visionModelOverride');
        }
        if (audioModelOverride != null && audioModelOverride.isNotEmpty) {
          widget.onAudioModelSelected('ollama/$audioModelOverride');
        }
    }
  }

  /// Probes each provider's stored config and assembles the per-capability
  /// model catalogs. Providers without a stored API key are skipped, except
  /// for Ollama which uses the URL field.
  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final textModels = <String, List<String>>{};
    final audioModels = <String, List<String>>{};

    final openAiKey = await _getStoredApiKey('openai');
    if (openAiKey != null) {
      textModels['openai'] = ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo'];
      audioModels['openai'] = ['whisper-1'];
    }

    final anthropicKey = await _getStoredApiKey('anthropic');
    if (anthropicKey != null) {
      textModels['anthropic'] = [
        'claude-sonnet-4-20250514',
        'claude-3-5-sonnet-latest',
        'claude-3-5-haiku-latest',
      ];
      audioModels['anthropic'] = const []; // No audio support
    }

    final geminiKey = await _getStoredApiKey('gemini');
    if (geminiKey != null) {
      textModels['gemini'] = [
        'gemini-2.0-flash',
        'gemini-1.5-pro',
        'gemini-1.5-flash',
      ];
      audioModels['gemini'] = ['gemini-2.0-flash'];
    }

    final openRouterKey = await _getStoredApiKey('openrouter');
    if (openRouterKey != null) {
      textModels['openrouter'] = [
        'openai/gpt-4o',
        'anthropic/claude-sonnet-4',
        'google/gemini-2.0-flash',
      ];
      audioModels['openrouter'] = const [];
    }

    final ollamaUrl = widget.ollamaUrlController.text.trim();
    if (ollamaUrl.isNotEmpty) {
      try {
        final models = await ref
            .read(aiProviderControllerProvider.notifier)
            .fetchOllamaModels(ollamaUrl);
        if (models.isNotEmpty) {
          textModels['ollama'] = models;
          // Most Ollama models can be used for transcription too.
          audioModels['ollama'] = models;
        }
      } catch (_) {
        // Ollama unreachable; leave it out of the catalogs.
      }
    }

    if (!mounted) return;
    setState(() {
      _textModels = textModels;
      _audioModels = audioModels;
      _isLoading = false;
      if (textModels.isEmpty && audioModels.isEmpty) {
        _loadError =
            'No providers configured. Add API keys in the provider tabs above.';
      }
    });
  }

  Future<String?> _getStoredApiKey(String provider) async {
    final aiState = ref.read(aiProviderControllerProvider);
    final config = aiState.activeConfig;
    if (config == null) return null;
    return switch (config) {
      ApiKeyConfig(:final providerName, :final apiKey)
          when providerName == provider =>
        apiKey,
      _ => null,
    };
  }
}

