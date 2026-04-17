import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_dependency_providers.dart';
import 'package:prepare_with_atlas/features/evaluation/application/prompt_builder.dart';
import 'package:prepare_with_atlas/features/evaluation/application/response_parser.dart';
import 'package:prepare_with_atlas/features/history/application/re_evaluation_state.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';

/// Hard cap on a single re-evaluation AI call. The flow is non-blocking so
/// this just bounds the worst-case wait when the user eventually returns.
const Duration _reEvalTimeout = Duration(seconds: 180);

/// Tracks in-flight re-evaluation requests on a per-session basis.
///
/// State is a `Map<int sessionId, ReEvaluationStatus>`. Sessions not in the
/// map are implicitly idle. Requests are fire-and-forget from the UI's point
/// of view: tapping "Re-evaluate" transitions the session to
/// [ReEvaluationRunning], and the user is free to navigate away. When the AI
/// call completes the status moves to [ReEvaluationSuccess] or
/// [ReEvaluationError] and the evaluation list providers are invalidated so
/// the Session Detail dropdown picks up the new row (spec 07, US-07.8 +
/// EC-07.2).
class ReEvaluationController extends Notifier<Map<int, ReEvaluationStatus>> {
  @override
  Map<int, ReEvaluationStatus> build() => const {};

  /// Returns the current status for [sessionId], or [ReEvaluationIdle] if
  /// no request has been made.
  ReEvaluationStatus statusFor(int sessionId) =>
      state[sessionId] ?? const ReEvaluationIdle();

  /// Kicks off a re-evaluation of [sessionId] using the explicitly-chosen
  /// [provider]. Does not await AI completion — returns once the AI call
  /// has resolved (success or error). The caller should show a banner while
  /// [statusFor] reports [ReEvaluationRunning].
  ///
  /// On success, the new [EvaluationResult] is persisted as a fresh row
  /// (not an overwrite) and the per-session evaluation providers are
  /// invalidated so the dropdown refreshes.
  Future<void> start({
    required int sessionId,
    required Problem problem,
    required List<StageNote> notes,
    required AiProvider provider,
    Uint8List? whiteboardScreenshot,
  }) async {
    if (state[sessionId] is ReEvaluationRunning) {
      dev.log(
        'start: re-evaluation already running for session=$sessionId; '
        'ignoring duplicate request',
        name: 'ReEvaluationController',
      );
      return;
    }
    _setStatus(
      sessionId,
      ReEvaluationRunning(
        providerName: provider.providerName,
        modelUsed: provider.currentModel,
      ),
    );

    final promptBuilder = ref.read(promptBuilderProvider);
    final parser = ref.read(responseParserProvider);
    final repository = ref.read(evaluationRepositoryProvider);

    final systemPrompt = promptBuilder.buildSystemPrompt();
    final userPrompt = promptBuilder.buildUserPrompt(
      problem: problem,
      notes: notes,
      whiteboardScreenshot: whiteboardScreenshot,
      referenceAnswer: problem.referenceSolution,
    );

    final messages = <AiMessage>[
      AiMessage(role: 'system', content: systemPrompt),
      AiMessage(
        role: 'user',
        content: userPrompt,
        imageBytes: whiteboardScreenshot?.toList(),
        imageMimeType: whiteboardScreenshot != null ? 'image/png' : null,
      ),
    ];

    try {
      final aiResult =
          await provider.complete(messages).timeout(_reEvalTimeout);
      final evaluation = parser.parse(
        raw: aiResult.content,
        sessionId: sessionId.toString(),
        providerUsed: provider.providerName,
        modelUsed: provider.currentModel,
      );
      await repository.save(evaluation);

      _setStatus(sessionId, ReEvaluationSuccess(result: evaluation));

      ref
        ..invalidate(evaluationsForSessionProvider(sessionId.toString()))
        ..invalidate(evaluationForSessionProvider(sessionId.toString()));
    } on EvaluationParseException catch (e) {
      dev.log(
        'start: parse failed — ${e.message}',
        name: 'ReEvaluationController',
        level: 1000,
      );
      _setStatus(
        sessionId,
        ReEvaluationError(
          providerName: provider.providerName,
          message: e.message,
        ),
      );
    } on Exception catch (e, stackTrace) {
      dev.log(
        'start: AI call failed — $e',
        name: 'ReEvaluationController',
        level: 900,
        error: e,
        stackTrace: stackTrace,
      );
      _setStatus(
        sessionId,
        ReEvaluationError(
          providerName: provider.providerName,
          message: e.toString(),
        ),
      );
    }
  }

  /// Clears the status for [sessionId] back to [ReEvaluationIdle]. Used by
  /// the UI to dismiss a success toast or an error banner.
  void dismiss(int sessionId) {
    if (!state.containsKey(sessionId)) return;
    final next = Map<int, ReEvaluationStatus>.from(state)..remove(sessionId);
    state = next;
  }

  void _setStatus(int sessionId, ReEvaluationStatus status) {
    state = {...state, sessionId: status};
  }
}

/// Provides the singleton [ReEvaluationController].
///
/// Intentionally **not** `autoDispose` so an in-flight re-evaluation
/// survives the user leaving Session Detail (US-07.8 "second opinion"
/// should not require the user to sit and wait).
final reEvaluationControllerProvider = NotifierProvider<
    ReEvaluationController, Map<int, ReEvaluationStatus>>(
  ReEvaluationController.new,
);
