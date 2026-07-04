import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/ai_provider_factory.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_message.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';
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
  late EvaluationRepository _repository;
  late PromptBuilder _promptBuilder;
  late ResponseParser _responseParser;
  late AiProvider Function(AiProviderConfig) _buildProvider;
  late AiProvider Function(AiProviderConfig, String) _buildProviderWithModel;

  /// Last args for retry support.
  InterviewSession? _lastSession;
  Problem? _lastProblem;
  List<StageNote>? _lastNotes;
  Uint8List? _lastScreenshot;

  @override
  EvaluationState build() {
    _repository = ref.read(evaluationRepositoryProvider);
    _promptBuilder = ref.read(promptBuilderProvider);
    _responseParser = ref.read(responseParserProvider);
    _buildProvider = ref.read(aiProviderBuilderProvider);
    _buildProviderWithModel = ref.read(aiProviderBuilderWithModelProvider);
    return const EvaluationState.idle();
  }

  AiProvider? _resolveVisionProvider(
    AiProviderConfig? activeConfig,
    String? visionModelOverride,
  ) {
    if (activeConfig == null) return null;
    if (visionModelOverride != null && visionModelOverride.isNotEmpty) {
      return _buildProviderWithModel(activeConfig, visionModelOverride);
    }
    return _buildProvider(activeConfig);
  }

  AiProvider? _resolveAudioProvider(
    AiProviderConfig? activeConfig,
    String? audioModelOverride,
  ) {
    if (activeConfig == null) return null;
    if (audioModelOverride != null && audioModelOverride.isNotEmpty) {
      return _buildProviderWithModel(activeConfig, audioModelOverride);
    }
    return _buildProvider(activeConfig);
  }

  AiProvider? _resolveTextProvider(
    AiProviderConfig? activeConfig,
    String? textModelOverride,
  ) {
    if (activeConfig == null) return null;
    if (textModelOverride != null && textModelOverride.isNotEmpty) {
      return _buildProviderWithModel(activeConfig, textModelOverride);
    }
    return _buildProvider(activeConfig);
  }

  /// Requests an AI evaluation for the given [session], [problem], and [notes].
  ///
  /// Emits [EvaluationLoading], then either [EvaluationSuccess] or
  /// [EvaluationError]. Retries up to [_maxRetries] times on AI failure
  /// with exponential backoff (2s, 4s).
  ///
  /// When [voiceRecordingEnabled] is true and [notes] contain audioFilePath
  /// values, audio transcription is performed before evaluation using the
  /// selected Audio model.
  Future<void> requestEvaluation({
    required InterviewSession session,
    required Problem problem,
    required List<StageNote> notes,
    Uint8List? whiteboardScreenshot,
    bool voiceRecordingEnabled = false,
    String? visionModelOverride,
    String? audioModelOverride,
    String? textModelOverride,
  }) async {
    _lastSession = session;
    _lastProblem = problem;
    _lastNotes = notes;
    _lastScreenshot = whiteboardScreenshot;

    final activeConfig =
        ref.read(aiProviderControllerProvider).activeConfig;
    final textProvider = _resolveTextProvider(activeConfig, textModelOverride);
    if (textProvider == null) {
      state = const EvaluationState.error('No AI provider configured');
      return;
    }

    final startedAt = DateTime.now();
    dev.log(
      'requestEvaluation: started — '
      'provider=${textProvider.providerName} model=${textProvider.currentModel} '
      'sessionId=${session.id} notes=${notes.length} '
      'hasScreenshot=${whiteboardScreenshot != null} '
      'voiceRecording=$voiceRecordingEnabled',
      name: 'EvaluationController',
    );

    state = const EvaluationState.loading();

    final isSingleStage = session.mode == SessionMode.singleStage;
    final focusStage = session.focusStage;

    // Build prompt
    final systemPrompt = _promptBuilder.buildSystemPrompt();
    var userPrompt = _promptBuilder.buildUserPrompt(
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
      'isSingleStage=$isSingleStage focusStage=${focusStage?.displayName}',
      name: 'EvaluationController',
    );

    // If voice recording is enabled, transcribe audio per stage
    if (voiceRecordingEnabled) {
      state = const EvaluationState.loading(
        statusText: 'Transcribing audio...',
      );

      final transcriptionNotes = await _transcribeNotesWithAudio(
        notes,
        activeConfig,
        audioModelOverride,
      );

      // Rebuild prompt with transcribed text
      userPrompt = _promptBuilder.buildUserPrompt(
        problem: problem,
        notes: transcriptionNotes,
        whiteboardScreenshot: whiteboardScreenshot,
        referenceAnswer: problem.referenceSolution,
        isSingleStage: isSingleStage,
        focusStage: focusStage,
      );
    }

    // Route to appropriate providers

    // Vision evaluation: whiteboard screenshot with Vision model
    if (whiteboardScreenshot != null && whiteboardScreenshot.isNotEmpty) {
      final visionProvider = _resolveVisionProvider(
        activeConfig,
        visionModelOverride,
      );
      if (visionProvider != null && visionProvider.supportsVision) {
        state = const EvaluationState.loading(
          statusText: 'Analysing whiteboard...',
        );

        final visionMessages = [
          AiMessage(role: 'system', content: _whiteboardSystemPrompt()),
          AiMessage(
            role: 'user',
            content: 'Please describe and evaluate this whiteboard diagram.',
            imageBytes: whiteboardScreenshot.toList(),
            imageMimeType: 'image/png',
          ),
        ];

        try {
          await visionProvider
              .complete(visionMessages)
              .timeout(const Duration(seconds: _timeoutSeconds));
        } catch (_) {
          // Continue even if vision evaluation fails
        }
      }
    }

    // Text evaluation: notes text with Text model (default provider)
    state = const EvaluationState.loading(
      statusText: 'Sending to AI for analysis...',
    );

    final messagesWithImage = [
      AiMessage(role: 'system', content: systemPrompt),
      AiMessage(
        role: 'user',
        content: userPrompt,
        imageBytes: whiteboardScreenshot?.toList(),
        imageMimeType: whiteboardScreenshot != null ? 'image/png' : null,
      ),
    ];

    // Attempt with retries
    Exception? lastError;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      if (attempt > 0) {
        final backoff = 2 * attempt;
        await Future<void>.delayed(Duration(seconds: backoff));
        state = EvaluationState.loading(
          statusText:
              'Retrying (attempt ${attempt + 1} of ${_maxRetries + 1})...',
        );
      }

      try {
        final aiCallStart = DateTime.now();
        final result = await textProvider
            .complete(messagesWithImage)
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
          providerUsed: textProvider.providerName,
          modelUsed: textProvider.currentModel,
        );

        state = const EvaluationState.loading(statusText: 'Saving results...');

        await _repository.save(evaluation);

        final totalElapsed =
            DateTime.now().difference(startedAt).inMilliseconds;
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
          level: 1000,
        );
        state = EvaluationState.error(e.message);
        return;
      } on Exception catch (e, stackTrace) {
        dev.log(
          'requestEvaluation: retry attempt $attempt failed — $e',
          name: 'EvaluationController',
          level: 900,
          error: e,
          stackTrace: stackTrace,
        );
        lastError = e;
      }
    }

    state = EvaluationState.error(
      lastError?.toString() ?? 'Unknown error during evaluation',
    );
  }

  /// Transcribes audio for each stage's notes using the Audio model.
  Future<List<StageNote>> _transcribeNotesWithAudio(
    List<StageNote> notes,
    AiProviderConfig? config,
    String? audioModelOverride,
  ) async {
    final result = <StageNote>[];
    final audioProvider = _resolveAudioProvider(config, audioModelOverride);

    for (final note in notes) {
      if (note.audioFilePath != null && note.audioFilePath!.isNotEmpty) {
        final file = File(note.audioFilePath!);
        if (await file.exists()) {
          try {
            final audioBytes = await file.readAsBytes();
            String transcript;
            if (audioProvider != null &&
                audioProvider.supportsAudioTranscription) {
              state = EvaluationState.loading(
                statusText: 'Transcribing ${note.stage.displayName}...',
              );
              transcript = await audioProvider.transcribe(
                audioBytes,
                mimeType: 'audio/flac',
              );
            } else {
              // No audio support — use existing notes text
              transcript = note.notes;
            }
            result.add(note.copyWith(notes: '${note.notes}\n\n[Transcript]: $transcript'));
          } catch (e) {
            dev.log(
              'Failed to transcribe audio for stage ${note.stage.displayName}: $e',
              name: 'EvaluationController',
              level: 900,
            );
            result.add(note);
          }
        } else {
          result.add(note);
        }
      } else {
        result.add(note);
      }
    }

    return result;
  }

  /// System prompt for whiteboard-only vision evaluation.
  String _whiteboardSystemPrompt() => '''
You are an expert system design interviewer. Describe and briefly evaluate the whiteboard diagram shown.
Return a short JSON: { "description": "...", "quality": 0-10 }.
''';

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
