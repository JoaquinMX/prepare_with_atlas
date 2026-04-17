import 'package:flutter/material.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';
import 'package:prepare_with_atlas/features/problem_bank/presentation/problem_tile.dart';

/// A labelled section in the Problem Bank screen.
///
/// Shows the section header ([ExperienceLevel.displayLabel]) and subtitle,
/// followed by [ProblemTile] widgets for each problem. When [problems] is
/// empty a placeholder message is rendered instead.
class ProblemSection extends StatelessWidget {
  /// Creates a [ProblemSection].
  const ProblemSection({
    required this.level,
    required this.problems,
    required this.onTap,
    super.key,
  });

  /// The experience level this section represents.
  final ExperienceLevel level;

  /// Problems to display in this section.
  final List<Problem> problems;

  /// Called with the tapped problem.
  final void Function(Problem problem) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          level.displayLabel,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AtlasColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          level.subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AtlasColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (problems.isEmpty)
          Text(
            'No ${level.displayLabel} problems yet. '
            'Generate one with AI or check back later.',
            style: const TextStyle(color: AtlasColors.textMuted),
          )
        else
          Column(
            children: [
              for (final problem in problems)
                Column(
                  children: [
                    ProblemTile(
                      problem: problem,
                      onTap: () => onTap(problem),
                    ),
                    if (problem != problems.last)
                      const Divider(
                        color: AtlasColors.border,
                        height: 1,
                        thickness: 1,
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
