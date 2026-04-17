import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'whiteboard_state.freezed.dart';

/// Immutable UI state for the whiteboard panel.
@freezed
abstract class WhiteboardState with _$WhiteboardState {
  /// Creates a [WhiteboardState].
  const factory WhiteboardState({
    /// True while the WebView and Excalidraw are initialising.
    @Default(true) bool isLoading,

    /// True when an unrecoverable error occurred during initialisation.
    @Default(false) bool hasError,

    /// Human-readable error detail when [hasError] is true.
    String? errorMessage,

    /// JSON-encoded Excalidraw scene, or null when the canvas is empty.
    String? sceneJson,

    /// PNG screenshot bytes captured for AI evaluation.
    Uint8List? screenshot,
  }) = _WhiteboardState;

  /// Returns the default initial state (loading, no data).
  factory WhiteboardState.initial() => const WhiteboardState();
}
