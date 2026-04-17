import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/whiteboard/data/drift_whiteboard_repository.dart';
import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_repository.dart';
import 'package:prepare_with_atlas/features/whiteboard/domain/whiteboard_snapshot.dart';

/// Provides the [WhiteboardRepository] implementation.
final whiteboardRepositoryProvider = Provider<WhiteboardRepository>(
  (ref) => DriftWhiteboardRepository(ref.watch(appDatabaseProvider)),
);

/// Fetches the most recent [WhiteboardSnapshot] for a given session id.
///
/// Returns null when no snapshot has been saved for the session.
final whiteboardSnapshotProvider = FutureProvider.autoDispose
    .family<WhiteboardSnapshot?, int>((ref, sessionId) async {
  final repo = ref.watch(whiteboardRepositoryProvider);
  return repo.getLatestForSession(sessionId);
});
