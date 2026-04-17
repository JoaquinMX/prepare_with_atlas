import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_controller.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_providers.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_state.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/evaluation/presentation/evaluation_result_screen.dart';
import 'package:prepare_with_atlas/features/evaluation/presentation/score_card_widget.dart';

void main() {
  final fullResult = EvaluationResult(
    id: 'eval-1',
    sessionId: 'session-1',
    scorecard: const {
      'requirementsGathering': 8,
      'estimationQuality': 6,
      'highLevelDesign': 7,
      'deepDiveQuality': 7,
      'scalingAwareness': 5,
      'communicationClarity': 8,
      'overall': 7,
    },
    overallScore: 7,
    strengths: const [
      'Clear requirements clarification',
      'Good high-level design',
    ],
    improvements: const [
      'Deeper dive into caching',
      'More detail on scaling',
    ],
    narrative: '## Overall Assessment\n\nSolid performance overall.',
    providerUsed: 'anthropic',
    modelUsed: 'claude-3-5-sonnet',
    createdAt: DateTime(2026, 4, 9),
  );

  final resultWithRef = fullResult.copyWith(
    referenceComparison: 'Compared to reference: good alignment.',
  );

  Widget buildUnderTest({
    required EvaluationResult result,
    String? navigatedTo,
  }) {
    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(
          path: '/result',
          builder: (_, __) => const EvaluationResultScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        evaluationControllerProvider.overrideWith(
          () => _FakeSuccessController(result),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('EvaluationResultScreen', () {
    testWidgets('ScoreCardWidget is present', (tester) async {
      await tester.pumpWidget(buildUnderTest(result: fullResult));
      await tester.pump();
      expect(find.byType(ScoreCardWidget), findsOneWidget);
    });

    testWidgets('narrative text is rendered', (tester) async {
      await tester.pumpWidget(buildUnderTest(result: fullResult));
      await tester.pump();
      // Markdown renders the text content
      expect(find.textContaining('Solid performance overall'), findsOneWidget);
    });

    testWidgets('strengths section with bullet points', (tester) async {
      await tester.pumpWidget(buildUnderTest(result: fullResult));
      await tester.pump();
      expect(
        find.textContaining('Clear requirements clarification'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Good high-level design'),
        findsOneWidget,
      );
    });

    testWidgets('improvements section with bullet points', (tester) async {
      await tester.pumpWidget(buildUnderTest(result: fullResult));
      await tester.pump();
      expect(
        find.textContaining('Deeper dive into caching'),
        findsOneWidget,
      );
      expect(
        find.textContaining('More detail on scaling'),
        findsOneWidget,
      );
    });

    testWidgets(
        'reference comparison NOT shown when referenceComparison is null',
        (tester) async {
      await tester.pumpWidget(buildUnderTest(result: fullResult));
      await tester.pump();
      expect(
        find.textContaining('Reference Comparison'),
        findsNothing,
      );
    });

    testWidgets(
        'reference comparison IS shown when referenceComparison is set',
        (tester) async {
      await tester.pumpWidget(buildUnderTest(result: resultWithRef));
      await tester.pump();
      expect(
        find.textContaining('Reference Comparison'),
        findsOneWidget,
      );
      expect(
        find.textContaining('good alignment'),
        findsOneWidget,
      );
    });

    testWidgets('Back to Home button is present', (tester) async {
      await tester.pumpWidget(buildUnderTest(result: fullResult));
      await tester.pump();
      expect(find.text('Back to Home'), findsOneWidget);
    });

    testWidgets('Back to Home button navigates to /', (tester) async {
      await tester.pumpWidget(buildUnderTest(result: fullResult));
      await tester.pump();

      // Scroll down to reveal the button
      await tester.scrollUntilVisible(
        find.text('Back to Home'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });
  });
}

/// A fake controller that emits [EvaluationSuccess] with a given result.
class _FakeSuccessController extends EvaluationController {
  _FakeSuccessController(this._result);

  final EvaluationResult _result;

  @override
  EvaluationState build() => EvaluationState.success(_result);
}
