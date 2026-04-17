import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_completion_result.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_dependency_providers.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_repository.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/history/application/re_evaluation_controller.dart';
import 'package:prepare_with_atlas/features/history/application/re_evaluation_state.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';

import 're_evaluation_controller_test.mocks.dart';

@GenerateMocks([AiProvider, EvaluationRepository])
void main() {
  late MockAiProvider mockProvider;
  late MockEvaluationRepository mockRepo;
  late ProviderContainer container;

  const sessionId = 42;

  final problem = Problem(
    id: 1,
    title: 'Design a URL Shortener',
    description: 'Build a URL shortener service.',
    difficulty: 'medium',
    category: 'web',
    createdAt: DateTime(2026, 4, 9),
  );

  final notes = [
    StageNote(
      id: 1,
      sessionId: sessionId,
      stage: InterviewStage.requirementGathering,
      timerDurationSeconds: 420,
      timeSpentSeconds: 390,
      notes: 'Requirements discussion',
      updatedAt: DateTime(2026, 4, 9),
    ),
  ];

  const validAiResponse = r'''
{
  "scorecard": {
    "requirementsGathering": 8,
    "estimationQuality": 6,
    "highLevelDesign": 7,
    "deepDiveQuality": 7,
    "scalingAwareness": 5,
    "communicationClarity": 8,
    "overall": 7
  },
  "strengths": ["Clear questions"],
  "improvements": ["Deeper scaling"],
  "narrative": "## Second opinion\n\nLGTM."
}
''';

  setUp(() {
    mockProvider = MockAiProvider();
    mockRepo = MockEvaluationRepository();

    when(mockProvider.providerName).thenReturn('gemini');
    when(mockProvider.currentModel).thenReturn('gemini-1.5-pro');
    when(mockProvider.supportsVision).thenReturn(true);
    when(mockRepo.save(any)).thenAnswer((_) async {});
    when(mockRepo.getAllBySessionId(any)).thenAnswer((_) async => const []);
    when(mockRepo.getBySessionId(any)).thenAnswer((_) async => null);

    container = ProviderContainer(
      overrides: [
        evaluationRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  ReEvaluationController controllerFor(ProviderContainer c) =>
      c.read(reEvaluationControllerProvider.notifier);

  group('ReEvaluationController', () {
    test('initial status for any session is ReEvaluationIdle', () {
      final status = controllerFor(container).statusFor(sessionId);
      expect(status, isA<ReEvaluationIdle>());
    });

    test('start → running → success; new evaluation persisted', () async {
      when(mockProvider.complete(any)).thenAnswer(
        (_) async => const AiCompletionResult(
          content: validAiResponse,
          providerName: 'gemini',
          modelUsed: 'gemini-1.5-pro',
          promptTokens: 10,
          completionTokens: 20,
        ),
      );

      final statuses = <ReEvaluationStatus>[];
      final sub = container.listen(
        reEvaluationControllerProvider,
        (_, next) {
          final s = next[sessionId];
          if (s != null) statuses.add(s);
        },
      );

      await controllerFor(container).start(
        sessionId: sessionId,
        problem: problem,
        notes: notes,
        provider: mockProvider,
      );

      sub.close();

      expect(
        statuses.whereType<ReEvaluationRunning>(),
        isNotEmpty,
        reason: 'should emit Running before terminal state',
      );
      expect(statuses.last, isA<ReEvaluationSuccess>());

      final saved = verify(mockRepo.save(captureAny)).captured.single
          as EvaluationResult;
      expect(saved.sessionId, sessionId.toString());
      expect(saved.providerUsed, 'gemini');
      expect(saved.modelUsed, 'gemini-1.5-pro');
    });

    test('AI failure → status becomes ReEvaluationError', () async {
      when(mockProvider.complete(any)).thenThrow(
        const AiProviderException('boom'),
      );

      await controllerFor(container).start(
        sessionId: sessionId,
        problem: problem,
        notes: notes,
        provider: mockProvider,
      );

      final status =
          controllerFor(container).statusFor(sessionId);
      expect(status, isA<ReEvaluationError>());
      final err = status as ReEvaluationError;
      expect(err.providerName, 'gemini');
      expect(err.message, contains('boom'));
      verifyNever(mockRepo.save(any));
    });

    test('parse failure → status becomes ReEvaluationError', () async {
      when(mockProvider.complete(any)).thenAnswer(
        (_) async => const AiCompletionResult(
          content: 'not json at all',
          providerName: 'gemini',
          modelUsed: 'gemini-1.5-pro',
          promptTokens: 1,
          completionTokens: 1,
        ),
      );

      await controllerFor(container).start(
        sessionId: sessionId,
        problem: problem,
        notes: notes,
        provider: mockProvider,
      );

      expect(
        controllerFor(container).statusFor(sessionId),
        isA<ReEvaluationError>(),
      );
      verifyNever(mockRepo.save(any));
    });

    test(
      'concurrent re-evaluations on different sessions do not collide',
      () async {
        when(mockProvider.complete(any)).thenAnswer(
          (_) async => const AiCompletionResult(
            content: validAiResponse,
            providerName: 'gemini',
            modelUsed: 'gemini-1.5-pro',
            promptTokens: 1,
            completionTokens: 1,
          ),
        );

        final a = controllerFor(container).start(
          sessionId: 1,
          problem: problem,
          notes: notes,
          provider: mockProvider,
        );
        final b = controllerFor(container).start(
          sessionId: 2,
          problem: problem,
          notes: notes,
          provider: mockProvider,
        );
        await Future.wait([a, b]);

        expect(
          controllerFor(container).statusFor(1),
          isA<ReEvaluationSuccess>(),
        );
        expect(
          controllerFor(container).statusFor(2),
          isA<ReEvaluationSuccess>(),
        );
      },
    );

    test(
      'duplicate start on a session already running is ignored',
      () async {
        final completer = Completer<AiCompletionResult>();
        when(mockProvider.complete(any))
            .thenAnswer((_) => completer.future);

        // Fire the first call but do not resolve the AI completer yet.
        final firstCall = controllerFor(container).start(
          sessionId: sessionId,
          problem: problem,
          notes: notes,
          provider: mockProvider,
        );

        // Second call while first is still running should be a no-op.
        await controllerFor(container).start(
          sessionId: sessionId,
          problem: problem,
          notes: notes,
          provider: mockProvider,
        );

        // Resolve the first AI call so the test can finish cleanly.
        completer.complete(
          const AiCompletionResult(
            content: validAiResponse,
            providerName: 'gemini',
            modelUsed: 'gemini-1.5-pro',
            promptTokens: 1,
            completionTokens: 1,
          ),
        );
        await firstCall;

        verify(mockProvider.complete(any)).called(1);
      },
    );

    test('dismiss clears status for the given session', () async {
      when(mockProvider.complete(any)).thenAnswer(
        (_) async => const AiCompletionResult(
          content: validAiResponse,
          providerName: 'gemini',
          modelUsed: 'gemini-1.5-pro',
          promptTokens: 1,
          completionTokens: 1,
        ),
      );

      await controllerFor(container).start(
        sessionId: sessionId,
        problem: problem,
        notes: notes,
        provider: mockProvider,
      );
      expect(
        controllerFor(container).statusFor(sessionId),
        isA<ReEvaluationSuccess>(),
      );

      controllerFor(container).dismiss(sessionId);
      expect(
        controllerFor(container).statusFor(sessionId),
        isA<ReEvaluationIdle>(),
      );
    });
  });
}
