import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/history/application/history_providers.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) =>
    '${_monthAbbr[dt.month - 1]} ${dt.day}';

/// Home screen showing recent sessions, stats, and a CTA to start a new
/// interview.
class HomeScreen extends ConsumerWidget {
  /// Creates a [HomeScreen].
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final sessions = state.sessions;

    return Scaffold(
      backgroundColor: AtlasColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(),
              const SizedBox(height: 24),
              _CtaButton(),
              const SizedBox(height: 24),
              _StatsRow(sessions: sessions),
              const SizedBox(height: 24),
              _RecentSessionsSection(sessions: sessions),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prepare with Atlas',
          style: TextStyle(
            color: AtlasColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'System Design Interview Preparation',
          style: TextStyle(
            color: AtlasColors.textSecondary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ── CTA Button ──────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.go('/problems'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AtlasColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Start New Interview',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Stats Row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.sessions});

  final List<SessionSummary> sessions;

  String _avgScore() {
    final scores =
        sessions.map((s) => s.overallScore).whereType<int>().toList();
    if (scores.isEmpty) return 'N/A';
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return avg.toStringAsFixed(0);
  }

  int _distinctProblems() =>
      sessions.map((s) => s.problemTitle).toSet().length;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Sessions',
            value: sessions.length.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Problems',
            value: _distinctProblems().toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Avg Score',
            value: _avgScore(),
          ),
        ),
      ],
    );
  }
}

/// A single statistic tile showing a [label] above a [value].
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AtlasColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AtlasColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AtlasColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent Sessions ─────────────────────────────────────────────────────────

class _RecentSessionsSection extends StatelessWidget {
  const _RecentSessionsSection({required this.sessions});

  final List<SessionSummary> sessions;

  @override
  Widget build(BuildContext context) {
    final recent = sessions.take(3).toList();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Sessions',
            style: TextStyle(
              color: AtlasColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No sessions yet.\nStart your first interview above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AtlasColors.textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AtlasColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AtlasColors.border),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: recent.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AtlasColors.border, height: 1),
                  itemBuilder: (context, index) =>
                      _SessionRow(summary: recent[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single row in the recent sessions list.
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.summary});

  final SessionSummary summary;

  Color _badgeColor(int score) {
    if (score <= 3) return AtlasColors.danger;
    if (score <= 6) return AtlasColors.warning;
    return AtlasColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final score = summary.overallScore;

    return InkWell(
      onTap: () => context.go(
        '/history/detail/${summary.session.id}',
        extra: summary,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                summary.problemTitle,
                style: const TextStyle(
                  color: AtlasColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatDate(summary.session.startedAt),
              style: const TextStyle(
                color: AtlasColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            if (score == null)
              const Text(
                'N/A',
                style: TextStyle(
                  color: AtlasColors.textMuted,
                  fontSize: 13,
                ),
              )
            else
              Container(
                width: 32,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _badgeColor(score).withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$score',
                  style: TextStyle(
                    color: _badgeColor(score),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
