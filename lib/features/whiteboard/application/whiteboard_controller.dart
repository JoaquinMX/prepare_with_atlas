import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_state.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Manages the whiteboard WebView state and JS bridge communication.
class WhiteboardController extends Notifier<WhiteboardState> {
  WebViewController? _webViewController;
  Timer? _autoSaveTimer;
  Completer<Uint8List?>? _screenshotCompleter;

  @override
  WhiteboardState build() => WhiteboardState.initial();

  // ── WebView attachment ────────────────────────────────────────────────────

  /// Attaches the [WebViewController] created by the presentation layer.
  // ignore: use_setters_to_change_properties
  void attachWebViewController(WebViewController controller) {
    _webViewController = controller;
  }

  // ── Bridge message handling ───────────────────────────────────────────────

  /// Handles a raw message string posted by the JS bridge.
  ///
  /// Recognised messages:
  /// - `"ready"` — Excalidraw mounted successfully.
  /// - `"error:<detail>"` — initialisation error.
  /// - `"png:<base64>"` — screenshot result from exportToPng.
  void onBridgeMessage(String message) {
    if (message == 'ready') {
      dev.log(
        'WhiteboardController: bridge message "ready"',
        name: 'WhiteboardController',
      );
      setReady();
    } else if (message.startsWith('scene-updated:')) {
      final count = message.substring('scene-updated:'.length);
      dev.log(
        'WhiteboardController: scene updated — $count element(s)',
        name: 'WhiteboardController',
      );
    } else if (message.startsWith('error:')) {
      dev.log(
        'WhiteboardController: bridge error — '
        '${message.substring('error:'.length)}',
        name: 'WhiteboardController',
      );
      setError(message.substring('error:'.length));
    } else if (message.startsWith('png:')) {
      final b64 = message.substring('png:'.length);
      try {
        final bytes = base64Decode(b64);
        setScreenshot(bytes);
        _screenshotCompleter?.complete(bytes);
      } on Object {
        // Ignore malformed png payloads.
        _screenshotCompleter?.complete(null);
      } finally {
        _screenshotCompleter = null;
      }
    }
  }

  // ── JS bridge calls ───────────────────────────────────────────────────────

