import 'package:drift/drift.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart' as db;
import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_repository.dart';
import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_snapshot.dart';

/// Drift-backed implementation of [WhiteboardRepository].
class DriftWhiteboardRepository implements WhiteboardRepository {
  /// Creates a [DriftWhiteboardRepository] backed by [_db].
  DriftWhiteboardRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<void> saveSnapshot({
    required int sessionId,
    required String sceneJson,
    Uint8List? screenshotPng,
  }) async {
    await _db.into(_db.whiteboardSnapshots).insert(
          db.WhiteboardSnapshotsCompanion(
            sessionId: Value(sessionId),
            sceneJson: Value(sceneJson),
            screenshotPng: Value(screenshotPng),
            capturedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<WhiteboardSnapshot?> getLatestForSession(int sessionId) async {
    final row = await (_db.select(_db.whiteboardSnapshots)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return WhiteboardSnapshot(
      id: row.id,
      sessionId: row.sessionId,
      sceneJson: row.sceneJson,
      screenshotPng: row.screenshotPng,
      capturedAt: row.capturedAt,
    );
  }
}
