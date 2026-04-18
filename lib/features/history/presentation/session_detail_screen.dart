import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/ai_provider_factory.dart';
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
    final attemptAsync = ref.watch(attemptCountForProblemProvider(problemId));

    final notes = notesAsync.asData?.value ?? const [];
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
                _EvaluationTab(sessionId: sessionId),
              ],
            ),
          ),
          _ReEvalStatusStrip(sessionId: sessionId),
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

class _EvaluationTab extends ConsumerStatefulWidget {
  const _EvaluationTab({required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<_EvaluationTab> createState() => _EvaluationTabState();
}

class _EvaluationTabState extends ConsumerState<_EvaluationTab> {
  /// Id of the evaluation currently selected in the dropdown.
  ///
  /// When `null` the latest (index 0) is shown. When the user picks from the
  /// dropdown this is set to that evaluation's id. Resets to null after a new
  /// re-evaluation succeeds so the newest entry auto-selects.
  String? _selectedEvalId;

  @override
  void initState() {
    super.initState();
    // Auto-select the newest evaluation when a re-evaluation completes.
    ref.listenManual<Map<int, ReEvaluationStatus>>(
      reEvaluationControllerProvider,
      (prev, next) {
        final prevStatus = prev?[widget.sessionId];
        final nextStatus = next[widget.sessionId];
        if (prevStatus is! ReEvaluationSuccess &&
            nextStatus is ReEvaluationSuccess) {
          if (mounted) setState(() => _selectedEvalId = null);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final evalsAsync = ref.watch(
      evaluationsForSessionProvider(widget.sessionId.toString()),
    );
    final reEvalStatus =
        ref.watch(reEvaluationControllerProvider)[widget.sessionId] ??
            const ReEvaluationIdle();

    return evalsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AtlasColors.accent),
      ),
      error: (err, _) => Center(
        child: Text(
          'Failed to load evaluations: $err',
          style: const TextStyle(color: AtlasColors.textSecondary),
        ),
      ),
      data: (evals) => _buildLoaded(evals, reEvalStatus),
    );
  }

  Widget _buildLoaded(
    List<EvaluationResult> evals,
    ReEvaluationStatus reEvalStatus,
  ) {
    if (evals.isEmpty && reEvalStatus is! ReEvaluationRunning) {
      return Column(
        children: [
          if (reEvalStatus is ReEvaluationError)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _ErrorBanner(
                status: reEvalStatus,
                sessionId: widget.sessionId,
              ),
            ),
          const Expanded(
            child: Center(
              child: Text(
                'No evaluation available for this session.',
                style: TextStyle(color: AtlasColors.textSecondary),
              ),
            ),
          ),
        ],
      );
    }

    final selected = _pickSelected(evals);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reEvalStatus is ReEvaluationRunning)
            _RunningBanner(status: reEvalStatus),
          if (reEvalStatus is ReEvaluationError)
            _ErrorBanner(
              status: reEvalStatus,
              sessionId: widget.sessionId,
            ),
          if (reEvalStatus is ReEvaluationRunning ||
              reEvalStatus is ReEvaluationError)
            const SizedBox(height: 12),
          if (evals.length > 1) ...[
            _EvaluationPicker(
              evaluations: evals,
              selectedId: selected?.id,
              onChanged: (id) => setState(() => _selectedEvalId = id),
            ),
            const SizedBox(height: 16),
          ],
          if (selected != null) ..._buildEvalBody(selected),
        ],
      ),
    );
  }

  EvaluationResult? _pickSelected(List<EvaluationResult> evals) {
    if (evals.isEmpty) return null;
    if (_selectedEvalId == null) return evals.first;
    return evals.firstWhere(
      (e) => e.id == _selectedEvalId,
      orElse: () => evals.first,
    );
  }

  List<Widget> _buildEvalBody(EvaluationResult eval) => [
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
      ];

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

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.summary, required this.attemptCount});

  final SessionSummary summary;
  final int attemptCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = summary.session.id;
    final reEvalStatus =
        ref.watch(reEvaluationControllerProvider)[sessionId] ??
            const ReEvaluationIdle();
    final isRunning = reEvalStatus is ReEvaluationRunning;

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
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('re_evaluate_button'),
              onPressed: isRunning
                  ? null
                  : () => _onReEvaluatePressed(context, ref),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(isRunning ? 'Re-evaluating…' : 'Re-evaluate'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AtlasColors.textPrimary,
                side: const BorderSide(color: AtlasColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
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

  Future<void> _onReEvaluatePressed(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final sessionId = summary.session.id;
    final problemId = summary.session.problemId;

    // Capture everything that depends on `ref` / this element BEFORE any
    // await, so a widget rebuild between awaits cannot crash us with
    // "Using ref when a widget is about to or has been unmounted".
    final problemRepo = ref.read(problemRepositoryProvider);
    final sessionRepo = ref.read(sessionRepositoryProvider);
    final whiteboardRepo = ref.read(whiteboardRepositoryProvider);
    final reEvalController =
        ref.read(reEvaluationControllerProvider.notifier);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final rootOverlay = Overlay.maybeOf(context, rootOverlay: true);

    final config = await showReEvaluateProviderSheet(context);
    if (config == null) return;

    final problem = await problemRepo.getById(problemId);
    if (problem == null) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Problem not found for this session.'),
        ),
      );
      return;
    }

    final notes = await sessionRepo.getStageNotes(sessionId);
    final snapshot = await whiteboardRepo.getLatestForSession(sessionId);

    Uint8List? screenshot;
    if (snapshot != null && rootOverlay != null && rootOverlay.mounted) {
      screenshot = await HeadlessWhiteboardScreenshot.capture(
        overlay: rootOverlay,
        sceneJson: snapshot.sceneJson,
      );
    }

    final aiProvider = buildAiProviderFromConfig(config);

    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Re-evaluating with ${providerNameFromConfig(config)}…',
        ),
      ),
    );

    unawaited(
      reEvalController.start(
        sessionId: sessionId,
        problem: problem,
        notes: notes,
        provider: aiProvider,
        whiteboardScreenshot: screenshot,
      ),
    );
  }

}

