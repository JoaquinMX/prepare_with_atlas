import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart'
    show MockPlatformInterfaceMixin;
import 'package:prepare_with_atlas/features/interview_session/application/dictation_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/dictation_state.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_state.dart';
import 'package:prepare_with_atlas/features/interview_session/application/stage_timer_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/timer_state.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/session_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';
import 'package:prepare_with_atlas/features/interview_session/presentation/interview_screen.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_repository_provider.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/experience_level.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem_repository.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class _FakeSessionController extends SessionController {
  @override
  SessionState build() => SessionState(
    currentSession: InterviewSession(
      id: 1,
      problemId: 1,
      mode: SessionMode.full,
      timerBehavior: TimerBehavior.softWarning,
      timerConfig: const TimerConfig(),
      startedAt: DateTime(2026, 4, 9),
    ),
    currentStage: InterviewStage.requirementGathering,
  );

  @override
  Future<void> advanceToNextStage() async {}

  @override
  Future<void> endSession() async {}

  @override
  Future<void> abandonSession() async {}
}

class _FakeTimerController extends StageTimerController {
  @override
  TimerState build() => const TimerState.running(
    stage: InterviewStage.requirementGathering,
    remainingSeconds: 420,
    totalSeconds: 420,
  );
}

/// A timer controller that starts running and exposes [triggerStageEnded]
/// so tests can drive the state machine to [TimerStageEnded] synchronously.
class _MutableTimerController extends StageTimerController {
  @override
  TimerState build() => const TimerState.running(
    stage: InterviewStage.requirementGathering,
    remainingSeconds: 420,
    totalSeconds: 420,
  );

  void triggerStageEnded() {
    state = const TimerState.stageEnded(
      stage: InterviewStage.requirementGathering,
      timeSpentSeconds: 420,
    );
  }
}

/// A session controller that records how many times [advanceToNextStage]
/// was called.
class _TrackingSessionController extends SessionController {
  int advanceCalled = 0;

  @override
  SessionState build() => SessionState(
    currentSession: InterviewSession(
      id: 1,
      problemId: 1,
      mode: SessionMode.full,
      timerBehavior: TimerBehavior.hardStop,
      timerConfig: const TimerConfig(),
      startedAt: DateTime(2026, 4, 9),
    ),
    currentStage: InterviewStage.requirementGathering,
  );

  @override
  Future<void> advanceToNextStage() async {
    advanceCalled++;
  }

  @override
  Future<void> endSession() async {}

  @override
  Future<void> abandonSession() async {}
}

class _FakeDictationController extends DictationController {
  @override
  DictationState build() => const DictationIdle();

  @override
  Future<void> cancelListening() async {}

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> toggleListening() async {}

  @override
  Future<void> reset() async {}
}

class _FakeRepo extends Fake implements SessionRepository {}

class _FakeProblemRepo implements ProblemRepository {
  @override
  Future<Problem?> getById(int id) async => null;
  @override
  Future<List<Problem>> getByExperienceLevel(ExperienceLevel level) async => [];
  @override
  Future<List<Problem>> searchByTitle(String query) async => [];
  @override
  Future<int> insert(Problem problem) async => 0;
  @override
  Future<void> delete(int id) async {}
  @override
  Stream<List<Problem>> watchAll() => const Stream.empty();
  @override
  Future<int> count() async => 0;
}

// ── Fake WebView platform ────────────────────────────────────────────────────

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

class _FakePlatformWidget extends PlatformWebViewWidget
    with MockPlatformInterfaceMixin {
  _FakePlatformWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

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

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _FakePlatformController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakePlatformWidget(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakePlatformNavigationDelegate(params);
}

void main() {
  group('InterviewScreen', () {
    Widget buildSubject() => ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(_FakeRepo()),
        problemRepositoryProvider.overrideWithValue(_FakeProblemRepo()),
        sessionControllerProvider.overrideWith(_FakeSessionController.new),
        stageTimerControllerProvider.overrideWith(_FakeTimerController.new),
        dictationControllerProvider.overrideWith(_FakeDictationController.new),
      ],
      child: const MaterialApp(home: InterviewScreen()),
    );

    // Set a wide test surface so the TopBar Row doesn't overflow.
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      WebViewPlatform.instance = _FakeWebViewPlatform();
    });

    testWidgets('renders End Session button', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('End Session'), findsOneWidget);
    });

    testWidgets('renders Abandon button', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Abandon'), findsOneWidget);
    });

    testWidgets('does not render Topics', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Topics'), findsNothing);
    });

    testWidgets('does not render Techniques', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Techniques'), findsNothing);
    });

    testWidgets('does not render Insights', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Insights'), findsNothing);
    });

    // ── Timer-driven stage advance ─────────────────────────────────────────
    //
    // These tests verify that InterviewScreen reacts to TimerStageEnded by
    // automatically calling SessionController.advanceToNextStage(). This is
    // the mechanism behind hard-stop and auto-advance (grace-period) modes.

    testWidgets(
      'calls advanceToNextStage when timer reaches StageEnded',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Use UncontrolledProviderScope so we can access the container
        // directly and mutate the timer state after the widget is pumped.
        final container = ProviderContainer(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(_FakeRepo()),
            problemRepositoryProvider.overrideWithValue(_FakeProblemRepo()),
            sessionControllerProvider.overrideWith(
              _TrackingSessionController.new,
            ),
            stageTimerControllerProvider.overrideWith(
              _MutableTimerController.new,
            ),
            dictationControllerProvider.overrideWith(
              _FakeDictationController.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: InterviewScreen()),
          ),
        );
        await tester.pump();

        final tracking = container.read(sessionControllerProvider.notifier)
            as _TrackingSessionController;
        expect(tracking.advanceCalled, 0);

        // Drive the timer to StageEnded (simulates hard-stop or grace period
        // expiry).
        (container.read(stageTimerControllerProvider.notifier)
                as _MutableTimerController)
            .triggerStageEnded();
        await tester.pump();

        expect(tracking.advanceCalled, 1);
      },
    );

    testWidgets(
      'does not call advanceToNextStage for normal timer ticks',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(_FakeRepo()),
            problemRepositoryProvider.overrideWithValue(_FakeProblemRepo()),
            sessionControllerProvider.overrideWith(
              _TrackingSessionController.new,
            ),
            stageTimerControllerProvider.overrideWith(
              _MutableTimerController.new,
            ),
            dictationControllerProvider.overrideWith(
              _FakeDictationController.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: InterviewScreen()),
          ),
        );
        await tester.pump();

        final tracking = container.read(sessionControllerProvider.notifier)
            as _TrackingSessionController;

        // State transitions that are NOT StageEnded must not trigger advance.
        container.read(stageTimerControllerProvider.notifier).pause();
        await tester.pump();

        expect(tracking.advanceCalled, 0);
      },
    );
  });
}
