import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/application/dictation_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/recording/application/audio_recorder_state.dart';
import 'package:prepare_with_atlas/features/interview_session/application/timer_state.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/presentation/stage_notes_panel.dart';
import 'package:prepare_with_atlas/features/interview_session/presentation/stage_progress_bar.dart';
import 'package:prepare_with_atlas/features/interview_session/presentation/timer_display.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_repository_provider.dart';
import 'package:prepare_with_atlas/features/whiteboard/application/whiteboard_controller.dart';
import 'package:prepare_with_atlas/features/whiteboard/data/whiteboard_providers.dart';
import 'package:prepare_with_atlas/features/whiteboard/presentation/whiteboard_panel.dart';

/// Provides the title of a problem by id for the interview screen top bar.
final _problemTitleProvider = FutureProvider.family<String, int>((
  ref,
  id,
) async {
  if (id == 0) return 'Interview';
  final problem = await ref.read(problemRepositoryProvider).getById(id);
  return problem?.title ?? 'Problem #$id';
});

/// Full-screen interview workspace — no sidebar, no reference material.
///
/// Layout (top bar then body row):
///
/// - Top bar: problem title, timer, stage bar, pause, End Session, Abandon
/// - Body: StageNotesPanel (40%) | draggable divider | Whiteboard (60%)
class InterviewScreen extends ConsumerStatefulWidget {
  /// Creates an [InterviewScreen].
  const InterviewScreen({super.key});

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen> {
  double _leftFraction = 0.4;
  bool _dividerHovered = false;

  @override
  void initState() {
    super.initState();
    // Ensure the timer is running as soon as the screen is visible.
    // This guards against edge cases where startFullSession() completed but
    // the timer state was reset before the screen mounted (e.g. provider
    // rebuild, DB latency).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sessionState = ref.read(sessionControllerProvider);
      final timerState = ref.read(stageTimerControllerProvider);
      final session = sessionState.currentSession;
      final stage = sessionState.currentStage;
      if (session != null && stage != null && timerState is TimerIdle) {
        ref
            .read(stageTimerControllerProvider.notifier)
            .startStage(stage, session.timerConfig, session.timerBehavior);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Register reactive listeners.
    //  1. Pending evaluation → capture screenshot, navigate to eval screen.
    //  2. Timer stage ended → auto-advance (hard-stop / grace expiry).
    ref
      ..listen<bool>(
        sessionControllerProvider.select((s) => s.pendingEvaluation),
        (_, pending) {
          if (pending && mounted) {
            ref
                .read(sessionControllerProvider.notifier)
                .clearPendingEvaluation();
            unawaited(_startEvaluationAndNavigate());
          }
        },
      )
      ..listen<TimerState>(stageTimerControllerProvider, (_, next) {
        if (next is TimerStageEnded && mounted) {
          unawaited(_autoAdvanceStage());
        }
      });

    final sessionState = ref.watch(sessionControllerProvider);
    final session = sessionState.currentSession;
    final currentStage = sessionState.currentStage;
    final timerState = ref.watch(stageTimerControllerProvider);

    final problemId = session?.problemId ?? 0;
    final problemTitle =
        ref.watch(_problemTitleProvider(problemId)).whenData((t) => t).value ??
        'Interview';

    final isPaused = timerState is TimerPaused;

    final completedStages = <InterviewStage>{};
    if (currentStage != null) {
      final idx = InterviewStage.values.indexOf(currentStage);
      for (var i = 0; i < idx; i++) {
        completedStages.add(InterviewStage.values[i]);
      }
    }

    return Scaffold(
      backgroundColor: AtlasColors.background,
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────
          _TopBar(
            problemTitle: problemTitle,
            currentStage: currentStage,
            completedStages: completedStages,
            isPaused: isPaused,
            onPauseResume: () {
              final notifier = ref.read(stageTimerControllerProvider.notifier);
              if (isPaused) {
                notifier.resume();
              } else {
                notifier.pause();
              }
            },
            onEndSession: _confirmEnd,
            onAbandon: _confirmAbandon,
          ),
          // ── Body ─────────────────────────────────────────────────────
          Expanded(
            child: Row(
              // Stretch forces children to fill the full height, which is
              // required for the draggable divider to be hit-testable.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Notes panel (left)
                SizedBox(
                  width: MediaQuery.of(context).size.width * _leftFraction,
                  child: const ColoredBox(
                    color: AtlasColors.surface,
                    child: StageNotesPanel(),
                  ),
                ),
                // Draggable divider
                MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  onEnter: (_) => setState(() => _dividerHovered = true),
                  onExit: (_) => setState(() => _dividerHovered = false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      final total = MediaQuery.of(context).size.width;
                      if (total == 0) return;
                      setState(() {
                        _leftFraction =
                            (_leftFraction + details.delta.dx / total).clamp(
                              0.2,
                              0.8,
                            );
                      });
                    },
                    child: ColoredBox(
                      color: _dividerHovered
                          ? AtlasColors.accent
                          : AtlasColors.border,
                      child: const SizedBox(width: 4),
                    ),
                  ),
                ),
                // Whiteboard panel (right)
                const Expanded(child: WhiteboardPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Called when [stageTimerControllerProvider] transitions to
  /// [TimerStageEnded] due to a hard-stop or an expired auto-advance grace
  /// period.
  ///
  /// Cancels active dictation so any in-flight recognised text is flushed
  /// and saved, then delegates to
  /// `SessionController.advanceToNextStage` which either loads the next
  /// stage or ends the session.
  Future<void> _autoAdvanceStage() async {
    await ref.read(dictationControllerProvider.notifier).cancelListening();
    await ref.read(sessionControllerProvider.notifier).advanceToNextStage();
  }

  /// Captures the whiteboard screenshot (while the WebView is still alive),
  /// loads the problem, and starts the evaluation before navigating to the
  /// loading screen.
  Future<void> _startEvaluationAndNavigate() async {
    final sessionState = ref.read(sessionControllerProvider);
    final session = sessionState.currentSession;
    if (session == null) return;

    final notes = sessionState.stageNotes.values.toList();

    // Capture all provider references synchronously before any await — using
    // ref after an await is unsafe if the widget unmounts during the await.
    final whiteboardNotifier = ref.read(whiteboardControllerProvider.notifier);
    final whiteboardRepo = ref.read(whiteboardRepositoryProvider);
    final problemRepo = ref.read(problemRepositoryProvider);
    final evalNotifier = ref.read(evaluationControllerProvider.notifier);

    // Grab the current scene JSON while the WebView is still alive.
    // Wrap in try/catch — WKWebView may throw FWFEvaluateJavaScriptError if
    // the JS context is not ready or the page is being torn down.
    String? sceneJson;
    try {
      sceneJson = await whiteboardNotifier.getSceneData();
    } on Object catch (e) {
      dev.log(
        'getSceneData failed during end-of-session: $e',
        name: 'InterviewScreen',
      );
    }

    // Screenshot must be captured while the WebView is still mounted.
    Uint8List? screenshot;
    try {
      screenshot = await whiteboardNotifier.captureScreenshot();
    } on Object catch (e) {
      dev.log(
        'captureScreenshot failed during end-of-session: $e',
        name: 'InterviewScreen',
      );
    }

    // Persist the final whiteboard state so the History screen can show it.
    // This supplements the 30-second auto-save and covers sessions shorter
    // than one auto-save tick.
    if (sceneJson != null) {
      await whiteboardRepo.saveSnapshot(
        sessionId: session.id,
        sceneJson: sceneJson,
        screenshotPng: screenshot,
      );
    }

    // Load the problem for the evaluation prompt.
    final problem = await problemRepo.getById(session.problemId);

    if (!mounted) return;

    // Fire evaluation (async — the loading screen watches its state).
    if (problem != null) {
      unawaited(
        evalNotifier.requestEvaluation(
          session: session,
          problem: problem,
          notes: notes,
          whiteboardScreenshot: screenshot,
          voiceRecordingEnabled:
              sessionState.recordingMode == RecordingMode.voiceRecording,
        ),
      );
    }

    context.go('/evaluation/loading');
  }

  Future<void> _confirmEnd() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AtlasColors.surfaceElevated,
        title: const Text(
          'End Session?',
          style: TextStyle(color: AtlasColors.textPrimary),
        ),
        content: const Text(
          'This will mark your session as completed.',
          style: TextStyle(color: AtlasColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      // Stop dictation before ending the session to ensure in-flight
      // recognised text is saved with the current stage notes.
      await ref.read(dictationControllerProvider.notifier).cancelListening();
      await ref.read(sessionControllerProvider.notifier).endSession();
      // Navigation to /evaluation/loading is handled by the ref.listen
      // on pendingEvaluation — do not navigate here.
    }
  }

  Future<void> _confirmAbandon() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AtlasColors.surfaceElevated,
        title: const Text(
          'Abandon Session?',
          style: TextStyle(color: AtlasColors.textPrimary),
        ),
        content: const Text(
          'Progress will not be saved.',
          style: TextStyle(color: AtlasColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AtlasColors.danger,
              side: const BorderSide(color: AtlasColors.danger),
            ),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      await ref.read(dictationControllerProvider.notifier).cancelListening();
      await ref.read(sessionControllerProvider.notifier).abandonSession();
      if (mounted) context.go('/');
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.problemTitle,
    required this.currentStage,
    required this.completedStages,
    required this.isPaused,
    required this.onPauseResume,
    required this.onEndSession,
    required this.onAbandon,
  });

  final String problemTitle;
  final InterviewStage? currentStage;
  final Set<InterviewStage> completedStages;
  final bool isPaused;
  final VoidCallback onPauseResume;
  final VoidCallback onEndSession;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AtlasColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Problem title
          Text(
            problemTitle,
            style: const TextStyle(
              color: AtlasColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          // Timer
          const TimerDisplay(),
          const SizedBox(width: 16),
          // Stage progress
          if (currentStage != null)
            Flexible(
              child: StageProgressBar(
                currentStage: currentStage,
                completedStages: completedStages,
              ),
            ),
          const Spacer(),
          // Pause/Resume
          IconButton(
            onPressed: onPauseResume,
            icon: Icon(
              isPaused ? Icons.play_arrow : Icons.pause,
              color: AtlasColors.textSecondary,
            ),
            tooltip: isPaused ? 'Resume' : 'Pause',
          ),
          const SizedBox(width: 8),
          // End Session (primary)
          ElevatedButton(
            onPressed: onEndSession,
            child: const Text('End Session'),
          ),
          const SizedBox(width: 8),
          // Abandon (secondary)
          OutlinedButton(
            onPressed: onAbandon,
            style: OutlinedButton.styleFrom(
              foregroundColor: AtlasColors.danger,
              side: const BorderSide(color: AtlasColors.danger),
            ),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
  }
}
