import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_dependency_providers.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_state.dart';
import 'package:prepare_with_atlas/features/evaluation/application/prompt_builder.dart';
import 'package:prepare_with_atlas/features/evaluation/application/response_parser.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';

/// Maximum time in seconds to wait for an AI evaluation response.
const int _timeoutSeconds = 120;

/// Number of retries on AI provider failure.
const int _maxRetries = 2;

/// Manages the state of an AI evaluation request for a completed session.
class EvaluationController extends Notifier<EvaluationState> {
  late AiProvider? _provider;
  late EvaluationRepository _repository;
  late PromptBuilder _promptBuilder;
  late ResponseParser _responseParser;

  /// Last args for retry support.
  InterviewSession? _lastSession;
  Problem? _lastProblem;
  List<StageNote>? _lastNotes;
  Uint8List? _lastScreenshot;

  @override
  EvaluationState build() {
    _provider = ref.read(activeAiProviderForEvaluationProvider);
    _repository = ref.read(evaluationRepositoryProvider);
    _promptBuilder = ref.read(promptBuilderProvider);
    _responseParser = ref.read(responseParserProvider);
    return const EvaluationState.idle();
  }

  /// Requests an AI evaluation for the given [session], [problem], and [notes].
  ///
  /// Emits [EvaluationLoading], then either [EvaluationSuccess] or
  /// [EvaluationError]. Retries up to [_maxRetries] times on AI failure
  /// with exponential backoff (2s, 4s).
  Future<void> requestEvaluation({
    required InterviewSession session,
    required Problem problem,
    required List<StageNote> notes,
    Uint8List? whiteboardScreenshot,
  }) async {
    // Persist args for retry
    _lastSession = session;
    _lastProblem = problem;
    _lastNotes = notes;
    _lastScreenshot = whiteboardScreenshot;

    // Read provider fresh so we pick up the value after _loadActive()
    // completes (the cached _provider from build() may have been null if
    // AiProviderController hadn't finished loading yet).
    final provider =
        ref.read(activeAiProviderForEvaluationProvider) ?? _provider;
    if (provider == null) {
      dev.log(
        'requestEvaluation: no AI provider configured',
        name: 'EvaluationController',
        level: 900, // WARNING
      );
      state = const EvaluationState.error('No AI provider configured');
      return;
    }

    final startedAt = DateTime.now();
    dev.log(
      'requestEvaluation: started — '
      'provider=${provider.providerName} model=${provider.currentModel} '
      'sessionId=${session.id} notes=${notes.length} '
      'hasScreenshot=${whiteboardScreenshot != null}',
      name: 'EvaluationController',
    );

    state = const EvaluationState.loading();

    // Build prompt
    final isSingleStage = session.mode == SessionMode.singleStage;
    final focusStage = session.focusStage;

    final systemPrompt = _promptBuilder.buildSystemPrompt();
    final userPrompt = _promptBuilder.buildUserPrompt(
      problem: problem,
      notes: notes,
      whiteboardScreenshot: whiteboardScreenshot,
      referenceAnswer: problem.referenceSolution,
      isSingleStage: isSingleStage,
      focusStage: focusStage,
    );

    dev.log(
      'requestEvaluation: prompt built — '
      'systemLen=${systemPrompt.length} userLen=${userPrompt.length} '
      'isSingleStage=$isSingleStage focusStage=${focusStage?.displayName} '
      'hasScreenshot=${whiteboardScreenshot != null}',
      name: 'EvaluationController',
    );

    final messages = [
      AiMessage(role: 'system', content: systemPrompt),
      // Attach screenshot bytes for multimodal providers (Gemini, Anthropic,
      // OpenAI). When null, providers send text-only as usual.
      AiMessage(
        role: 'user',
        content: userPrompt,
        imageBytes: whiteboardScreenshot?.toList(),
        imageMimeType: whiteboardScreenshot != null ? 'image/png' : null,
      ),
    ];

    state = const EvaluationState.loading(
      statusText: 'Sending to AI for analysis...',
    );

    // Attempt with retries
    Exception? lastError;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      if (attempt > 0) {
        // Exponential backoff: 2s, 4s
        final backoff = 2 * attempt;
        dev.log(
          'requestEvaluation: retry attempt $attempt — '
          'backoff=${backoff}s lastError=$lastError',
          name: 'EvaluationController',
          level: 900, // WARNING
        );
        await Future<void>.delayed(Duration(seconds: backoff));
        state = EvaluationState.loading(
          statusText:
              'Retrying (attempt ${attempt + 1} of ${_maxRetries + 1})...',
        );
      }

      try {
        final aiCallStart = DateTime.now();
        final result = await provider
            .complete(messages)
            .timeout(const Duration(seconds: _timeoutSeconds));

        final aiElapsed = DateTime.now().difference(aiCallStart).inMilliseconds;
        dev.log(
          'requestEvaluation: AI responded — '
          'elapsedMs=$aiElapsed '
          'promptTokens=${result.promptTokens} '
          'completionTokens=${result.completionTokens}',
          name: 'EvaluationController',
        );

        state = const EvaluationState.loading(
          statusText: 'Analysing your response...',
        );

        final evaluation = _responseParser.parse(
          raw: result.content,
          sessionId: session.id.toString(),
          providerUsed: provider.providerName,
          modelUsed: provider.currentModel,
        );

        state = const EvaluationState.loading(statusText: 'Saving results...');

        await _repository.save(evaluation);

        final totalElapsed = DateTime.now()
            .difference(startedAt)
            .inMilliseconds;
        dev.log(
          'requestEvaluation: completed — '
          'totalElapsedMs=$totalElapsed '
          'overallScore=${evaluation.overallScore}',
          name: 'EvaluationController',
        );

        state = EvaluationState.success(evaluation);
        return;
      } on EvaluationParseException catch (e) {
        dev.log(
          'requestEvaluation: parse failed — ${e.message}',
          name: 'EvaluationController',
          level: 1000, // SEVERE
        );
        // Parse failures are not retried
        state = EvaluationState.error(e.message);
        return;
      } on Exception catch (e, stackTrace) {
        dev.log(
          'requestEvaluation: retry attempt $attempt failed — $e',
          name: 'EvaluationController',
          level: 900, // WARNING
          error: e,
          stackTrace: stackTrace,
        );
        lastError = e;
      }
    }

    final totalElapsed = DateTime.now().difference(startedAt).inMilliseconds;
    dev.log(
      'requestEvaluation: all attempts exhausted — '
      'totalElapsedMs=$totalElapsed lastError=$lastError',
      name: 'EvaluationController',
      level: 1000, // SEVERE
    );

    state = EvaluationState.error(
      lastError?.toString() ?? 'Unknown error during evaluation',
    );
  }

  /// Retries the last evaluation request.
  Future<void> retry() async {
    final session = _lastSession;
    final problem = _lastProblem;
    final notes = _lastNotes;
    if (session == null || problem == null || notes == null) return;

    await requestEvaluation(
      session: session,
      problem: problem,
      notes: notes,
      whiteboardScreenshot: _lastScreenshot,
    );
  }
}
