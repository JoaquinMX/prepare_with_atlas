import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart';
import 'package:prepare_with_atlas/features/whiteboard/data/drift_whiteboard_repository.dart';

void main() {
  late AppDatabase db;
  late DriftWhiteboardRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftWhiteboardRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftWhiteboardRepository', () {
    test('getLatestForSession returns null when no snapshot exists', () async {
      final result = await repo.getLatestForSession(999);
      expect(result, isNull);
    });

    test('saveSnapshot persists sceneJson for a sessionId', () async {
      await repo.saveSnapshot(
        sessionId: 1,
        sceneJson: '{"elements":[]}',
      );
      final snapshot = await repo.getLatestForSession(1);
      expect(snapshot, isNotNull);
      expect(snapshot!.sessionId, 1);
      expect(snapshot.sceneJson, '{"elements":[]}');
      expect(snapshot.screenshotPng, isNull);
    });

    test('saveSnapshot persists screenshotPng bytes', () async {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      await repo.saveSnapshot(
        sessionId: 2,
        sceneJson: '{"elements":[{"id":"a"}]}',
        screenshotPng: bytes,
      );
      final snapshot = await repo.getLatestForSession(2);
      expect(snapshot, isNotNull);
      expect(snapshot!.screenshotPng, bytes);
    });

    test('getLatestForSession returns most recent when multiple saved',
        () async {
      await repo.saveSnapshot(sessionId: 3, sceneJson: '{"version":1}');
      await repo.saveSnapshot(sessionId: 3, sceneJson: '{"version":2}');
      final snapshot = await repo.getLatestForSession(3);
      expect(snapshot!.sceneJson, '{"version":2}');
    });

    test('snapshots for different sessions are isolated', () async {
      await repo.saveSnapshot(sessionId: 10, sceneJson: '{"session":10}');
      await repo.saveSnapshot(sessionId: 20, sceneJson: '{"session":20}');

      final s10 = await repo.getLatestForSession(10);
      final s20 = await repo.getLatestForSession(20);

      expect(s10!.sceneJson, '{"session":10}');
      expect(s20!.sceneJson, '{"session":20}');
    });
  });
}
