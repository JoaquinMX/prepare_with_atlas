import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/features/history/application/history_providers.dart';
import 'package:prepare_with_atlas/features/history/application/history_state.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';
import 'package:prepare_with_atlas/presentation/home/home_screen.dart';

/// Stub controller that returns a pre-set [HistoryState].
class _StubHistoryController extends HistoryController {
  _StubHistoryController(this._stubState);

  final HistoryState _stubState;

  @override
  HistoryState build() => _stubState;
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

/// Wraps [HomeScreen] with a minimal router and provider scope.
Widget _buildScreen(HistoryState stubState) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/problems',
        builder: (_, __) => const Scaffold(body: Text('Problems')),
      ),
      GoRoute(
        path: '/history/detail/:sessionId',
        builder: (_, __) => const Scaffold(body: Text('Detail')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      historyControllerProvider
          .overrideWith(() => _StubHistoryController(stubState)),
    ],
    child: MaterialApp.router(routerConfig: router),
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

  final summary3 = SessionSummary(
    session: _makeSession(3),
    problemTitle: 'Design Twitter',
  );

  group('HomeScreen', () {
    testWidgets('shows empty state when no sessions', (tester) async {
      await tester.pumpWidget(
        _buildScreen(const HistoryState()),
      );
      await tester.pump();

      expect(find.textContaining('No sessions yet'), findsOneWidget);
    });

    testWidgets('shows Start New Interview button', (tester) async {
      await tester.pumpWidget(
        _buildScreen(const HistoryState()),
      );
      await tester.pump();

      expect(find.textContaining('Start New Interview'), findsOneWidget);
    });

    testWidgets('shows stats section labels', (tester) async {
      await tester.pumpWidget(
        _buildScreen(const HistoryState()),
      );
      await tester.pump();

      // 'Sessions' stat label appears in stats row; 'Recent Sessions' is also
      // present — verify the exact stat tile label exists.
      expect(find.text('Sessions'), findsOneWidget);
    });

    testWidgets('shows session rows with problem titles for 3 sessions',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          HistoryState(sessions: [summary3, summary2, summary1]),
        ),
      );
      await tester.pump();

      expect(find.text('Design a URL Shortener'), findsOneWidget);
      expect(find.text('Design a CDN'), findsOneWidget);
      expect(find.text('Design Twitter'), findsOneWidget);
    });

    testWidgets('shows only first 3 sessions when more exist', (tester) async {
      final extra = SessionSummary(
        session: _makeSession(4),
        problemTitle: 'Design Uber',
        overallScore: 7,
      );
      await tester.pumpWidget(
        _buildScreen(
          HistoryState(sessions: [extra, summary3, summary2, summary1]),
        ),
      );
      await tester.pump();

      // First 3 in the list are shown, the 4th (summary1) should not appear
      expect(find.text('Design Uber'), findsOneWidget);
      expect(find.text('Design Twitter'), findsOneWidget);
      expect(find.text('Design a CDN'), findsOneWidget);
      expect(find.text('Design a URL Shortener'), findsNothing);
    });

    testWidgets('session with null score shows N/A badge', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          HistoryState(sessions: [summary3]),
        ),
      );
      await tester.pump();

      // N/A appears in both the Avg Score stat tile and the session row badge.
      expect(find.text('N/A'), findsWidgets);
    });

    testWidgets('session with score shows numeric badge', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          HistoryState(sessions: [summary1]),
        ),
      );
      await tester.pump();

      // '8' appears in both the Avg Score stat tile and the session row badge.
      expect(find.text('8'), findsWidgets);
    });

    testWidgets('stats show correct session count', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          HistoryState(sessions: [summary1, summary2]),
        ),
      );
      await tester.pump();

      // Session count = 2
      expect(find.text('2'), findsWidgets);
    });
  });
}
