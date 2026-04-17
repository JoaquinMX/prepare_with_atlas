import 'dart:typed_data';

/// A point-in-time snapshot of the Excalidraw whiteboard for a session.
class WhiteboardSnapshot {
  /// Creates a [WhiteboardSnapshot].
  const WhiteboardSnapshot({
    required this.id,
    required this.sessionId,
    required this.sceneJson,
    required this.capturedAt,
    this.screenshotPng,
  });

  /// Database row identifier (0 for unsaved snapshots).
  final int id;

  /// The interview session this snapshot belongs to.
  final int sessionId;

  /// JSON-encoded Excalidraw scene data.
  final String sceneJson;

  /// Optional PNG screenshot bytes.
  final Uint8List? screenshotPng;

  /// When this snapshot was recorded.
  final DateTime capturedAt;
}