  /// Retrieves the current Excalidraw scene as a JSON string.
  Future<String?> getSceneData() async {
    final ctrl = _webViewController;
    if (ctrl == null) return null;
    try {
      final result = await ctrl.runJavaScriptReturningResult(
        'window.getSceneData()',
      );
      final str = result.toString();
      if (str == 'null' || str.isEmpty) return null;
      // WKWebView wraps strings in quotes; strip them.
      if (str.startsWith('"') && str.endsWith('"')) {
        return str
            .substring(1, str.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', r'\');
      }
      return str;
    } on Object catch (e) {
      dev.log(
        'getSceneData: JS evaluation failed — $e',
        name: 'WhiteboardController',
      );
      return null;
    }
  }

  /// Loads a previously captured scene from its JSON representation.
  Future<void> loadSceneData(String json) async {
    final ctrl = _webViewController;
    if (ctrl == null) return;
    final escaped = json.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    try {
      await ctrl.runJavaScript("window.loadSceneData('$escaped')");
      updateScene(json);
    } on Object catch (e) {
      dev.log(
        'loadSceneData: JS evaluation failed — $e',
        name: 'WhiteboardController',
      );
    }
  }

  /// Triggers screenshot export via the JS bridge and awaits the result.
  ///
  /// Sends `exportToPng(1200)` to the WebView and waits for the bridge to
  /// respond with `"png:<base64>"` (handled in [onBridgeMessage]).
  /// Times out after 5 seconds and returns `null` if no response arrives.
  Future<Uint8List?> captureScreenshot() async {
    final ctrl = _webViewController;
    if (ctrl == null) return null;
    _screenshotCompleter?.complete(null); // cancel any in-flight request
    _screenshotCompleter = Completer<Uint8List?>();
    try {
      await ctrl.runJavaScript('window.exportToPng(1200)');
    } on Object {
      _screenshotCompleter?.complete(null);
      _screenshotCompleter = null;
      return null;
    }
    return _screenshotCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _screenshotCompleter = null;
        return null;
      },
    );
  }

  /// Shows the problem [title] and [description] in the HTML overlay banner.
  ///
  /// Only call this on a fresh canvas (no existing
  /// [WhiteboardState.sceneJson]).
  /// The banner is dismissible — the user can close it to get full canvas.
  Future<void> setProblemStatement(String title, String description) async {
    dev.log(
      'setProblemStatement: webViewController='
      '${_webViewController != null} '
      'title="${title.length > 40 ? '${title.substring(0, 40)}…' : title}"',
      name: 'WhiteboardController',
    );
    final ctrl = _webViewController;
    if (ctrl == null) return;
    final escapedTitle = title
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n');
    final escapedDesc = description
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n');
    try {
      await ctrl.runJavaScript(
        "window.setProblemStatement('$escapedTitle', '$escapedDesc')",
      );
      dev.log(
        'setProblemStatement: banner shown',
        name: 'WhiteboardController',
      );
    } on Object catch (e) {
      // WKWebView on macOS can throw FWFEvaluateJavaScriptError if the page
      // isn't ready yet or if the function is unavailable (e.g. stale cache).
      // The banner is non-critical — log and continue.
      dev.log(
        'setProblemStatement: JS call failed — $e',
        name: 'WhiteboardController',
      );
    }
  }

  /// Clears all elements from the Excalidraw canvas.
  Future<void> clearCanvas() async {
    final ctrl = _webViewController;
    if (ctrl == null) return;
    try {
      await ctrl.runJavaScript('window.clearCanvas()');
      state = state.copyWith(sceneJson: null);
    } on Object catch (e) {
      dev.log(
        'clearCanvas: JS evaluation failed — $e',
        name: 'WhiteboardController',
      );
    }
  }

  /// Enables or disables view-only mode on the canvas.
  Future<void> setViewMode({required bool viewOnly}) async {
    final ctrl = _webViewController;
    if (ctrl == null) return;
    try {
      await ctrl.runJavaScript('window.setViewMode($viewOnly)');
    } on Object catch (e) {
      dev.log(
        'setViewMode: JS evaluation failed — $e',
        name: 'WhiteboardController',
      );
    }
  }

  // ── Auto-save ─────────────────────────────────────────────────────────────

  /// Starts a 30-second auto-save timer.
  ///
  /// [onSave] is called with the current scene JSON (may be null) on each tick.
  void startAutoSave(void Function(String? json) onSave) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final json = await getSceneData();
        if (json != null) updateScene(json);
        onSave(json);
      } on Object catch (e) {
        dev.log(
          'startAutoSave: tick failed — $e',
          name: 'WhiteboardController',
        );
        // Intentionally swallow so the Timer.periodic keeps running.
      }
    });
  }

  /// Stops the auto-save timer.
  void stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  // ── State mutations ───────────────────────────────────────────────────────

  /// Marks the whiteboard as ready (WebView + Excalidraw fully loaded).
  void setReady() {
    state = state.copyWith(isLoading: false, hasError: false);
  }

  /// Records an error message and marks the whiteboard as errored.
  void setError(String message) {
    state = state.copyWith(
      isLoading: false,
      hasError: true,
      errorMessage: message,
    );
  }

  /// Updates the cached scene JSON in state.
  void updateScene(String json) {
    state = state.copyWith(sceneJson: json);
  }

  /// Stores PNG screenshot [bytes] in state.
  void setScreenshot(Uint8List bytes) {
    state = state.copyWith(screenshot: bytes);
  }

  /// Resets controller state back to initial loading and cancels any active
  /// auto-save timer.
  ///
  /// Called when a new [WhiteboardPanel] mounts so the singleton controller
  /// starts fresh rather than reusing state from a previous screen.
  ///
  /// Does NOT null [_webViewController] — the new panel's
  /// [attachWebViewController] call in [initState] replaces the old reference
  /// before [reset] runs in the post-frame callback. Nulling it here would
  /// wipe the freshly-attached controller and silently break all JS bridge
  /// calls ([getSceneData], [captureScreenshot], [loadSceneData], etc.).
  void reset() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    state = WhiteboardState.initial();
  }

  /// Cancels any active auto-save timer.
  void cancelTimers() {
    _autoSaveTimer?.cancel();
  }
}

/// Provides the singleton [WhiteboardController] instance.
final whiteboardControllerProvider =
    NotifierProvider<WhiteboardController, WhiteboardState>(
      WhiteboardController.new,
    );
