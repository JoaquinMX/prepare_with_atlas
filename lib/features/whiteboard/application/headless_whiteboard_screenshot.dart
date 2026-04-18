import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Captures a PNG screenshot of an Excalidraw [sceneJson] without requiring a
/// visible [WhiteboardPanel] to be mounted.
///
/// The helper inserts a 1×1, fully transparent WebView into the root
/// [Overlay] just long enough to:
/// 1. Load `assets/excalidraw/index.html`.
/// 2. Inject the persisted scene via `window.loadSceneData(...)`.
/// 3. Trigger `window.exportToPng(...)` and await the `png:<base64>` message
///    from the `FlutterBridge` channel.
///
/// Returns the decoded PNG bytes, or `null` if the capture times out or the
/// bridge posts an error. The overlay is always removed before the future
/// resolves.
///
/// Uses `rootOverlay: true` so the capture survives the calling screen being
/// popped off the navigator — re-evaluation from Session Detail must remain
/// non-blocking (spec 07, US-07.8).
class HeadlessWhiteboardScreenshot {
  HeadlessWhiteboardScreenshot._();

  /// Captures a screenshot of [sceneJson]. Caller must supply an
  /// [OverlayState] (typically the root one: `Overlay.of(context,
  /// rootOverlay: true)`) — resolving it here from a context is brittle
  /// because the context that owns the overlay cannot be used to look itself
  /// up. Capturing the [OverlayState] at the call site before any `await`
  /// also sidesteps "widget unmounted" issues when the originating button
  /// rebuilds.
  static Future<Uint8List?> capture({
    required OverlayState overlay,
    required String sceneJson,
    Duration timeout = const Duration(seconds: 20),
    double maxWidth = 1200,
  }) async {
    final completer = Completer<Uint8List?>();
    late final OverlayEntry entry;

    void complete(Uint8List? bytes) {
      if (!completer.isCompleted) completer.complete(bytes);
    }

    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Opacity(
          opacity: 0,
          child: SizedBox(
            width: 1,
            height: 1,
            child: _HeadlessCaptureWebView(
              sceneJson: sceneJson,
              maxWidth: maxWidth,
              onResult: complete,
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);

    Uint8List? result;
    try {
      result = await completer.future.timeout(
        timeout,
        onTimeout: () {
          dev.log(
            'capture: timed out after ${timeout.inSeconds}s',
            name: 'HeadlessWhiteboardScreenshot',
            level: 900,
          );
          return null;
        },
      );
    } finally {
      entry.remove();
    }
    return result;
  }
}

class _HeadlessCaptureWebView extends StatefulWidget {
  const _HeadlessCaptureWebView({
    required this.sceneJson,
    required this.maxWidth,
    required this.onResult,
  });

  final String sceneJson;
  final double maxWidth;
  final void Function(Uint8List? bytes) onResult;

  @override
  State<_HeadlessCaptureWebView> createState() =>
      _HeadlessCaptureWebViewState();
}

class _HeadlessCaptureWebViewState extends State<_HeadlessCaptureWebView> {
  late final WebViewController _controller;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) => _onBridgeMessage(msg.message),
      )
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {}))
      ..loadFlutterAsset('assets/excalidraw/index.html');
  }

  Future<void> _onBridgeMessage(String message) async {
    if (_resolved) return;
    if (message == 'ready') {
      try {
        final escaped = widget.sceneJson
            .replaceAll(r'\', r'\\')
            .replaceAll("'", r"\'");
        await _controller.runJavaScript(
          "window.loadSceneData('$escaped')",
        );
        // Give Excalidraw a frame to render before exporting.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _controller.runJavaScript(
          'window.exportToPng(${widget.maxWidth.toInt()})',
        );
      } on Object catch (e) {
        dev.log(
          '_onBridgeMessage: JS call failed — $e',
          name: 'HeadlessWhiteboardScreenshot',
          level: 1000,
        );
        _resolve(null);
      }
    } else if (message.startsWith('png:')) {
      try {
        final bytes = base64Decode(message.substring('png:'.length));
        _resolve(bytes);
      } on Object {
        _resolve(null);
      }
    } else if (message.startsWith('error:')) {
      dev.log(
        '_onBridgeMessage: bridge error — '
        '${message.substring('error:'.length)}',
        name: 'HeadlessWhiteboardScreenshot',
        level: 900,
      );
      _resolve(null);
    }
  }

  void _resolve(Uint8List? bytes) {
    if (_resolved) return;
    _resolved = true;
    widget.onResult(bytes);
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
