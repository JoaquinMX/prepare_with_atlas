import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/interview_session/application/dictation_state.dart';
import 'package:speech_to_text/speech_to_text.dart'
    show ListenMode, SpeechListenOptions, SpeechToText;

/// Manages in-app speech-to-text dictation during interviews.
///
/// Wraps [SpeechToText] and exposes a simple state machine:
/// [DictationIdle] -> [DictationListening] -> [DictationStopped],
/// with [DictationError] for failures such as permission denial.
///
/// Recognised words are emitted via [onResult] so the presentation layer
/// can insert them into the notes text field at the cursor position.
///
/// ## Keep-listening behaviour
///
/// Once the user taps the mic to activate dictation, the microphone stays
/// open until the user taps the mic again, the session ends, or the stage
/// transitions. Platform-level silence timeouts (`pauseFor`) and total-
/// duration limits (`listenFor`) automatically restart a fresh listen
/// session so the user never has to re-tap after a pause.
///
/// [stopListening], [cancelListening], and [reset] are the only paths that
/// actually close the microphone.
class DictationController extends Notifier<DictationState> {
  final SpeechToText _speech = SpeechToText();

  /// `true` while the user wants dictation to remain active.
  ///
  /// Set to `true` by [startListening]; cleared by [stopListening],
  /// [cancelListening], and [reset]. When `true`, `_onStopped` restarts
  /// a fresh listen session instead of transitioning to [DictationStopped].
  bool _keepListening = false;

  /// Callback invoked when new recognised text arrives.
  ///
  /// `text` is the recognised words. `isFinal` is true when the recogniser
  /// has finished a phrase; partial results have `isFinal` = false.
  void Function(String text, {required bool isFinal})? onResult;

  @override
  DictationState build() {
    ref.onDispose(() {
      if (_speech.isListening) {
        _speech.cancel();
      }
    });
    return const DictationState.idle();
  }

  /// Initialises the speech recogniser if it hasn't been initialised yet.
  ///
  /// Returns `true` if the recogniser is ready to listen, `false` if
  /// initialisation failed (e.g. permission denied).
  Future<bool> _ensureInitialised() async {
    if (_speech.isAvailable) return true;

    try {
      final available = await _speech.initialize(
        onError: (error) {
          dev.log(
            'DictationController: speech error — '
            '${error.errorMsg} (permanent: ${error.permanent})',
            name: 'DictationController',
          );
          if (error.permanent) {
            state = DictationState.error(
              message: _humanReadableError(error.errorMsg),
            );
          }
        },
        onStatus: (status) {
          dev.log(
            'DictationController: speech status — $status',
            name: 'DictationController',
          );
          if (status == 'notListening' || status == 'done') {
            _onStopped();
          }
        },
      );

      if (!available) {
        state = const DictationState.error(
          message:
              'Microphone access is needed for dictation. '
              'Enable it in System Settings → Privacy & Security '
              '→ Microphone.',
        );
        return false;
      }
      return true;
    } on Object catch (e) {
      dev.log(
        'DictationController: initialisation failed — $e',
        name: 'DictationController',
      );
      state = DictationError(message: 'Could not start dictation: $e');
      return false;
    }
  }

  /// Starts listening for speech input.
  ///
  /// If the recogniser is not yet initialised, initialises it first (which
  /// may prompt for microphone permission). Transitions to
  /// [DictationListening] on success, or [DictationError] on failure.
  ///
  /// Sets [_keepListening] so that platform-triggered stops (silence timeout,
  /// duration limit) automatically restart the session rather than closing
  /// the microphone.
  Future<void> startListening() async {
    if (state is DictationListening) return;

    _keepListening = true;

    final ready = await _ensureInitialised();
    if (!ready) {
      _keepListening = false;
      return;
    }

    state = const DictationState.listening();
    await _startSpeechSession();
  }

  /// Launches a single [SpeechToText.listen] session.
  ///
  /// Called by [startListening] on first activation and by [_onStopped]
  /// whenever the session restarts due to a platform silence/duration event
  /// while [_keepListening] is `true`.
  Future<void> _startSpeechSession() async {
    try {
      await _speech.listen(
        onResult: (result) {
          onResult?.call(result.recognizedWords, isFinal: result.finalResult);
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
    } on Object catch (e) {
      dev.log(
        'DictationController: listen() failed — $e',
        name: 'DictationController',
      );
      _keepListening = false;
      state = DictationError(message: 'Could not start dictation: $e');
    }
  }

  /// Stops listening and transitions to [DictationStopped].
  ///
  /// Use [stopListening] (not [cancelListening]) when the user explicitly
  /// taps the mic button so that a final result is delivered.
  /// Clears [_keepListening] so no auto-restart occurs.
  Future<void> stopListening() async {
    if (state is! DictationListening) return;
    _keepListening = false;
    await _speech.stop();
    _onStopped();
  }

  /// Cancels the current listening session without delivering a final
  /// result. Used internally during session transitions to ensure clean
  /// shutdown. Clears [_keepListening] so no auto-restart occurs.
  Future<void> cancelListening() async {
    _keepListening = false;
    await _speech.cancel();
    state = const DictationState.idle();
  }

  /// Toggles between listening and idle/stopped.
  Future<void> toggleListening() async {
    if (state is DictationListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// Resets the controller to idle. Used when transitioning to a new
  /// stage or ending a session. Clears [_keepListening] so no auto-restart
  /// occurs.
  Future<void> reset() async {
    _keepListening = false;
    await _speech.cancel();
    state = const DictationState.idle();
  }

  /// Called when the speech recogniser stops (either manually or on a
  /// platform silence/duration event).
  ///
  /// If [_keepListening] is `true` (user has not explicitly stopped), a
  /// new listen session is started immediately so the microphone stays
  /// open. Otherwise transitions to [DictationStopped].
  void _onStopped() {
    if (state is! DictationListening) return;
    if (_keepListening) {
      // Platform auto-stop (silence/duration) — restart transparently.
      unawaited(_startSpeechSession());
    } else {
      state = const DictationState.stopped();
    }
  }

  /// Returns a human-readable error message for common speech recogniser
  /// error codes.
  String _humanReadableError(String errorMsg) {
    final lower = errorMsg.toLowerCase();
    if (lower.contains('permission') ||
        lower.contains('denied') ||
        lower.contains('not permitted')) {
      return 'Microphone access is needed for dictation. '
          'Enable it in System Settings → Privacy & Security → Microphone.';
    }
    if (lower.contains('network')) {
      return 'Dictation requires network access for speech recognition.';
    }
    if (lower.contains('retry')) {
      return 'Speech recognition failed. Please try again.';
    }
    return 'Dictation encountered an error. Please try again.';
  }
}

/// Provides the singleton [DictationController] for the interview session.
final dictationControllerProvider =
    NotifierProvider<DictationController, DictationState>(
      DictationController.new,
    );
