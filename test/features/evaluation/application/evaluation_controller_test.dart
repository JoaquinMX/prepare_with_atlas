import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_completion_result.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_providers.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_state.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';

import 'evaluation_controller_test.mocks.dart';

@GenerateMocks([AiProvider, EvaluationRepository])
void main() {
  late MockAiProvider mockProvider;
  late MockEvaluationRepository mockRepo;
  late ProviderContainer container;

  final session = InterviewSession(
    id: 1,
    problemId: 1,
    mode: SessionMode.full,
    timerBehavior: TimerBehavior.softWarning,
    timerConfig: const TimerConfig(),
    startedAt: DateTime(2026, 4, 9),
    status: SessionStatus.completed,
  );

  final problem = Problem(
    id: 1,
    title: 'Design a URL Shortener',
    description: 'Build a URL shortener.',
    difficulty: 'medium',
    category: 'web',
    createdAt: DateTime(2026, 4, 9),
  );

  final notes = [
    StageNote(
      id: 1,
      sessionId: 1,
      stage: InterviewStage.requirementGathering,
      timerDurationSeconds: 420,
      timeSpentSeconds: 390,
      notes: 'Good requirements discussion',
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
  "strengths": ["Good requirements"],
  "improvements": ["More depth"],
  "narrative": "## Assessment\n\nSolid.",
  "referenceComparison": null
}
''';

  setUp(() {
    mockProvider = MockAiProvider();
    mockRepo = MockEvaluationRepository();

    when(mockProvider.providerName).thenReturn('anthropic');
    when(mockProvider.currentModel).thenReturn('claude-3-5-sonnet');
    when(mockProvider.supportsVision).thenReturn(false);
    when(mockRepo.save(any)).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        evaluationRepositoryProvider.overrideWithValue(mockRepo),
        activeAiProviderForEvaluationProvider.overrideWithValue(mockProvider),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('EvaluationController.requestEvaluation', () {
    test('success path: calls AI, parses response, saves, emits success',
        () async {
      when(mockProvider.complete(any)).thenAnswer(
        (_) async => const AiCompletionResult(
          content: validAiResponse,
          providerName: 'anthropic',
          modelUsed: 'claude-3-5-sonnet',
          promptTokens: 100,
          completionTokens: 200,
        ),
      );

      final notifier =
          container.read(evaluationControllerProvider.notifier);
      await notifier.requestEvaluation(
        session: session,
        problem: problem,
        notes: notes,
      );

      final state = container.read(evaluationControllerProvider);
      expect(state, isA<EvaluationSuccess>());
      final success = state as EvaluationSuccess;
      expect(success.result.overallScore, 7);
      expect(success.result.providerUsed, 'anthropic');

      verify(mockRepo.save(any)).called(1);
    });

    test('emits loading state before success', () async {
      when(mockProvider.complete(any)).thenAnswer(
        (_) async => const AiCompletionResult(
          content: validAiResponse,
          providerName: 'anthropic',
          modelUsed: 'claude-3-5-sonnet',
          promptTokens: 100,
          completionTokens: 200,
        ),
      );

      final states = <EvaluationState>[];
      final sub = container.listen(
        evaluationControllerProvider,
        (prev, next) => states.add(next),
      );

      final notifier =
          container.read(evaluationControllerProvider.notifier);
      await notifier.requestEvaluation(
        session: session,
        problem: problem,
        notes: notes,
      );

      sub.close();
      expect(states.any((s) => s is EvaluationLoading), isTrue);
      expect(states.last, isA<EvaluationSuccess>());
    });

    test('AI throws → retries, then emits EvaluationError', () async {
      // Always throws
      when(mockProvider.complete(any)).thenThrow(
        const AiProviderException('Network error'),
      );

      final notifier =
          container.read(evaluationControllerProvider.notifier);
      await notifier.requestEvaluation(
        session: session,
        problem: problem,
        notes: notes,
      );

      final state = container.read(evaluationControllerProvider);
      expect(state, isA<EvaluationError>());

      // Should have retried 2 extra times = 3 total calls
      verify(mockProvider.complete(any)).called(3);
    });

    test('parse failure → emits EvaluationError', () async {
      when(mockProvider.complete(any)).thenAnswer(
        (_) async => const AiCompletionResult(
          content: 'This is not valid JSON or scores at all.',
          providerName: 'anthropic',
          modelUsed: 'claude-3-5-sonnet',
          promptTokens: 10,
          completionTokens: 10,
        ),
      );

      final notifier =
          container.read(evaluationControllerProvider.notifier);
      await notifier.requestEvaluation(
        session: session,
        problem: problem,
        notes: notes,
      );

      final state = container.read(evaluationControllerProvider);
      expect(state, isA<EvaluationError>());
    });
  });

  group('EvaluationController initial state', () {
    test('initial state is EvaluationIdle', () {
      final state = container.read(evaluationControllerProvider);
      expect(state, isA<EvaluationIdle>());
    });
  });
}
