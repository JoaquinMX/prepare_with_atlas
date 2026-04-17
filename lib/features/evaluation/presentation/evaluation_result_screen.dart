import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_providers.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_state.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/evaluation/presentation/score_card_widget.dart';

/// Screen displaying the full AI evaluation result for a completed session.
class EvaluationResultScreen extends ConsumerWidget {
  /// Creates an [EvaluationResultScreen].
  const EvaluationResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(evaluationControllerProvider);

    return Scaffold(
      backgroundColor: AtlasColors.background,
      body: switch (state) {
        EvaluationSuccess(:final result) => _ResultView(result: result),
        _ => const Center(
            child: Text(
              'No evaluation result available.',
              style: TextStyle(color: AtlasColors.textSecondary),
            ),
          ),
      },
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final EvaluationResult result;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          ScoreCardWidget(result: result),
          const SizedBox(height: 32),
          _buildStrengths(),
          const SizedBox(height: 24),
          _buildImprovements(),
          const SizedBox(height: 24),
          _buildNarrative(),
          if (result.referenceComparison != null) ...[
            const SizedBox(height: 24),
            _buildReferenceComparison(result.referenceComparison!),
          ],
          const SizedBox(height: 40),
          _buildBackButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Evaluation Complete',
                  style: TextStyle(
                    color: AtlasColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by ${result.providerUsed} · ${result.modelUsed}',
                  style: const TextStyle(
                    color: AtlasColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildStrengths() => _SectionCard(
        title: 'Strengths',
        icon: Icons.thumb_up_outlined,
        iconColor: AtlasColors.success,
        children: result.strengths
            .map(
              (s) => _BulletItem(text: s, color: AtlasColors.success),
            )
            .toList(),
      );

  Widget _buildImprovements() => _SectionCard(
        title: 'Areas for Improvement',
        icon: Icons.trending_up,
        iconColor: AtlasColors.warning,
        children: result.improvements
            .map(
              (s) => _BulletItem(text: s, color: AtlasColors.warning),
            )
            .toList(),
      );

  Widget _buildNarrative() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Feedback',
            style: TextStyle(
              color: AtlasColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AtlasColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: MarkdownBody(
              data: result.narrative,
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(
                  color: AtlasColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                h2: const TextStyle(
                  color: AtlasColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                p: const TextStyle(
                  color: AtlasColors.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildReferenceComparison(String comparison) => _SectionCard(
        title: 'Reference Comparison',
        icon: Icons.compare_arrows,
        iconColor: AtlasColors.accent,
        children: [
          Text(
            comparison,
            style: const TextStyle(
              color: AtlasColors.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      );

  Widget _buildBackButton(BuildContext context) => Center(
        child: ElevatedButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Back to Home'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AtlasColors.surface,
            foregroundColor: AtlasColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            side: const BorderSide(color: AtlasColors.border),
          ),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AtlasColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AtlasColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
