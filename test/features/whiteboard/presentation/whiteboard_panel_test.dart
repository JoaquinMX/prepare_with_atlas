import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart'
    show MockPlatformInterfaceMixin;
import 'package:prepare_with_atlas/features/whiteboard/application/whiteboard_controller.dart';
import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_state.dart';
import 'package:prepare_with_atlas/features/whiteboard/presentation/whiteboard_panel.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlatformController fakePlatformController;
  late _FakePlatformWidget fakePlatformWidget;

  setUp(() {
    fakePlatformController = _FakePlatformController(
      const PlatformWebViewControllerCreationParams(),
    );
    fakePlatformWidget = _FakePlatformWidget(
      PlatformWebViewWidgetCreationParams(controller: fakePlatformController),
    );

    WebViewPlatform.instance = _FakeWebViewPlatform(
      controller: fakePlatformController,
      widget: fakePlatformWidget,
    );
  });

  Widget buildUnderTest(WhiteboardState presetState) {
    return ProviderScope(
      overrides: [
        whiteboardControllerProvider.overrideWith(
          () => _FakeWhiteboardController(presetState),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: WhiteboardPanel())),
    );
  }

  group('WhiteboardPanel', () {
    testWidgets('shows loading overlay when isLoading is true', (tester) async {
      await tester.pumpWidget(buildUnderTest(WhiteboardState.initial()));
      await tester.pump();
      expect(find.byKey(const Key('whiteboard_loading')), findsOneWidget);
      expect(find.byKey(const Key('whiteboard_error')), findsNothing);
    });

    testWidgets('shows error overlay when hasError is true', (tester) async {
      await tester.pumpWidget(
        buildUnderTest(
          const WhiteboardState(
            isLoading: false,
            hasError: true,
            errorMessage: 'CDN unreachable',
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('whiteboard_error')), findsOneWidget);
      expect(find.text('CDN unreachable'), findsOneWidget);
      expect(find.byKey(const Key('whiteboard_loading')), findsNothing);
    });

    testWidgets('shows WebView stack when ready (not loading, no error)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest(const WhiteboardState(isLoading: false)),
      );
      await tester.pump();
      expect(find.byKey(const Key('whiteboard_webview_stack')), findsOneWidget);
      expect(find.byKey(const Key('whiteboard_loading')), findsNothing);
      expect(find.byKey(const Key('whiteboard_error')), findsNothing);
    });

    testWidgets('clear button is present in toolbar when ready', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest(const WhiteboardState(isLoading: false)),
      );
      await tester.pump();
      expect(find.byKey(const Key('whiteboard_clear_btn')), findsOneWidget);
    });

    testWidgets('tapping clear button calls clearCanvas', (tester) async {
      final fakeController = _FakeWhiteboardController(
        const WhiteboardState(isLoading: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whiteboardControllerProvider.overrideWith(() => fakeController),
          ],
          child: const MaterialApp(home: Scaffold(body: WhiteboardPanel())),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('whiteboard_clear_btn')));
      await tester.pump();

      expect(fakeController.state.sceneJson, isNull);
    });

    testWidgets('view-only mode does not show clear toolbar button', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whiteboardControllerProvider.overrideWith(
              () => _FakeWhiteboardController(
                const WhiteboardState(isLoading: false),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: WhiteboardPanel(viewOnly: true)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('whiteboard_clear_btn')), findsNothing);
    });
  });
}

// ── Fakes ────────────────────────────────────────────────────────────────────

/// Fake [WhiteboardController] that exposes preset state without side effects.
class _FakeWhiteboardController extends WhiteboardController {
  _FakeWhiteboardController(this._preset);

  final WhiteboardState _preset;

  @override
  WhiteboardState build() => _preset;

  @override
  void attachWebViewController(_) {}

  @override
  void startAutoSave(_) {}

  @override
  void stopAutoSave() {}

  @override
  Future<void> clearCanvas() async {
    state = state.copyWith(sceneJson: null);
  }

  @override
  void reset() {
    // No-op in tests: the fake controller's state is set by the test and
    // should not be overridden by the post-frame reset in WhiteboardPanel.
  }
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

/// Fake [PlatformNavigationDelegate] that accepts all callbacks silently.
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
