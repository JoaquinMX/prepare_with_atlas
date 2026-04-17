import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';

part 'ai_provider_state.freezed.dart';

/// State for the AI provider controller.
@freezed
abstract class AiProviderState with _$AiProviderState {
  /// Creates an [AiProviderState].
  const factory AiProviderState({
    /// The currently active provider instance, or `null` if none configured.
    @Default(null) AiProvider? activeProvider,

    /// The currently active config, or `null` if none configured.
    @Default(null) AiProviderConfig? activeConfig,

    /// Whether a connection test is currently in progress.
    @Default(false) bool isTesting,

    /// Human-readable result message from the last connection test.
    @Default(null) String? testResultMessage,

    /// Whether the last connection test succeeded; `null` if not tested yet.
    @Default(null) bool? testSuccess,

    /// Whether the controller is loading (initialising or saving).
    @Default(false) bool isLoading,

    /// An error message if the last operation failed.
    @Default(null) String? errorMessage,
  }) = _AiProviderState;
}
