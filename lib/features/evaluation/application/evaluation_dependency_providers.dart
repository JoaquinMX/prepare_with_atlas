import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_providers.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/evaluation/application/prompt_builder.dart';
import 'package:prepare_with_atlas/features/evaluation/application/response_parser.dart';
import 'package:prepare_with_atlas/features/evaluation/data/drift_evaluation_repository.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_repository.dart';
import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';

/// Fetches the latest evaluation result for a given session id.
///
/// Returns null when no evaluation has been saved for the session. When a
/// session has multiple evaluations (user re-evaluated with a different AI
/// provider), this returns the newest by `createdAt`.
final evaluationForSessionProvider =
    FutureProvider.autoDispose.family<EvaluationResult?, String>(
  (ref, sessionId) => ref.watch(evaluationRepositoryProvider).getBySessionId(
        sessionId,
      ),
);

/// Fetches all evaluations for a given session id, newest first.
///
/// Used by the session-detail UI to populate the multi-evaluation dropdown
/// (spec 07, EC-07.2). Refresh this provider with [Ref.invalidate] after a
/// re-evaluation completes so the dropdown picks up the new row.
final evaluationsForSessionProvider =
    FutureProvider.autoDispose.family<List<EvaluationResult>, String>(
  (ref, sessionId) =>
      ref.watch(evaluationRepositoryProvider).getAllBySessionId(sessionId),
);

/// Provides the active AI provider for evaluation.
///
/// Reads from [aiProviderControllerProvider] so that the active provider
/// configured in AI Settings is automatically picked up. Override in tests
/// to inject a mock.
final activeAiProviderForEvaluationProvider = Provider<AiProvider?>(
  (ref) => ref.watch(aiProviderControllerProvider).activeProvider,
);

/// Provides the [EvaluationRepository] implementation backed by Drift.
final evaluationRepositoryProvider = Provider<EvaluationRepository>(
  (ref) => DriftEvaluationRepository(ref.watch(appDatabaseProvider)),
);

/// Provides a singleton [PromptBuilder].
final promptBuilderProvider = Provider<PromptBuilder>(
  (_) => PromptBuilder(),
);

/// Provides a singleton [ResponseParser].
final responseParserProvider = Provider<ResponseParser>(
  (_) => ResponseParser(),
);
