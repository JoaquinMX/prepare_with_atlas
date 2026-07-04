import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prepare_with_atlas/features/recording/application/audio_recorder_state.dart';
import 'package:record/record.dart';

/// Provider for the audio recorder.
final audioRecorderProvider =
    NotifierProvider<AudioRecorderController, AudioRecorderState>(
  AudioRecorderController.new,
);

/// Controller for audio recording using FLAC format.
///
/// Uses the `record` package to capture audio during interview sessions.
class AudioRecorderController extends Notifier<AudioRecorderState> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  AudioRecorderState build() {
    ref.onDispose(() {
      _elapsedTimer?.cancel();
      _recorder.dispose();
    });
    return const AudioRecorderState.idle();
  }

  /// Starts recording audio for the given session and stage.
  Future<void> startRecording({
    required int sessionId,
    required int stageIndex,
  }) async {
    if (state.isRecording) {
      dev.log(
        'startRecording called but already recording',
        name: 'AudioRecorderController',
      );
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      state = const AudioRecorderState.error(
        message: 'Microphone permission denied.',
      );
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${dir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath =
        '${recordingsDir.path}/session_${sessionId}_stage${stageIndex}_$timestamp.flac';

    try {
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.flac,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: filePath,
      );

      _elapsed = Duration.zero;
      _elapsedTimer?.cancel();
      _elapsedTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (state.isRecording) {
            _elapsed += const Duration(seconds: 1);
            state = AudioRecorderState.recording(
              sessionId: sessionId,
              stageIndex: stageIndex,
              filePath: filePath,
              elapsed: _elapsed,
            );
          }
        },
      );

      state = AudioRecorderState.recording(
        sessionId: sessionId,
        stageIndex: stageIndex,
        filePath: filePath,
        elapsed: Duration.zero,
      );

      dev.log(
        'Started recording: $filePath',
        name: 'AudioRecorderController',
      );
    } on Exception catch (e) {
      state = AudioRecorderState.error(message: e.toString());
    }
  }

  /// Stops the current recording and returns the file path.
  Future<String?> stopRecording() async {
    if (!state.isRecording) return null;

    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    try {
      final path = await _recorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          state = AudioRecorderState.stopped(
            filePath: path,
            duration: _elapsed,
          );
          dev.log(
            'Stopped recording: $path (${_elapsed.inSeconds}s)',
            name: 'AudioRecorderController',
          );
          return path;
        }
      }
      state = const AudioRecorderState.idle();
      return null;
    } on Exception catch (e) {
      state = AudioRecorderState.error(message: e.toString());
      return null;
    }
  }

  /// Cancels the current recording without saving.
  Future<void> cancelRecording() async {
    if (!state.isRecording) return;

    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    try {
      await _recorder.cancel();
      state = const AudioRecorderState.idle();
    } on Exception catch (e) {
      state = AudioRecorderState.error(message: e.toString());
    }
  }

  /// Returns the current recording file path if recording.
  String? get currentFilePath =>
      state.isRecording ? (state as AudioRecorderRecording).filePath : null;
}
