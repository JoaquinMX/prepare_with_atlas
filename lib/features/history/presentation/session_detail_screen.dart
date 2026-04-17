import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/ai_provider_factory.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_dependency_providers.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/evaluation/presentation/score_card_widget.dart';
import 'package:prepare_with_atlas/features/history/application/history_providers.dart';
import 'package:prepare_with_atlas/features/history/application/re_evaluation_controller.dart';
import 'package:prepare_with_atlas/features/history/application/re_evaluation_state.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';
import 'package:prepare_with_atlas/features/history/presentation/re_evaluate_provider_sheet.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_repository_provider.dart';
import 'package:prepare_with_atlas/features/whiteboard/application/headless_whiteboard_screenshot.dart';
import 'package:prepare_with_atlas/features/whiteboard/application/whiteboard_controller.dart';
import 'package:prepare_with_atlas/features/whiteboard/data/whiteboard_providers.dart';
import 'package:prepare_with_atlas/features/whiteboard/presentation/whiteboard_panel.dart';

/// Displays the details of a completed interview session.
///
/// Shows three tabs — Notes, Whiteboard, and Evaluation — plus action buttons
/// for retrying the problem or comparing to a previous attempt.
///
/// All data (stage notes, evaluation, attempt count) is loaded from the
/// database using Riverpod providers keyed on the session id.
class SessionDetailScreen extends ConsumerStatefulWidget {
  /// Creates a [SessionDetailScreen].
  const SessionDetailScreen({required this.summary, super.key});

  /// Summary containing session metadata and problem title.
  final SessionSummary summary;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = widget.summary.session.id;
    final problemId = widget.summary.session.problemId;

    final notesAsync = ref.watch(stageNotesForSessionProvider(sessionId));
    final evalAsync = ref.watch(
      evaluationForSessionProvider(sessionId.toString()),
    );
    final attemptAsync = ref.watch(attemptCountForProblemProvider(problemId));

    final notes = notesAsync.asData?.value ?? const [];
    final evaluation = evalAsync.asData?.value;
    final attemptCount = attemptAsync.asData?.value ?? 1;

    return Scaffold(
      backgroundColor: AtlasColors.background,
      appBar: AppBar(
        backgroundColor: AtlasColors.surface,
        title: Text(
          widget.summary.problemTitle,
          style: const TextStyle(color: AtlasColors.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AtlasColors.accent,
          unselectedLabelColor: AtlasColors.textSecondary,
          indicatorColor: AtlasColors.accent,
          tabs: const [
            Tab(text: 'Notes'),
            Tab(text: 'Whiteboard'),
            Tab(text: 'Evaluation'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _NotesTab(notes: notes),
                _WhiteboardTab(sessionId: sessionId),
                _EvaluationTab(
                  evaluation: evaluation,
                  isLoading: evalAsync.isLoading,
                ),
              ],
            ),
          ),
          _ActionBar(summary: widget.summary, attemptCount: attemptCount),
        ],
      ),
    );
  }
}

// ── Notes Tab ────────────────────────────────────────────────────────────────

class _NotesTab extends StatelessWidget {
  const _NotesTab({required this.notes});

  final List<StageNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Center(
        child: Text(
          'No notes recorded.',
          style: TextStyle(color: AtlasColors.textSecondary),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: notes.map(_buildNoteSection).toList(),
    );
  }

