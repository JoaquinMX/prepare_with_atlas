import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_repository.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/history/application/comparison_controller.dart';
import 'package:prepare_with_atlas/features/history/application/comparison_state.dart';

import 'comparison_controller_test.mocks.dart';

@GenerateMocks([EvaluationRepository])
void main() {
  late MockEvaluationRepository mockEvalRepo;
  late ProviderContainer container;

  final baseScorecard = <String, int>{
    'requirementsGathering': 6,
    'estimationQuality': 5,
    'highLevelDesign': 7,
    'deepDiveQuality': 4,
    'scalingAwareness': 5,
    'communicationClarity': 6,
    'overall': 6,
  };

  EvaluationResult makeEval(String id, String sessionId, {int overall = 6}) =>
      EvaluationResult(
        id: id,
        sessionId: sessionId,
        scorecard: {...baseScorecard, 'overall': overall},
        overallScore: overall,
        strengths: const [],
        improvements: const [],
        narrative: '',
        providerUsed: 'anthropic',
        modelUsed: 'claude-3-5-sonnet',
        createdAt: DateTime(2026, 4, 9),
      );

  setUp(() {
    mockEvalRepo = MockEvaluationRepository();

    container = ProviderContainer(
      overrides: [
        comparisonEvaluationRepositoryProvider
            .overrideWithValue(mockEvalRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('ComparisonController', () {
    test('initial state is ComparisonIdle', () {
      final state = container.read(comparisonControllerProvider);
      expect(state, isA<ComparisonIdle>());
    });

    test('loadComparison emits success with ProgressDiff', () async {
      when(mockEvalRepo.getBySessionId('1'))
          .thenAnswer((_) async => makeEval('e1', '1', overall: 5));
      when(mockEvalRepo.getBySessionId('2'))
          .thenAnswer((_) async => makeEval('e2', '2', overall: 8));

      await container
          .read(comparisonControllerProvider.notifier)
          .loadComparison(priorSessionId: '1', currentSessionId: '2');

      final state = container.read(comparisonControllerProvider);
      expect(state, isA<ComparisonSuccess>());
      final success = state as ComparisonSuccess;
      expect(success.diff.overallDelta, 3);
      expect(success.diff.priorEvaluation.id, 'e1');
      expect(success.diff.currentEvaluation.id, 'e2');
    });

    test(
        'loadComparison emits error when prior evaluation is missing',
        () async {
      when(mockEvalRepo.getBySessionId('1'))
          .thenAnswer((_) async => null);
      when(mockEvalRepo.getBySessionId('2'))
          .thenAnswer((_) async => makeEval('e2', '2', overall: 8));

      await container
          .read(comparisonControllerProvider.notifier)
          .loadComparison(priorSessionId: '1', currentSessionId: '2');

      final state = container.read(comparisonControllerProvider);
      expect(state, isA<ComparisonError>());
    });

    test(
        'loadComparison emits error when current evaluation is missing',
        () async {
      when(mockEvalRepo.getBySessionId('1'))
          .thenAnswer((_) async => makeEval('e1', '1', overall: 5));
      when(mockEvalRepo.getBySessionId('2'))
          .thenAnswer((_) async => null);

      await container
          .read(comparisonControllerProvider.notifier)
          .loadComparison(priorSessionId: '1', currentSessionId: '2');

      final state = container.read(comparisonControllerProvider);
      expect(state, isA<ComparisonError>());
    });

    test('loadComparison emits loading state first', () async {
      when(mockEvalRepo.getBySessionId('1'))
          .thenAnswer((_) async => makeEval('e1', '1'));
      when(mockEvalRepo.getBySessionId('2'))
          .thenAnswer((_) async => makeEval('e2', '2', overall: 8));

      final states = <ComparisonState>[];
      final sub = container.listen(
        comparisonControllerProvider,
        (_, next) => states.add(next),
      );

      await container
          .read(comparisonControllerProvider.notifier)
          .loadComparison(priorSessionId: '1', currentSessionId: '2');

      sub.close();
      expect(states.any((s) => s is ComparisonLoading), isTrue);
      expect(states.last, isA<ComparisonSuccess>());
    });
  });
}
