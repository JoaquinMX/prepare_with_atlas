import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/history/application/history_providers.dart';
import 'package:prepare_with_atlas/features/history/application/history_view_mode.dart';
import 'package:prepare_with_atlas/features/history/domain/problem_attempts.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';

/// Screen displaying the list of past interview sessions.
///
/// Supports two view modes — flat (date-sorted) and grouped by problem — and
/// allows the user to delete sessions with a swipe or context menu.
class SessionHistoryScreen extends ConsumerWidget {
  /// Creates a [SessionHistoryScreen].
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);

    return Scaffold(
      backgroundColor: AtlasColors.background,
      appBar: AppBar(
        backgroundColor: AtlasColors.surface,
        title: const Text(
          'History',
          style: TextStyle(color: AtlasColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(
              state.viewMode == HistoryViewMode.flat
                  ? Icons.grid_view
                  : Icons.list,
              color: AtlasColors.textPrimary,
            ),
            tooltip: state.viewMode == HistoryViewMode.flat
                ? 'Group by problem'
                : 'Flat list',
            onPressed: () =>
                ref.read(historyControllerProvider.notifier).toggleView(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.viewMode == HistoryViewMode.flat
              ? _FlatView(sessions: state.sessions)
              : _GroupedView(groups: state.problemGroups),
    );
  }
}

// ── Flat View ────────────────────────────────────────────────────────────────

class _FlatView extends ConsumerWidget {
  const _FlatView({required this.sessions});

  final List<SessionSummary> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessions.isEmpty) {
      return const Center(
        child: Text(
          'No sessions yet. Start your first interview!',
          style: TextStyle(
            color: AtlasColors.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final summary = sessions[index];
        return _SessionTile(summary: summary);
      },
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = summary.overallScore;
    final scoreColor = score == null
        ? AtlasColors.textMuted
        : score <= 3
            ? AtlasColors.danger
            : score <= 6
                ? AtlasColors.warning
                : AtlasColors.success;

    return Dismissible(
      key: Key('session-${summary.session.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AtlasColors.danger,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref
            .read(historyControllerProvider.notifier)
            .deleteSession(summary.session.id);
      },
      child: GestureDetector(
        onTap: () => context.push(
          '/history/detail/${summary.session.id}',
          extra: summary,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AtlasColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AtlasColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.problemTitle,
                      style: const TextStyle(
                        color: AtlasColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(summary.session.startedAt),
                      style: const TextStyle(
                        color: AtlasColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (score != null)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scoreColor.withAlpha(30),
                    border: Border.all(color: scoreColor),
                  ),
                  child: Center(
                    child: Text(
                      '$score',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

// ── Grouped View ─────────────────────────────────────────────────────────────

class _GroupedView extends StatelessWidget {
  const _GroupedView({required this.groups});

  final List<ProblemAttempts> groups;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(
        child: Text(
          'No sessions yet. Start your first interview!',
          style: TextStyle(
            color: AtlasColors.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        return _ProblemGroup(group: groups[index]);
      },
    );
  }
}

class _ProblemGroup extends StatelessWidget {
  const _ProblemGroup({required this.group});

  final ProblemAttempts group;

  @override
  Widget build(BuildContext context) {
    final trend = group.trend;
    final trendIcon = trend == 1
        ? Icons.trending_up
        : trend == -1
            ? Icons.trending_down
            : Icons.trending_flat;
    final trendColor = trend == 1
        ? AtlasColors.success
        : trend == -1
            ? AtlasColors.danger
            : AtlasColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AtlasColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          group.problemTitle,
          style: const TextStyle(
            color: AtlasColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${group.attempts.length} '
          'attempt${group.attempts.length == 1 ? '' : 's'}',
          style: const TextStyle(
            color: AtlasColors.textMuted,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(trendIcon, color: trendColor, size: 20),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, color: AtlasColors.textSecondary),
          ],
        ),
        children: group.attempts
            .map(
              (a) => _SessionTile(summary: a),
            )
            .toList(),
      ),
    );
  }
}
