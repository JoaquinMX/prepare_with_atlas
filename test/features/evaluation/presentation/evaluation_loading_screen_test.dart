import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_controller.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_providers.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_state.dart';
import 'package:prepare_with_atlas/features/evaluation/presentation/evaluation_loading_screen.dart';

void main() {
  Widget buildUnderTest({
    EvaluationState initialState = const EvaluationState.loading(),
  }) {
    return ProviderScope(
      overrides: [
        evaluationControllerProvider.overrideWith(
          () => _FakeEvaluationController(initialState),
        ),
      ],
      child: const MaterialApp(
        home: EvaluationLoadingScreen(),
      ),
    );
  }

  group('EvaluationLoadingScreen', () {
    testWidgets('shows progress indicator in loading state', (tester) async {
      await tester.pumpWidget(buildUnderTest());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows status text from loading state', (tester) async {
      await tester.pumpWidget(
        buildUnderTest(
          initialState: const EvaluationState.loading(
            statusText: 'Analysing your session...',
          ),
        ),
      );
      expect(find.text('Analysing your session...'), findsOneWidget);
    });

    testWidgets('error state shows error message', (tester) async {
      await tester.pumpWidget(
        buildUnderTest(
          initialState: const EvaluationState.error('Network error'),
        ),
      );
      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('error state shows Retry button', (tester) async {
      await tester.pumpWidget(
        buildUnderTest(
          initialState: const EvaluationState.error('Something went wrong'),
        ),
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

/// A minimal fake [EvaluationController] that emits a fixed [EvaluationState].
class _FakeEvaluationController extends EvaluationController {
  _FakeEvaluationController(this._initialState);

  final EvaluationState _initialState;

  @override
  EvaluationState build() => _initialState;
}
