import 'dart:typed_data';

import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_snapshot.dart';

/// Port for persisting and retrieving whiteboard snapshots.
abstract class WhiteboardRepository {
  /// Saves a snapshot of the current scene for [sessionId].
  Future<void> saveSnapshot({
    required int sessionId,
    required String sceneJson,
    Uint8List? screenshotPng,
  });

  /// Returns the most recent snapshot for [sessionId], or null if none exist.
  Future<WhiteboardSnapshot?> getLatestForSession(int sessionId);
}
