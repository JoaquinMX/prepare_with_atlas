import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/history/application/history_providers.dart';
import 'package:prepare_with_atlas/features/history/application/history_state.dart';
import 'package:prepare_with_atlas/features/history/application/history_view_mode.dart';
import 'package:prepare_with_atlas/features/history/domain/problem_attempts.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';
import 'package:prepare_with_atlas/features/history/presentation/session_history_screen.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

/// Stub that extends [HistoryController] with a pre-set state.
class _StubHistoryController extends HistoryController {
  _StubHistoryController(this._stubState);

  final HistoryState _stubState;

  @override
  HistoryState build() => _stubState;

  @override
  void toggleView() {
    state = state.copyWith(
      viewMode: state.viewMode == HistoryViewMode.flat
          ? HistoryViewMode.byProblem
          : HistoryViewMode.flat,
    );
  }

  @override
  Future<void> deleteSession(int sessionId) async {}
}

InterviewSession _makeSession(int id) => InterviewSession(
      id: id,
      problemId: id,
      mode: SessionMode.full,
      timerBehavior: TimerBehavior.softWarning,
      timerConfig: const TimerConfig(),
      startedAt: DateTime(2026, 4, id),
      status: SessionStatus.completed,
    );

Widget _buildScreen(HistoryState stubState) {
  return ProviderScope(
    overrides: [
      historyControllerProvider
          .overrideWith(() => _StubHistoryController(stubState)),
    ],
    child: const MaterialApp(home: SessionHistoryScreen()),
  );
}

void main() {
  final summary1 = SessionSummary(
    session: _makeSession(1),
    problemTitle: 'Design a URL Shortener',
    overallScore: 8,
  );

  final summary2 = SessionSummary(
    session: _makeSession(2),
    problemTitle: 'Design a CDN',
    overallScore: 5,
  );

  final group1 = ProblemAttempts(
    problemId: '1',
    problemTitle: 'Design a URL Shortener',
    attempts: [summary1],
    firstScore: 8,
    latestScore: 8,
  );

  group('SessionHistoryScreen', () {
    testWidgets('flat view renders session list with problem title and score',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          HistoryState(
            sessions: [summary1, summary2],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Design a URL Shortener'), findsOneWidget);
      expect(find.text('Design a CDN'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('empty state shows encouraging message', (tester) async {
      await tester.pumpWidget(
        _buildScreen(const HistoryState()),
      );
      await tester.pump();

      expect(find.text('No sessions yet. Start your first interview!'),
          findsOneWidget);
    });

    testWidgets('toggle button switches to grouped view', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          HistoryState(sessions: [summary1]),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.grid_view));
      await tester.pump();

      // After toggle, viewMode is byProblem — icon switches to list
      expect(find.byIcon(Icons.list), findsOneWidget);
    });

    testWidgets('grouped view shows problem groups with attempt count',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          HistoryState(
            viewMode: HistoryViewMode.byProblem,
            sessions: [summary1],
            problemGroups: [group1],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Design a URL Shortener'), findsOneWidget);
      // Attempt count text
      expect(find.textContaining('1 attempt'), findsOneWidget);
    });

    testWidgets('grouped view shows trend arrow for improving score',
        (tester) async {
      final group = ProblemAttempts(
        problemId: '1',
        problemTitle: 'Design a URL Shortener',
        attempts: [summary1],
        firstScore: 4,
        latestScore: 8,
      );

      await tester.pumpWidget(
        _buildScreen(
          HistoryState(
            viewMode: HistoryViewMode.byProblem,
            problemGroups: [group],
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('grouped view shows trend arrow for declining score',
        (tester) async {
      final group = ProblemAttempts(
        problemId: '1',
        problemTitle: 'Design a URL Shortener',
        attempts: [summary1],
        firstScore: 8,
        latestScore: 4,
      );

      await tester.pumpWidget(
        _buildScreen(
          HistoryState(
            viewMode: HistoryViewMode.byProblem,
            problemGroups: [group],
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.trending_down), findsOneWidget);
    });
  });
}
