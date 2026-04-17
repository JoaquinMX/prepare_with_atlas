import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_bank_providers.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';
import 'package:prepare_with_atlas/features/problem_bank/presentation/problem_section.dart';

/// The Problem Bank screen — lists all available system-design problems.
///
/// Problems are grouped into three sections by [ExperienceLevel]. Only the
/// problem title is shown in each row; no metadata is ever displayed here.
class ProblemsScreen extends ConsumerWidget {
  /// Creates a [ProblemsScreen].
  const ProblemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger seed on first load.
    ref.watch(curatedSeedProvider);

    final state = ref.watch(problemBankControllerProvider);
    final controller = ref.read(problemBankControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AtlasColors.background,
      body: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Problems',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AtlasColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by title...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: controller.search,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: null, // Spec 05 — not yet implemented
                icon: const Icon(Icons.add),
                label: const Text('Generate with AI'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.errorMessage != null)
            Text(
              state.errorMessage!,
              style: const TextStyle(color: AtlasColors.danger),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final level in ExperienceLevel.values) ...[
                      ProblemSection(
                        level: level,
                        problems:
                            state.sections[level] ?? const <Problem>[],
                        onTap: (problem) => context.go(
                          '/session-setup?problemId=${problem.id}',
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
