import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/ai_provider_config_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/ai_provider_factory.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';

/// Opens a modal bottom sheet letting the user pick an [AiProviderConfig]
/// for a one-off re-evaluation run. Returns the picked config, or `null` if
/// the user dismissed the sheet without selecting.
Future<AiProviderConfig?> showReEvaluateProviderSheet(
  BuildContext context,
) =>
    showModalBottomSheet<AiProviderConfig>(
      context: context,
      backgroundColor: AtlasColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const _ReEvaluateProviderSheet(),
    );

class _ReEvaluateProviderSheet extends ConsumerStatefulWidget {
  const _ReEvaluateProviderSheet();

  @override
  ConsumerState<_ReEvaluateProviderSheet> createState() =>
      _ReEvaluateProviderSheetState();
}

class _ReEvaluateProviderSheetState
    extends ConsumerState<_ReEvaluateProviderSheet> {
  late Future<List<AiProviderConfig>> _configsFuture;

  @override
  void initState() {
    super.initState();
    _configsFuture =
        ref.read(aiProviderConfigRepositoryProvider).getAll();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Re-evaluate with…',
              style: TextStyle(
                color: AtlasColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick an AI provider for a second opinion on this session. '
              'The new evaluation will be saved alongside the original.',
              style: TextStyle(
                color: AtlasColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<AiProviderConfig>>(
              future: _configsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AtlasColors.accent,
                      ),
                    ),
                  );
                }
                final configs = snap.data ?? const <AiProviderConfig>[];
                if (configs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No AI providers are configured. Open Settings to '
                      'add one first.',
                      style: TextStyle(color: AtlasColors.textSecondary),
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final config in configs)
                      _ProviderTile(
                        config: config,
                        onTap: () => Navigator.of(context).pop(config),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.config, required this.onTap});

  final AiProviderConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = providerNameFromConfig(config);
    final subtitle = switch (config) {
      ApiKeyConfig(:final modelOverride) => modelOverride.isEmpty
          ? 'Provider default model'
          : modelOverride,
      OAuthConfig(:final modelOverride) => modelOverride.isEmpty
          ? 'Provider default model'
          : modelOverride,
      OllamaConfig(:final modelName, :final baseUrl) => '$modelName · $baseUrl',
    };

    return Material(
      key: Key('re_eval_provider_${name}_tile'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AtlasColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AtlasColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AtlasColors.accent,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(name),
                      style: const TextStyle(
                        color: AtlasColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AtlasColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AtlasColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _displayName(String providerName) => switch (providerName) {
        'openai' => 'OpenAI',
        'anthropic' => 'Anthropic',
        'gemini' => 'Gemini',
        'openrouter' => 'OpenRouter',
        'ollama' => 'Ollama',
        _ => providerName,
      };
}
