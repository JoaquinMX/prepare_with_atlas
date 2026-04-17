import 'package:flutter/material.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';

/// Maps a scorecard dimension key to a human-readable label.
const Map<String, String> _dimensionLabels = {
  'requirementsGathering': 'Requirements Gathering',
  'estimationQuality': 'Estimation Quality',
  'highLevelDesign': 'High-Level Design',
  'deepDiveQuality': 'Deep Dive Quality',
  'scalingAwareness': 'Scaling Awareness',
  'communicationClarity': 'Communication Clarity',
  'overall': 'Overall',
};

/// Returns the color appropriate for a given score (0–10).
Color _scoreColor(int score) {
  if (score <= 3) return AtlasColors.danger;
  if (score <= 6) return AtlasColors.warning;
  return AtlasColors.success;
}

/// Displays the evaluation scorecard as 7 dimension rows with color-coded bars.
class ScoreCardWidget extends StatelessWidget {
  /// Creates a [ScoreCardWidget] for the given [result].
  const ScoreCardWidget({required this.result, super.key});

  /// The evaluation result to display.
  final EvaluationResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverallScore(),
        const SizedBox(height: 24),
        ..._dimensionLabels.entries.map(_buildDimensionRow),
      ],
    );
  }

  Widget _buildOverallScore() {
    final score = result.overallScore;
    final color = _scoreColor(score);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Score',
                  style: TextStyle(
                    color: AtlasColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$score / 10',
                  style: TextStyle(
                    color: color,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(30),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionRow(MapEntry<String, String> entry) {
    final key = entry.key;
    final label = entry.value;
    final rawScore = result.scorecard[key];
    final isMissing = rawScore == null;
    final score = rawScore ?? 0;
    final color = _scoreColor(score);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                color: AtlasColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isMissing
                ? const Text(
                    'N/A',
                    style: TextStyle(
                      color: AtlasColors.textMuted,
                      fontSize: 13,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          color: AtlasColors.border,
                        ),
                        FractionallySizedBox(
                          widthFactor: score / 10,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 32,
            child: Text(
              isMissing ? 'N/A' : '$score',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isMissing ? AtlasColors.textMuted : color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
