import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/history/application/comparison_controller.dart';
import 'package:prepare_with_atlas/features/history/application/comparison_state.dart';
import 'package:prepare_with_atlas/features/history/domain/progress_diff.dart';

/// Maps scorecard dimension keys to human-readable labels.
const _dimensionLabels = {
  'requirementsGathering': 'Requirements Gathering',
  'estimationQuality': 'Estimation Quality',
  'highLevelDesign': 'High-Level Design',
  'deepDiveQuality': 'Deep Dive Quality',
  'scalingAwareness': 'Scaling Awareness',
  'communicationClarity': 'Communication Clarity',
  'overall': 'Overall',
};

/// Side-by-side comparison of two session evaluations.
///
/// Accepts [priorSessionId] and [currentSessionId] as route parameters,
/// loads both evaluations via [ComparisonController], and renders a
/// per-dimension delta table.
class ProgressComparisonScreen extends ConsumerStatefulWidget {
  /// Creates a [ProgressComparisonScreen].
  const ProgressComparisonScreen({
    required this.priorSessionId,
    required this.currentSessionId,
    super.key,
  });

  /// Session ID of the baseline (earlier) session.
  final String priorSessionId;

  /// Session ID of the more recent session.
  final String currentSessionId;

  @override
  ConsumerState<ProgressComparisonScreen> createState() =>
      _ProgressComparisonScreenState();
}

class _ProgressComparisonScreenState
    extends ConsumerState<ProgressComparisonScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(comparisonControllerProvider.notifier).loadComparison(
            priorSessionId: widget.priorSessionId,
            currentSessionId: widget.currentSessionId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(comparisonControllerProvider);

    return Scaffold(
      backgroundColor: AtlasColors.background,
      appBar: AppBar(
        backgroundColor: AtlasColors.surface,
        title: const Text(
          'Progress Comparison',
          style: TextStyle(color: AtlasColors.textPrimary),
        ),
      ),
      body: switch (state) {
        ComparisonLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
        ComparisonError(:final message) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                message,
                style: const TextStyle(
                  color: AtlasColors.danger,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ComparisonSuccess(:final diff) => _ComparisonView(diff: diff),
        ComparisonIdle() => const SizedBox.shrink(),
      },
    );
  }
}

// ── Comparison Table ─────────────────────────────────────────────────────────

class _ComparisonView extends StatelessWidget {
  const _ComparisonView({required this.diff});

  final ProgressDiff diff;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverallTrend(),
          const SizedBox(height: 24),
          _buildHeader(),
          const Divider(color: AtlasColors.border, height: 1),
          ..._dimensionLabels.entries.map(_buildDimensionRow),
        ],
      ),
    );
  }

  Widget _buildOverallTrend() {
    final priorOverall = diff.priorEvaluation.scorecard['overall'] ??
        diff.priorEvaluation.overallScore;
    final currentOverall =
        diff.currentEvaluation.scorecard['overall'] ??
        diff.currentEvaluation.overallScore;
    final delta = diff.overallDelta;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AtlasColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ScoreColumn(label: 'Prior', score: priorOverall),
          _DeltaChip(delta: delta),
          _ScoreColumn(label: 'Current', score: currentOverall),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Dimension',
              style: TextStyle(
                color: AtlasColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _headerCell('Prior'),
          _headerCell('Delta'),
          _headerCell('Current'),
        ],
      ),
    );
  }

  Widget _headerCell(String text) => SizedBox(
        width: 60,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AtlasColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _buildDimensionRow(MapEntry<String, String> entry) {
    final key = entry.key;
    final label = entry.value;
    final priorScore = diff.priorEvaluation.scorecard[key];
    final currentScore = diff.currentEvaluation.scorecard[key];
    final delta = diff.scorecardDeltas[key];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: AtlasColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          _scoreCell(priorScore),
          SizedBox(
            width: 60,
            child: Center(child: _DeltaChip(delta: delta, compact: true)),
          ),
          _scoreCell(currentScore),
        ],
      ),
    );
  }

  Widget _scoreCell(int? score) => SizedBox(
        width: 60,
        child: Text(
          score == null ? 'N/A' : '$score',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: score == null
                ? AtlasColors.textMuted
                : AtlasColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AtlasColors.textMuted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: const TextStyle(
            color: AtlasColors.textPrimary,
            fontSize: 40,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta, this.compact = false});

  final int? delta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (delta == null) {
      return Text(
        'N/A',
        style: TextStyle(
          color: AtlasColors.textMuted,
          fontSize: compact ? 12 : 16,
        ),
      );
    }
    final isPositive = delta! > 0;
    final isNegative = delta! < 0;
    final color = isPositive
        ? AtlasColors.success
        : isNegative
            ? AtlasColors.danger
            : AtlasColors.textMuted;
    final label = isPositive ? '+$delta' : '$delta';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 12,
        vertical: compact ? 2 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 12 : 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
