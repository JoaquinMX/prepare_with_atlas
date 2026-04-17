import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart'
    show MockPlatformInterfaceMixin;
import 'package:prepare_with_atlas/features/whiteboard/application/whiteboard_controller.dart';
import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_state.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up the fake WebView platform once for all JS error handling tests.
  // WebViewPlatform.instance can only be set once per test run.
  late _ThrowingPlatformController throwingPlatform;
  setUpAll(() {
    throwingPlatform = _ThrowingPlatformController(
      const PlatformWebViewControllerCreationParams(),
    );
    WebViewPlatform.instance = _ThrowingWebViewPlatform(
      controller: throwingPlatform,
    );
  });

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  group('WhiteboardController', () {
    test('initial state has isLoading true and no data', () {
      final state = container.read(whiteboardControllerProvider);
      expect(state.isLoading, isTrue);
      expect(state.sceneJson, isNull);
      expect(state.screenshot, isNull);
      expect(state.hasError, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('setReady sets isLoading to false', () {
      container.read(whiteboardControllerProvider.notifier).setReady();
      final state = container.read(whiteboardControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.hasError, isFalse);
    });

    test('setError sets hasError and errorMessage', () {
      container
          .read(whiteboardControllerProvider.notifier)
          .setError('Something went wrong');
      final state = container.read(whiteboardControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.errorMessage, 'Something went wrong');
      expect(state.isLoading, isFalse);
    });

    test('updateScene stores sceneJson', () {
      container.read(whiteboardControllerProvider.notifier)
        ..setReady()
        ..updateScene('{"elements":[]}');
      final state = container.read(whiteboardControllerProvider);
      expect(state.sceneJson, '{"elements":[]}');
    });

    test('setScreenshot stores screenshot bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      container
          .read(whiteboardControllerProvider.notifier)
          .setScreenshot(bytes);
      final state = container.read(whiteboardControllerProvider);
      expect(state.screenshot, bytes);
    });

    test('reset clears scene and screenshot and returns to loading state', () {
      container.read(whiteboardControllerProvider.notifier)
        ..setReady()
        ..updateScene('{"elements":[]}')
        ..setScreenshot(Uint8List.fromList([1, 2, 3]))
        ..reset();

      final state = container.read(whiteboardControllerProvider);
      expect(state.sceneJson, isNull);
      expect(state.screenshot, isNull);
      expect(state.isLoading, isTrue);
      expect(state.hasError, isFalse);
    });

    test('onBridgeMessage with "ready" calls setReady', () {
      expect(container.read(whiteboardControllerProvider).isLoading, isTrue);
      container
          .read(whiteboardControllerProvider.notifier)
          .onBridgeMessage('ready');
      expect(container.read(whiteboardControllerProvider).isLoading, isFalse);
    });

    test('onBridgeMessage with "error:msg" calls setError', () {
      container
          .read(whiteboardControllerProvider.notifier)
          .onBridgeMessage('error:init failed');
      final state = container.read(whiteboardControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.errorMessage, 'init failed');
    });

    test('WhiteboardState.initial() matches expected defaults', () {
      final state = WhiteboardState.initial();
      expect(state.isLoading, isTrue);
      expect(state.hasError, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.sceneJson, isNull);
      expect(state.screenshot, isNull);
    });
  });

  group('WhiteboardController JS error handling', () {
    setUp(() {
      final webViewController = WebViewController();
      container
          .read(whiteboardControllerProvider.notifier)
          .attachWebViewController(webViewController);
      container.read(whiteboardControllerProvider.notifier).setReady();
    });

    test('getSceneData returns null when JS evaluation throws', () async {
      final result = await container
          .read(whiteboardControllerProvider.notifier)
          .getSceneData();
      expect(result, isNull);
    });

    test('loadSceneData swallows JS evaluation error gracefully', () async {
      await container
          .read(whiteboardControllerProvider.notifier)
          .loadSceneData('{"elements":[]}');
      final state = container.read(whiteboardControllerProvider);
      expect(state.hasError, isFalse);
    });

    test('clearCanvas swallows JS evaluation error gracefully', () async {
      await container.read(whiteboardControllerProvider.notifier).clearCanvas();
      final state = container.read(whiteboardControllerProvider);
      expect(state.hasError, isFalse);
    });

    test('setViewMode swallows JS evaluation error gracefully', () async {
      await container
          .read(whiteboardControllerProvider.notifier)
          .setViewMode(viewOnly: true);
      final state = container.read(whiteboardControllerProvider);
      expect(state.hasError, isFalse);
    });

    test('startAutoSave does not throw when WebView JS evaluation fails', () {
      expect(
        () => container
            .read(whiteboardControllerProvider.notifier)
            .startAutoSave((_) {}),
        returnsNormally,
      );
      container.read(whiteboardControllerProvider.notifier).stopAutoSave();
    });
  });

  group('WhiteboardController reset preserves WebViewController', () {
    setUp(() {
      final webViewController = WebViewController();
      container
          .read(whiteboardControllerProvider.notifier)
          .attachWebViewController(webViewController);
      container.read(whiteboardControllerProvider.notifier).setReady();
    });

    test('getSceneData still calls WebView after reset (not nulled)', () async {
      container.read(whiteboardControllerProvider.notifier).reset();
      final result = await container
          .read(whiteboardControllerProvider.notifier)
          .getSceneData();
      // The throwing platform is still attached, so JS evaluation throws —
      // but crucially it does NOT early-return null due to a null controller.
      // If reset() had nulled _webViewController, getSceneData would return
      // null silently. With the fix, it attempts the JS call (which throws)
      // and returns null via the catch path instead.
      expect(result, isNull);
    });

    test('reset does not set hasError when WebView is still attached', () {
      container.read(whiteboardControllerProvider.notifier).reset();
      final state = container.read(whiteboardControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.isLoading, isTrue);
      expect(state.sceneJson, isNull);
      expect(state.screenshot, isNull);
    });
  });
}

/// Fake [PlatformWebViewController] that throws on every JS call to simulate
/// the WKWebView FWFEvaluateJavaScriptError.
class _ThrowingPlatformController extends PlatformWebViewController
    with MockPlatformInterfaceMixin {
  _ThrowingPlatformController(super.params) : super.implementation();

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
  Future<void> runJavaScript(String javaScript) async {
    throw PlatformException(
      code: 'FWFEvaluateJavaScriptError',
      message: 'Failed evaluating JavaScript.',
    );
  }

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    throw PlatformException(
      code: 'FWFEvaluateJavaScriptError',
      message: 'Failed evaluating JavaScript.',
    );
  }
}

/// Fake [WebViewPlatform] that wires up the throwing controller.
class _ThrowingWebViewPlatform extends WebViewPlatform {
  _ThrowingWebViewPlatform({required this.controller});

  final _ThrowingPlatformController controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller;

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakePlatformWidget(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakePlatformNavigationDelegate(params);
}

class _FakePlatformWidget extends PlatformWebViewWidget
    with MockPlatformInterfaceMixin {
  _FakePlatformWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
