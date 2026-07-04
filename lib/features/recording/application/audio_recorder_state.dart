import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_recorder_state.freezed.dart';

/// The current recording mode for an interview session.
enum RecordingMode {
  /// Voice recording to FLAC file, with real-time STT display.
  voiceRecording,

  /// Real-time STT transcription to notes (existing behavior).
  speechToText,

  /// Manual note-taking only, no audio capture.
  notesOnly,
}

/// State machine for audio recording.
@freezed
sealed class AudioRecorderState with _$AudioRecorderState {
  const factory AudioRecorderState.idle() = AudioRecorderIdle;

  const factory AudioRecorderState.recording({
    required int sessionId,
    required int stageIndex,
    required String filePath,
    required Duration elapsed,
  }) = AudioRecorderRecording;

  const factory AudioRecorderState.stopped({
    required String filePath,
    required Duration duration,
  }) = AudioRecorderStopped;

  const factory AudioRecorderState.error({
    required String message,
  }) = AudioRecorderError;
}

/// Extension to check if recording is active.
extension AudioRecorderStateX on AudioRecorderState {
  bool get isRecording => this is AudioRecorderRecording;
}
