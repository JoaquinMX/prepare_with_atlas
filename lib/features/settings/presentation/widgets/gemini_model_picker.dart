import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';

/// Possible states for the Gemini model picker.
enum _PickerState { initial, loading, loaded, error }

/// Picker widget that loads available Gemini models for a given API key and
/// lets the user select one.
///
/// State machine:
///   initial → user clicks "Load available models" → loading
///   loading → fetch succeeds → loaded
///   loading → fetch fails or returns empty → error
///   loaded  → user can refresh or pick a model
///   error   → user can try again
///
/// The parent owns the persisted [selectedModel] and observes selection
/// changes via [onModelSelected]; the loading state and the fetched model
/// list are local to this widget because they are recoverable on re-mount.
class GeminiModelPicker extends ConsumerStatefulWidget {
  /// Creates a [GeminiModelPicker].
  const GeminiModelPicker({
    required this.apiKeyController,
    required this.selectedModel,
    required this.onModelSelected,
    super.key,
  });

  /// Controller backing the API key input shown above this picker. The picker
  /// reads its current value on each load attempt.
  final TextEditingController apiKeyController;

  /// Currently selected model id, or `null` if the user has not picked one.
  final String? selectedModel;

  /// Callback fired when the user selects (or clears) a model.
  final ValueChanged<String?> onModelSelected;

  @override
  ConsumerState<GeminiModelPicker> createState() => _GeminiModelPickerState();
}

class _GeminiModelPickerState extends ConsumerState<GeminiModelPicker> {
  _PickerState _pickerState = _PickerState.initial;
  List<String> _models = const [];
  String? _pickerError;

  Future<void> _loadModels() async {
    final apiKey = widget.apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your Gemini API key first.')),
      );
      return;
    }
    setState(() {
      _pickerState = _PickerState.loading;
      _models = const [];
      widget.onModelSelected(null);
      _pickerError = null;
    });
    try {
      final models = await ref
          .read(aiProviderControllerProvider.notifier)
          .fetchGeminiModels(apiKey);
      if (!mounted) return;
      setState(() {
        _models = models;
        _pickerState = models.isEmpty
            ? _PickerState.error
            : _PickerState.loaded;
        _pickerError = models.isEmpty
            ? 'No models found for this API key.'
            : null;
      });
    } on AiProviderException catch (e) {
      if (!mounted) return;
      setState(() {
        _pickerState = _PickerState.error;
        _pickerError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pickerState = _PickerState.error;
        _pickerError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_pickerState) {
      _PickerState.initial => OutlinedButton.icon(
        onPressed: () => unawaited(_loadModels()),
        icon: const Icon(Icons.search, size: 18),
        label: const Text('Load available models'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AtlasColors.textSecondary,
          side: const BorderSide(color: AtlasColors.border),
        ),
      ),
      _PickerState.loading => const Row(
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
      _PickerState.loaded => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Model'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: widget.selectedModel,
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
            items: _models
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: widget.onModelSelected,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => unawaited(_loadModels()),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh list'),
            style: TextButton.styleFrom(
              foregroundColor: AtlasColors.textMuted,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      _PickerState.error => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _pickerError ?? 'Failed to load Gemini models.',
            style: const TextStyle(color: AtlasColors.danger, fontSize: 13),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => unawaited(_loadModels()),
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
    style: const TextStyle(color: AtlasColors.textSecondary, fontSize: 13),
  );
}
