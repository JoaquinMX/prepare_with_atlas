import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart'
    show MockPlatformInterfaceMixin;
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_dependency_providers.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/history/application/history_providers.dart';
import 'package:prepare_with_atlas/features/history/application/history_state.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';
import 'package:prepare_with_atlas/features/history/presentation/session_detail_screen.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';
import 'package:prepare_with_atlas/features/whiteboard/application/whiteboard_controller.dart';
import 'package:prepare_with_atlas/features/whiteboard/data/whiteboard_providers.dart';
import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_repository.dart';
import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_snapshot.dart';
import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_state.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class _StubHistoryController extends HistoryController {
  @override
  HistoryState build() => const HistoryState();

  @override
  void toggleView() {}

  @override
  Future<void> deleteSession(int sessionId) async {}
}

/// Stub whiteboard controller that starts in a non-loading ready state so that
/// the whiteboard panel renders the WebView instead of the loading spinner,
/// which allows pumpAndSettle to complete in widget tests.
///
/// Also records whether loadSceneData and setViewMode were called so tests can
/// verify the read-only scene restoration flow.
class _ReadyWhiteboardController extends WhiteboardController {
  bool loadSceneDataCalled = false;
  bool setViewModeCalled = false;
  String? lastSceneJson;

  @override
  WhiteboardState build() => const WhiteboardState(isLoading: false);

  @override
  Future<void> loadSceneData(String json) async {
    loadSceneDataCalled = true;
    lastSceneJson = json;
  }

  @override
  Future<void> setViewMode({required bool viewOnly}) async {
    setViewModeCalled = true;
  }

  @override
  void reset() {
    state = const WhiteboardState(isLoading: false);
  }
}

EvaluationResult _makeEval(String sessionId) => EvaluationResult(
  id: 'eval-1',
  sessionId: sessionId,
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
  strengths: const ['Good'],
  improvements: const ['Improve'],
  narrative: '## Assessment\n\nSolid.',
  providerUsed: 'anthropic',
  modelUsed: 'claude-3-5-sonnet',
  createdAt: DateTime(2026, 4, 9),
);

InterviewSession _makeSession(int id) => InterviewSession(
  id: id,
  problemId: 1,
  mode: SessionMode.full,
  timerBehavior: TimerBehavior.softWarning,
  timerConfig: const TimerConfig(),
  startedAt: DateTime(2026, 4, 9),
  status: SessionStatus.completed,
);

StageNote _makeNote(int sessionId) => StageNote(
  id: 1,
  sessionId: sessionId,
  stage: InterviewStage.highLevelDesign,
  notes: 'My design notes',
  timerDurationSeconds: 720,
  updatedAt: DateTime(2026, 4, 9),
);

SessionSummary _makeSummary({int sessionId = 1}) => SessionSummary(
  session: _makeSession(sessionId),
  problemTitle: 'Design a URL Shortener',
  overallScore: 7,
);

Widget _buildScreen({
  required SessionSummary summary,
  EvaluationResult? evaluation,
  List<StageNote> notes = const [],
  int attemptCount = 1,
  WhiteboardRepository? whiteboardRepo,
  bool readyWhiteboard = false,
}) {
  final sessionId = summary.session.id;
  final problemId = summary.session.problemId;

  return ProviderScope(
    overrides: [
      historyControllerProvider.overrideWith(_StubHistoryController.new),
      stageNotesForSessionProvider(
        sessionId,
      ).overrideWith((ref) async => notes),
      evaluationForSessionProvider(
        sessionId.toString(),
      ).overrideWith((ref) async => evaluation),
      attemptCountForProblemProvider(
        problemId,
      ).overrideWith((ref) async => attemptCount),
      if (whiteboardRepo != null)
        whiteboardRepositoryProvider.overrideWithValue(whiteboardRepo),
      if (readyWhiteboard)
        whiteboardControllerProvider.overrideWith(
          _ReadyWhiteboardController.new,
        ),
    ],
    child: MaterialApp(home: SessionDetailScreen(summary: summary)),
  );
}

