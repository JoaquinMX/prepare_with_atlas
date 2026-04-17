import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_providers.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_state.dart';

/// Screen displayed while an AI evaluation is in progress.
///
/// Shows a loading spinner with status text, or an error message with a
/// retry button if the evaluation fails.
class EvaluationLoadingScreen extends ConsumerWidget {
  /// Creates an [EvaluationLoadingScreen].
  const EvaluationLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigate to result screen as soon as evaluation succeeds.
    ref.listen<EvaluationState>(evaluationControllerProvider, (_, next) {
      if (next is EvaluationSuccess) {
        context.go('/evaluation/result');
      }
    });

    final state = ref.watch(evaluationControllerProvider);

    return Scaffold(
      backgroundColor: AtlasColors.background,
      body: Center(
        child: switch (state) {
          EvaluationLoading(:final statusText) =>
            _LoadingView(statusText: statusText),
          EvaluationError(:final message, :final canRetry) => _ErrorView(
              message: message,
              canRetry: canRetry,
              onRetry: canRetry
                  ? () => ref
                      .read(evaluationControllerProvider.notifier)
                      .retry()
                  : null,
            ),
          EvaluationIdle() => const _LoadingView(
              statusText: 'Preparing evaluation...',
            ),
          EvaluationSuccess() => const _LoadingView(
              statusText: 'Evaluation complete. Navigating...',
            ),
        },
      ),
    );
  }
}

class _LoadingView extends StatefulWidget {
  const _LoadingView({required this.statusText});

  final String statusText;

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> {
  late final DateTime _startedAt;
  late final Timer _ticker;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSeconds =
              DateTime.now().difference(_startedAt).inSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          color: AtlasColors.accent,
          strokeWidth: 3,
        ),
        const SizedBox(height: 32),
        Text(
          widget.statusText,
          style: const TextStyle(
            color: AtlasColors.textSecondary,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          '$_elapsedLabel elapsed · typically 30–90 seconds',
          style: const TextStyle(
            color: AtlasColors.textMuted,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.canRetry,
    required this.onRetry,
  });

  final String message;
  final bool canRetry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: AtlasColors.danger,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Evaluation Failed',
            style: TextStyle(
              color: AtlasColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AtlasColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (canRetry && onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AtlasColors.accent,
                foregroundColor: AtlasColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