  Widget _buildNoteSection(StageNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AtlasColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stageLabel(note.stage),
            style: const TextStyle(
              color: AtlasColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note.notes.isEmpty ? '(no notes)' : note.notes,
            style: const TextStyle(
              color: AtlasColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _stageLabel(InterviewStage stage) => stage.displayName;
}

// ── Whiteboard Tab ───────────────────────────────────────────────────────────

/// Displays a view-only snapshot of the whiteboard for a completed session.
///
/// Fetches the latest whiteboard snapshot for [sessionId] from the repository
/// and renders [WhiteboardPanel] in read-only mode when a snapshot is found.
///
/// Uses [AutomaticKeepAliveClientMixin] so that switching to an adjacent tab
/// in the [TabBarView] does not dispose the widget (and its WebView). Without
/// it, the [whiteboardSnapshotProvider] (which is `autoDispose`) would
/// invalidate on unmount, destroying the [WhiteboardPanel] and losing the
/// loaded Excalidraw scene.
class _WhiteboardTab extends ConsumerStatefulWidget {
  const _WhiteboardTab({required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<_WhiteboardTab> createState() => _WhiteboardTabState();
}

class _WhiteboardTabState extends ConsumerState<_WhiteboardTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final snapshotAsync = ref.watch(
      whiteboardSnapshotProvider(widget.sessionId),
    );

    return snapshotAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AtlasColors.accent),
      ),
      error: (_, __) => const Center(
        child: Text(
          'Failed to load whiteboard snapshot.',
          style: TextStyle(color: AtlasColors.textSecondary),
        ),
      ),
      data: (snapshot) {
        if (snapshot == null) {
          return const Center(
            child: Text(
              'No whiteboard snapshot for this session.',
              style: TextStyle(color: AtlasColors.textSecondary),
            ),
          );
        }

        return WhiteboardPanel(
          key: const Key('whiteboard_panel'),
          viewOnly: true,
          onReady: () async {
            await ref
                .read(whiteboardControllerProvider.notifier)
                .loadSceneData(snapshot.sceneJson);
            await ref
                .read(whiteboardControllerProvider.notifier)
                .setViewMode(viewOnly: true);
          },
        );
      },
    );
  }
}

// ── Evaluation Tab ───────────────────────────────────────────────────────────

class _EvaluationTab extends StatelessWidget {
  const _EvaluationTab({required this.evaluation, required this.isLoading});

  final EvaluationResult? evaluation;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AtlasColors.accent),
      );
    }
    final eval = evaluation;
    if (eval == null) {
      return const Center(
        child: Text(
          'No evaluation available for this session.',
          style: TextStyle(color: AtlasColors.textSecondary),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreCardWidget(result: eval),
          const SizedBox(height: 24),
          _buildStrengths(eval),
          const SizedBox(height: 16),
          _buildImprovements(eval),
          const SizedBox(height: 16),
          _buildNarrative(eval),
          if (eval.referenceComparison != null) ...[
            const SizedBox(height: 16),
            _buildReferenceComparison(eval.referenceComparison!),
          ],
          const SizedBox(height: 16),
          Text(
            'Powered by ${eval.providerUsed} · ${eval.modelUsed}',
            style: const TextStyle(color: AtlasColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengths(EvaluationResult eval) => _EvalSection(
    title: 'Strengths',
    icon: Icons.thumb_up_outlined,
    iconColor: AtlasColors.success,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: eval.strengths
          .map((s) => _BulletItem(text: s, color: AtlasColors.success))
          .toList(),
    ),
  );

  Widget _buildImprovements(EvaluationResult eval) => _EvalSection(
    title: 'Areas for Improvement',
    icon: Icons.trending_up,
    iconColor: AtlasColors.warning,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: eval.improvements
          .map((s) => _BulletItem(text: s, color: AtlasColors.warning))
          .toList(),
    ),
  );

  Widget _buildNarrative(EvaluationResult eval) => _EvalSection(
    title: 'Detailed Feedback',
    icon: Icons.article_outlined,
    iconColor: AtlasColors.accent,
    child: MarkdownBody(
      data: eval.narrative,
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(
          color: AtlasColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        h2: const TextStyle(
          color: AtlasColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        p: const TextStyle(
          color: AtlasColors.textSecondary,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    ),
  );

  Widget _buildReferenceComparison(String comparison) => _EvalSection(
    title: 'Reference Comparison',
    icon: Icons.compare_arrows,
    iconColor: AtlasColors.accent,
    child: Text(
      comparison,
      style: const TextStyle(
        color: AtlasColors.textSecondary,
        fontSize: 14,
        height: 1.6,
      ),
    ),
  );
}

class _EvalSection extends StatelessWidget {
  const _EvalSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AtlasColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AtlasColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
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

// ── Action Bar ───────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.summary, required this.attemptCount});

  final SessionSummary summary;
  final int attemptCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AtlasColors.surface,
        border: Border(top: BorderSide(color: AtlasColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.go(
                '/session-setup?problemId=${summary.session.problemId}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AtlasColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Retry This Problem'),
            ),
          ),
          if (attemptCount >= 2) ...[
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.push(
                  '/history/compare',
                  extra: {
                    'priorSessionId': summary.session.id.toString(),
                    'currentSessionId': summary.session.id.toString(),
                  },
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AtlasColors.textPrimary,
                  side: const BorderSide(color: AtlasColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Compare to Previous'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
