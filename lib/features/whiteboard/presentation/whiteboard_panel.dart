import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/problem_bank/application/problem_repository_provider.dart';
import 'package:prepare_with_atlas/features/whiteboard/application/whiteboard_controller.dart';
import 'package:prepare_with_atlas/features/whiteboard/data/whiteboard_providers.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Full-screen Excalidraw whiteboard with auto-save wired to the
/// whiteboard repository.
///
/// Shows a loading overlay while Excalidraw initialises, an error overlay on
/// failure, and the live WebView once ready.
class WhiteboardPanel extends ConsumerStatefulWidget {
  /// Creates a [WhiteboardPanel].
  ///
  /// When [viewOnly] is true, auto-save and problem-statement injection are
  /// skipped and the clear-toolbar is hidden. This is used for the History
  /// read-only view.
  ///
  /// [onReady] is invoked once when the JS bridge posts "ready", after the
  /// controller has been marked as loaded. Use this to restore a previously
  /// saved scene in view-only mode — it avoids the race condition where a
  /// `ref.listen` on the controller's `isLoading` field may miss the
  /// transition.
  const WhiteboardPanel({this.viewOnly = false, this.onReady, super.key});

  /// Whether the whiteboard is rendered in read-only (history review) mode.
  final bool viewOnly;

  /// Optional callback invoked once when the WebView is ready.
  final VoidCallback? onReady;

  @override
  ConsumerState<WhiteboardPanel> createState() => _WhiteboardPanelState();
}

class _WhiteboardPanelState extends ConsumerState<WhiteboardPanel> {
  late final WebViewController _controller;
  late final WhiteboardController _notifier;

  @override
  void initState() {
    super.initState();

    _notifier = ref.read(whiteboardControllerProvider.notifier);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) {
          _notifier.onBridgeMessage(msg.message);
          if (msg.message == 'ready') {
            if (!widget.viewOnly) {
              _startAutoSave();
              _injectProblemIfFresh();
            }
            widget.onReady?.call();
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {}))
      ..loadFlutterAsset('assets/excalidraw/index.html');

    // Reset the singleton controller back to loading state so the fresh
    // WebView goes through the proper loading → ready lifecycle.  Deferred
    // to after the current build to avoid modifying a provider during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifier.reset();
      }
    });
    _notifier.attachWebViewController(_controller);
  }

  /// Injects the current session's problem statement into a fresh canvas.
  ///
  /// Called directly from the "ready" bridge message so it fires regardless
  /// of whether isLoading transitions are observed upstream.
  Future<void> _injectProblemIfFresh() async {
    dev.log('_injectProblemIfFresh called', name: 'WhiteboardPanel');
    final wbState = ref.read(whiteboardControllerProvider);
    if (wbState.sceneJson != null) {
      dev.log(
        '_injectProblemIfFresh: scene already has data — skipping',
        name: 'WhiteboardPanel',
      );
      return;
    }

    final sessionState = ref.read(sessionControllerProvider);
    final problemId = sessionState.currentSession?.problemId;
    dev.log(
      '_injectProblemIfFresh: problemId=$problemId',
      name: 'WhiteboardPanel',
    );
    if (problemId == null) return;

    final problem = await ref
        .read(problemRepositoryProvider)
        .getById(problemId);
    dev.log(
      '_injectProblemIfFresh: problem="${problem?.title}"',
      name: 'WhiteboardPanel',
    );
    if (problem == null) return;

    await _notifier.setProblemStatement(problem.title, problem.description);
  }

  void _startAutoSave() {
    final sessionId = ref.read(sessionControllerProvider).currentSession?.id;
    if (sessionId == null) return;

    // Capture the repository instance now so the timer closure does not
    // call ref.read() after the widget is unmounted (e.g. on navigation to
    // the evaluation screen).
    final repository = ref.read(whiteboardRepositoryProvider);

    _notifier.startAutoSave((json) async {
      if (json == null) return;
      await repository.saveSnapshot(sessionId: sessionId, sceneJson: json);
    });
  }

  @override
  void dispose() {
    _notifier.stopAutoSave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whiteboardControllerProvider);

    if (state.isLoading) {
      return const _LoadingOverlay(key: Key('whiteboard_loading'));
    }

    if (state.hasError) {
      return _ErrorOverlay(
        key: const Key('whiteboard_error'),
        message: state.errorMessage ?? 'Unknown error',
      );
    }

    return Stack(
      key: const Key('whiteboard_webview_stack'),
      children: [
        WebViewWidget(controller: _controller),
        if (!widget.viewOnly)
          Positioned(
            top: 8,
            right: 8,
            child: _WhiteboardToolbar(onClear: () => _notifier.clearCanvas()),
          ),
      ],
    );
  }
}

/// Loading state shown while Excalidraw initialises.
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AtlasColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AtlasColors.accent),
            SizedBox(height: 16),
            Text(
              'Loading Whiteboard…',
              style: TextStyle(color: AtlasColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state shown when Excalidraw fails to initialise.
class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, super.key});

  /// Human-readable error detail to display to the user.
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AtlasColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AtlasColors.danger,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Whiteboard failed to load',
                style: TextStyle(
                  color: AtlasColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: AtlasColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small floating toolbar for whiteboard actions.
class _WhiteboardToolbar extends StatelessWidget {
  const _WhiteboardToolbar({required this.onClear});

  /// Called when the user requests to clear the canvas.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AtlasColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AtlasColors.border),
      ),
      child: IconButton(
        key: const Key('whiteboard_clear_btn'),
        icon: const Icon(
          Icons.delete_sweep_outlined,
          color: AtlasColors.textSecondary,
        ),
        tooltip: 'Clear canvas',
        onPressed: onClear,
      ),
    );
  }
}
