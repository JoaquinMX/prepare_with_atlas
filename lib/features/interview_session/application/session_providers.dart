import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/providers/app_database_provider.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_state.dart';
import 'package:prepare_with_atlas/features/interview_session/application/stage_timer_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/timer_state.dart';
import 'package:prepare_with_atlas/features/interview_session/data/drift_session_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/session_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';

export 'package:prepare_with_atlas/core/providers/app_database_provider.dart'
    show appDatabaseProvider;

/// Provides the [SessionRepository] implementation.
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => DriftSessionRepository(ref.watch(appDatabaseProvider)),
);

/// Manages the stage countdown timer.
final stageTimerControllerProvider =
    NotifierProvider<StageTimerController, TimerState>(
  StageTimerController.new,
);

/// Manages the overall interview session state.
final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Fetches all stage notes for a completed session by session id.
final stageNotesForSessionProvider =
    FutureProvider.autoDispose.family<List<StageNote>, int>(
  (ref, sessionId) =>
      ref.watch(sessionRepositoryProvider).getStageNotes(sessionId),
);
