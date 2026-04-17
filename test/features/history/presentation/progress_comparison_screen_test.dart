import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/history/application/comparison_controller.dart';
import 'package:prepare_with_atlas/features/history/application/comparison_state.dart';
import 'package:prepare_with_atlas/features/history/domain/progress_diff.dart';
import 'package:prepare_with_atlas/features/history/presentation/progress_comparison_screen.dart';

class _StubComparisonController extends ComparisonController {
  _StubComparisonController(this._stubState);

  final ComparisonState _stubState;

  @override
  ComparisonState build() => _stubState;

  @override
  Future<void> loadComparison({
    required String priorSessionId,
    required String currentSessionId,
  }) async {}
}

EvaluationResult _makeEval({
  required String id,
  required int overall,
}) =>
    EvaluationResult(
      id: id,
      sessionId: '1',
      scorecard: {
        'requirementsGathering': overall - 1,
        'estimationQuality': overall,
        'highLevelDesign': overall,
        'deepDiveQuality': overall,
        'scalingAwareness': overall,
        'communicationClarity': overall,
        'overall': overall,
      },
      overallScore: overall,
      strengths: const [],
      improvements: const [],
      narrative: '',
      providerUsed: 'anthropic',
      modelUsed: 'claude-3-5-sonnet',
      createdAt: DateTime(2026, 4, 9),
    );

Widget _buildScreen(ComparisonState state) {
  return ProviderScope(
    overrides: [
      comparisonControllerProvider.overrideWith(
        () => _StubComparisonController(state),
      ),
    ],
    child: const MaterialApp(
      home: ProgressComparisonScreen(
        priorSessionId: '1',
        currentSessionId: '2',
      ),
    ),
  );
}

void main() {
  final prior = _makeEval(id: 'e1', overall: 5);
  final current = _makeEval(id: 'e2', overall: 8);
  final diff = ProgressDiff.from(prior, current);

  group('ProgressComparisonScreen', () {
    testWidgets('shows loading indicator while loading', (tester) async {
      await tester.pumpWidget(_buildScreen(const ComparisonLoading()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message on ComparisonError', (tester) async {
      await tester.pumpWidget(
        _buildScreen(const ComparisonError(message: 'No evaluation found')),
      );
      await tester.pump();

      expect(find.text('No evaluation found'), findsOneWidget);
    });

    testWidgets('shows Prior and Current column headers on success',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(ComparisonSuccess(diff: diff)),
      );
      await tester.pump();

      expect(find.text('Prior'), findsAtLeastNWidgets(1));
      expect(find.text('Current'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows positive delta chip with + prefix', (tester) async {
      await tester.pumpWidget(
        _buildScreen(ComparisonSuccess(diff: diff)),
      );
      await tester.pump();

      // overall delta should be +3
      expect(find.textContaining('+'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows overall score trend at top', (tester) async {
      await tester.pumpWidget(
        _buildScreen(ComparisonSuccess(diff: diff)),
      );
      await tester.pump();

      // Prior overall: 5, Current overall: 8
      expect(find.text('5'), findsAtLeastNWidgets(1));
      expect(find.text('8'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows N/A for null delta', (tester) async {
      // Create a diff where a dimension is missing in prior
      final priorNoScaling = EvaluationResult(
        id: 'e1',
        sessionId: '1',
        scorecard: const {
          'requirementsGathering': 5,
          'estimationQuality': 5,
          'highLevelDesign': 5,
          'deepDiveQuality': 5,
          'communicationClarity': 5,
          'overall': 5,
          // scalingAwareness missing
        },
        overallScore: 5,
        strengths: const [],
        improvements: const [],
        narrative: '',
        providerUsed: 'anthropic',
        modelUsed: 'claude-3-5-sonnet',
        createdAt: DateTime(2026, 4, 9),
      );
      final diffWithNull = ProgressDiff.from(priorNoScaling, current);

      await tester.pumpWidget(
        _buildScreen(ComparisonSuccess(diff: diffWithNull)),
      );
      await tester.pump();

      expect(find.text('N/A'), findsAtLeastNWidgets(1));
    });
  });
}
