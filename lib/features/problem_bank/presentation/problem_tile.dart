import 'package:flutter/material.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';

// IMPORTANT: This widget intentionally shows ONLY the problem title.
// Adding any metadata field (difficulty, category, description, tags)
// violates the no-spoilers spec.

/// A single row in the Problem Bank list.
///
/// Displays only the problem title — no metadata of any kind is rendered here.
/// Tap to trigger [onTap].
class ProblemTile extends StatelessWidget {
  /// Creates a [ProblemTile].
  const ProblemTile({
    required this.problem,
    required this.onTap,
    super.key,
  });

  /// The problem whose title is displayed.
  final Problem problem;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AtlasColors.surface,
          border: Border.all(color: AtlasColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                problem.title,
                style: const TextStyle(
                  color: AtlasColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AtlasColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