void main() {
  group('SessionDetailScreen', () {
    testWidgets('shows three tabs: Notes, Whiteboard, Evaluation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          summary: _makeSummary(),
          evaluation: _makeEval('1'),
          notes: [_makeNote(1)],
        ),
      );
      await tester.pump();

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Whiteboard'), findsOneWidget);
      expect(find.text('Evaluation'), findsOneWidget);
    });

    testWidgets('"Retry This Problem" button is always visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(summary: _makeSummary(), evaluation: _makeEval('1')),
      );
      await tester.pump();

      expect(find.text('Retry This Problem'), findsOneWidget);
    });

    testWidgets('"Compare to Previous" button is hidden when < 2 attempts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(summary: _makeSummary(), evaluation: _makeEval('1')),
      );
      await tester.pump();

      expect(find.text('Compare to Previous'), findsNothing);
    });

    testWidgets('"Compare to Previous" button is visible when >= 2 attempts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          summary: _makeSummary(),
          evaluation: _makeEval('1'),
          attemptCount: 2,
        ),
      );
      await tester.pump();

      expect(find.text('Compare to Previous'), findsOneWidget);
    });

    testWidgets('notes tab shows stage notes text', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          summary: _makeSummary(),
          evaluation: _makeEval('1'),
          notes: [_makeNote(1)],
        ),
      );
      await tester.pump();

      expect(find.text('My design notes'), findsOneWidget);
    });

    testWidgets('evaluation tab shows ScoreCardWidget when tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(summary: _makeSummary(), evaluation: _makeEval('1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Evaluation'));
      await tester.pumpAndSettle();

      // ScoreCardWidget renders dimension labels
      expect(find.text('Requirements Gathering'), findsOneWidget);
    });
  });

  group('_WhiteboardTab', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      final fakeController = _FakePlatformController(
        const PlatformWebViewControllerCreationParams(),
      );
      final fakeWidget = _FakePlatformWidget(
        PlatformWebViewWidgetCreationParams(controller: fakeController),
      );
      WebViewPlatform.instance = _FakeWebViewPlatform(
        controller: fakeController,
        widget: fakeWidget,
      );
    });

    Future<void> openWhiteboardTab(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(screen);
      await tester.pump();
      await tester.tap(find.text('Whiteboard'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows no-snapshot message when repo returns null', (
      tester,
    ) async {
      await openWhiteboardTab(
        tester,
        _buildScreen(
          summary: _makeSummary(),
          whiteboardRepo: _NullWhiteboardRepository(),
        ),
      );

      expect(
        find.text('No whiteboard snapshot for this session.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('whiteboard_panel')), findsNothing);
    });

    testWidgets('shows WhiteboardPanel when repo returns a snapshot', (
      tester,
    ) async {
      await openWhiteboardTab(
        tester,
        _buildScreen(
          summary: _makeSummary(),
          whiteboardRepo: _FixedWhiteboardRepository(
            WhiteboardSnapshot(
              id: 1,
              sessionId: 1,
              sceneJson: '{}',
              capturedAt: DateTime(2026, 4, 9),
            ),
          ),
          // Use a ready state so WhiteboardPanel renders the WebView widget
          // instead of the loading spinner, allowing pumpAndSettle to complete.
          readyWhiteboard: true,
        ),
      );

      expect(find.byKey(const Key('whiteboard_panel')), findsOneWidget);
    });

    testWidgets('view-only mode hides clear toolbar button', (tester) async {
      await openWhiteboardTab(
        tester,
        _buildScreen(
          summary: _makeSummary(),
          whiteboardRepo: _FixedWhiteboardRepository(
            WhiteboardSnapshot(
              id: 1,
              sessionId: 1,
              sceneJson: '{"elements":[]}',
              capturedAt: DateTime(2026, 4, 9),
            ),
          ),
          readyWhiteboard: true,
        ),
      );

      // In view-only mode (History), the clear button should NOT be present.
      expect(find.byKey(const Key('whiteboard_clear_btn')), findsNothing);
    });
  });
}

// ── Fakes ───────────────────────────────────────────────────────────────────

/// Fake repository that always returns null for any snapshot query.
class _NullWhiteboardRepository implements WhiteboardRepository {
  @override
  Future<WhiteboardSnapshot?> getLatestForSession(int sessionId) async => null;

  @override
  Future<void> saveSnapshot({
    required int sessionId,
    required String sceneJson,
    Uint8List? screenshotPng,
  }) async {}
}

/// Fake repository that always returns a fixed snapshot.
class _FixedWhiteboardRepository implements WhiteboardRepository {
  _FixedWhiteboardRepository(this._snapshot);

  final WhiteboardSnapshot _snapshot;

  @override
  Future<WhiteboardSnapshot?> getLatestForSession(int sessionId) async =>
      _snapshot;

  @override
  Future<void> saveSnapshot({
    required int sessionId,
    required String sceneJson,
    Uint8List? screenshotPng,
  }) async {}
}

/// Fake [PlatformWebViewController] that accepts all calls silently.
class _FakePlatformController extends PlatformWebViewController
    with MockPlatformInterfaceMixin {
  _FakePlatformController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> loadFlutterAsset(String key) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async => '';
}

/// Fake [PlatformWebViewWidget] that renders an empty box.
class _FakePlatformWidget extends PlatformWebViewWidget
    with MockPlatformInterfaceMixin {
  _FakePlatformWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// Fake [PlatformNavigationDelegate] that silently accepts all callbacks.
class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate
    with MockPlatformInterfaceMixin {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}
}

/// Fake [WebViewPlatform] that wires up the fakes above.
class _FakeWebViewPlatform extends WebViewPlatform {
  _FakeWebViewPlatform({required this.controller, required this.widget});

  final _FakePlatformController controller;
  final _FakePlatformWidget widget;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller;

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => widget;

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakePlatformNavigationDelegate(params);
}
