import 'package:freezed_annotation/freezed_annotation.dart';

part 'dictation_state.freezed.dart';

/// All possible states of the in-app dictation feature.
///
/// The dictation controller transitions through these states:
/// - [DictationIdle]: Not listening; the default state.
/// - [DictationListening]: Actively listening; speech recogniser is running.
/// - [DictationStopped]: Stopped after listening (silence timeout, manual
///   stop, or error recovery).
/// - [DictationError]: An error occurred (e.g. permission denied).
@freezed
sealed class DictationState with _$DictationState {
  /// Not listening — the mic button shows the default icon.
  const factory DictationState.idle() = DictationIdle;

  /// Actively listening — the mic button shows accent colour + pulse.
  const factory DictationState.listening() = DictationListening;

  /// Stopped after listening — brief state before going idle.
  const factory DictationState.stopped() = DictationStopped;

  /// Error state — permission denied or speech recogniser failure.
  ///
  /// [message] is a human-readable description shown near the mic button.
  const factory DictationState.error({required String message}) =
      DictationError;
}
