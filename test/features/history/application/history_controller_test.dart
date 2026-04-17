import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/history/application/history_providers.dart';
import 'package:prepare_with_atlas/features/history/application/history_state.dart';
import 'package:prepare_with_atlas/features/history/application/history_view_mode.dart';
import 'package:prepare_with_atlas/features/history/domain/history_repository.dart';
import 'package:prepare_with_atlas/features/history/domain/problem_attempts.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';

import 'history_controller_test.mocks.dart';

@GenerateMocks([HistoryRepository])
void main() {
  late MockHistoryRepository mockRepo;
  late ProviderContainer container;

  final stubSession = InterviewSession(
    id: 1,
    problemId: 1,
    mode: SessionMode.full,
    timerBehavior: TimerBehavior.softWarning,
    timerConfig: const TimerConfig(),
    startedAt: DateTime(2026, 4, 9),
    status: SessionStatus.completed,
  );

  final stubSummary = SessionSummary(
    session: stubSession,
    problemTitle: 'Design a URL Shortener',
    overallScore: 7,
  );

  final stubGroup = ProblemAttempts(
    problemId: '1',
    problemTitle: 'Design a URL Shortener',
    attempts: [stubSummary],
    firstScore: 7,
    latestScore: 7,
  );

  /// Waits until [historyControllerProvider] emits a state where [predicate]
  /// returns true, or times out after [timeoutMs] milliseconds.
  Future<HistoryState> waitForState(
    ProviderContainer c,
    bool Function(HistoryState) predicate, {
    int timeoutMs = 2000,
  }) async {
    final completer = Completer<HistoryState>();
    final sub = c.listen(historyControllerProvider, (_, next) {
      if (!completer.isCompleted && predicate(next)) {
        completer.complete(next);
      }
    });
    // Also check current state immediately.
    final current = c.read(historyControllerProvider);
    if (predicate(current) && !completer.isCompleted) {
      completer.complete(current);
    }
    final result = await completer.future
        .timeout(Duration(milliseconds: timeoutMs));
    sub.close();
    return result;
  }

  setUp(() {
    mockRepo = MockHistoryRepository();

    when(mockRepo.watchHistory()).thenAnswer(
      (_) => Stream.value([stubSummary]),
    );
    when(mockRepo.watchHistoryByProblem()).thenAnswer(
      (_) => Stream.value([stubGroup]),
    );

    container = ProviderContainer(
      overrides: [
        historyRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('HistoryController', () {
    test('initial state has isLoading true before streams emit', () {
      when(mockRepo.watchHistory()).thenAnswer(
        (_) => const Stream.empty(),
      );
      when(mockRepo.watchHistoryByProblem()).thenAnswer(
        (_) => const Stream.empty(),
      );

      final freshContainer = ProviderContainer(
        overrides: [
          historyRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(freshContainer.dispose);

      final state = freshContainer.read(historyControllerProvider);
      expect(state.isLoading, isTrue);
      expect(state.viewMode, HistoryViewMode.flat);
    });

    test('loads session list from repository stream', () async {
      final state = await waitForState(
        container,
        (s) => s.sessions.isNotEmpty,
      );
      expect(state.sessions, hasLength(1));
      expect(state.sessions.first.problemTitle, 'Design a URL Shortener');
      expect(state.sessions.first.overallScore, 7);
    });

    test('toggleView switches from flat to byProblem', () {
      container.read(historyControllerProvider.notifier).toggleView();
      final state = container.read(historyControllerProvider);
      expect(state.viewMode, HistoryViewMode.byProblem);
    });

    test('toggleView switches from byProblem back to flat', () {
      container.read(historyControllerProvider.notifier)
        ..toggleView()
        ..toggleView();
      final state = container.read(historyControllerProvider);
      expect(state.viewMode, HistoryViewMode.flat);
    });

    test('deleteSession delegates to repository', () async {
      when(mockRepo.deleteSession(1)).thenAnswer((_) async {});

      await container
          .read(historyControllerProvider.notifier)
          .deleteSession(1);

      verify(mockRepo.deleteSession(1)).called(1);
    });

    test('problemGroups is populated from watchHistoryByProblem', () async {
      final state = await waitForState(
        container,
        (s) => s.problemGroups.isNotEmpty,
      );
      expect(state.problemGroups, hasLength(1));
      expect(state.problemGroups.first.problemTitle, 'Design a URL Shortener');
    });
  });
}
