import 'package:flutter/material.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';

/// A row of stage chips showing progress through the five interview stages.
///
/// Current stage: accent background with white text.
/// Completed stages: muted text, no border.
/// Upcoming stages: border only, no fill.
class StageProgressBar extends StatelessWidget {
  /// Creates a [StageProgressBar].
  const StageProgressBar({
    required this.currentStage,
    required this.completedStages,
    super.key,
  });

  /// The stage currently in progress.
  final InterviewStage? currentStage;

  /// Stages that have already been completed.
  final Set<InterviewStage> completedStages;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: InterviewStage.values.map((stage) {
        return _StageChip(
          stage: stage,
          isCurrent: stage == currentStage,
          isCompleted: completedStages.contains(stage),
        );
      }).toList(),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.stage,
    required this.isCurrent,
    required this.isCompleted,
  });

  final InterviewStage stage;
  final bool isCurrent;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color textColor;
    final Border? border;

    if (isCurrent) {
      bg = AtlasColors.accent;
      textColor = Colors.white;
      border = null;
    } else if (isCompleted) {
      bg = Colors.transparent;
      textColor = AtlasColors.textMuted;
      border = null;
    } else {
      bg = Colors.transparent;
      textColor = AtlasColors.textSecondary;
      border = Border.all(color: AtlasColors.border);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: border,
      ),
      child: Text(
        stage.displayName,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
