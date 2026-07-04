import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_providers.dart';

/// Inline button that lets the user sign in to OpenAI via the ChatGPT OAuth
/// flow as an alternative to pasting an API key.
///
/// On success, surfaces a confirmation snackbar; on failure, shows the
/// controller's most recent error message. The widget owns the snackbar
/// presentation so the parent screen does not need to know about the OAuth
/// flow's outcome.
class OpenAiOAuthButton extends ConsumerWidget {
  /// Creates an [OpenAiOAuthButton].
  const OpenAiOAuthButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => _signIn(context, ref),
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
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(aiProviderControllerProvider.notifier);
    await notifier.signInWithOpenAiOAuth();
    if (!context.mounted) return;
    final error = ref.read(aiProviderControllerProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Signed in with ChatGPT successfully.'),
        backgroundColor:
            error != null ? AtlasColors.danger : AtlasColors.success,
      ),
    );
  }
}
