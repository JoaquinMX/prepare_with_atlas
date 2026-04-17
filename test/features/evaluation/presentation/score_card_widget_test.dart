import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/evaluation/presentation/score_card_widget.dart';

void main() {
  EvaluationResult makeResult({Map<String, int>? scorecard}) =>
      EvaluationResult(
        id: 'eval-1',
        sessionId: 'session-1',
        scorecard: scorecard ??
            {
              'requirementsGathering': 8,
              'estimationQuality': 5,
              'highLevelDesign': 7,
              'deepDiveQuality': 7,
              'scalingAwareness': 2,
              'communicationClarity': 8,
              'overall': 7,
            },
        overallScore: 7,
        strengths: const ['Good design'],
        improvements: const ['More detail'],
        narrative: '## Narrative',
        providerUsed: 'anthropic',
        modelUsed: 'claude-3-5-sonnet',
        createdAt: DateTime(2026, 4, 9),
      );

  Widget buildWidget(EvaluationResult result) => MaterialApp(
        home: Scaffold(
          body: ScoreCardWidget(result: result),
        ),
      );

  group('ScoreCardWidget', () {
    testWidgets('renders 7 dimension rows', (tester) async {
      await tester.pumpWidget(buildWidget(makeResult()));

      // Each dimension should appear as text somewhere
      expect(find.text('Requirements Gathering'), findsOneWidget);
      expect(find.text('Estimation Quality'), findsOneWidget);
      expect(find.text('High-Level Design'), findsOneWidget);
      expect(find.text('Deep Dive Quality'), findsOneWidget);
      expect(find.text('Scaling Awareness'), findsOneWidget);
      expect(find.text('Communication Clarity'), findsOneWidget);
      expect(find.text('Overall'), findsAtLeastNWidgets(1));
    });

    testWidgets('score 0-3 uses danger color (red)', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          makeResult(
            scorecard: {
              'requirementsGathering': 2,
              'estimationQuality': 3,
              'highLevelDesign': 7,
              'deepDiveQuality': 7,
              'scalingAwareness': 5,
              'communicationClarity': 8,
              'overall': 5,
            },
          ),
        ),
      );

      // Find containers with danger color
      final dangerContainers = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == AtlasColors.danger;
      });
      expect(dangerContainers, findsAtLeastNWidgets(1));
    });

    testWidgets('score 4-6 uses warning color (amber)', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          makeResult(
            scorecard: {
              'requirementsGathering': 5,
              'estimationQuality': 4,
              'highLevelDesign': 7,
              'deepDiveQuality': 7,
              'scalingAwareness': 6,
              'communicationClarity': 8,
              'overall': 6,
            },
          ),
        ),
      );

      final warningContainers = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == AtlasColors.warning;
      });
      expect(warningContainers, findsAtLeastNWidgets(1));
    });

    testWidgets('score 7-10 uses success color (green)', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          makeResult(
            scorecard: {
              'requirementsGathering': 8,
              'estimationQuality': 7,
              'highLevelDesign': 9,
              'deepDiveQuality': 10,
              'scalingAwareness': 7,
              'communicationClarity': 8,
              'overall': 8,
            },
          ),
        ),
      );

      final successContainers = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == AtlasColors.success;
      });
      expect(successContainers, findsAtLeastNWidgets(1));
    });

    testWidgets('overall score is displayed prominently', (tester) async {
      await tester.pumpWidget(buildWidget(makeResult()));

      // The overall score (7) should appear
      expect(find.text('7'), findsAtLeastNWidgets(1));
    });

    testWidgets('N/A shown for missing dimension', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          makeResult(
            scorecard: {
              'requirementsGathering': 8,
              // estimationQuality missing
              'highLevelDesign': 7,
              'deepDiveQuality': 7,
              'scalingAwareness': 5,
              'communicationClarity': 8,
              'overall': 7,
            },
          ),
        ),
      );

      expect(find.text('N/A'), findsAtLeastNWidgets(1));
    });
  });
}