// ── Re-evaluation status strip (always visible above the ActionBar) ──────────

class _ReEvalStatusStrip extends ConsumerWidget {
  const _ReEvalStatusStrip({required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(reEvaluationControllerProvider)[sessionId] ??
        const ReEvaluationIdle();

    if (status is ReEvaluationIdle || status is ReEvaluationSuccess) {
      return const SizedBox.shrink();
    }
    if (status is ReEvaluationRunning) {
      return Container(
        key: const Key('re_eval_status_strip_running'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AtlasColors.accent.withValues(alpha: 0.08),
          border: const Border(
            top: BorderSide(color: AtlasColors.border),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AtlasColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Re-evaluating with ${status.providerName} · '
                '${status.modelUsed}…',
                style: const TextStyle(
                  color: AtlasColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final err = status as ReEvaluationError;
    return Container(
      key: const Key('re_eval_status_strip_error'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AtlasColors.danger.withValues(alpha: 0.08),
        border: const Border(top: BorderSide(color: AtlasColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AtlasColors.danger, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Re-evaluation with ${err.providerName} failed: ${err.message}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AtlasColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 16,
            color: AtlasColors.textMuted,
            icon: const Icon(Icons.close),
            onPressed: () => ref
                .read(reEvaluationControllerProvider.notifier)
                .dismiss(sessionId),
          ),
        ],
      ),
    );
  }
}

// ── Re-evaluation banners & picker ───────────────────────────────────────────

class _RunningBanner extends StatelessWidget {
  const _RunningBanner({required this.status});

  final ReEvaluationRunning status;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('re_eval_running_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AtlasColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AtlasColors.accent),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AtlasColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Re-evaluating with ${status.providerName} · '
              '${status.modelUsed}…',
              style: const TextStyle(
                color: AtlasColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.status, required this.sessionId});

  final ReEvaluationError status;
  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const Key('re_eval_error_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AtlasColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AtlasColors.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: AtlasColors.danger,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Re-evaluation with ${status.providerName} failed',
                  style: const TextStyle(
                    color: AtlasColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.message,
                  style: const TextStyle(
                    color: AtlasColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              color: AtlasColors.textMuted,
              size: 18,
            ),
            onPressed: () => ref
                .read(reEvaluationControllerProvider.notifier)
                .dismiss(sessionId),
          ),
        ],
      ),
    );
  }
}

class _EvaluationPicker extends StatelessWidget {
  const _EvaluationPicker({
    required this.evaluations,
    required this.selectedId,
    required this.onChanged,
  });

  final List<EvaluationResult> evaluations;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, y · HH:mm');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AtlasColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('re_eval_picker'),
          isExpanded: true,
          value: selectedId ?? evaluations.first.id,
          dropdownColor: AtlasColors.surface,
          iconEnabledColor: AtlasColors.textSecondary,
          style: const TextStyle(
            color: AtlasColors.textPrimary,
            fontSize: 13,
          ),
          items: [
            for (final e in evaluations)
              DropdownMenuItem<String>(
                value: e.id,
                child: Text(
                  '${e.providerUsed} · ${e.modelUsed} · '
                  '${fmt.format(e.createdAt)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
