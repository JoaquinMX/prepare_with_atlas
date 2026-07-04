import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/interview_session/application/dictation_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/dictation_state.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/recording/application/audio_recorder_controller.dart';
import 'package:prepare_with_atlas/features/recording/application/audio_recorder_state.dart';

/// A panel for free-form notes during an interview stage.
///
/// Shows a label and an expanded multi-line text field with an in-app
/// dictation mic button. Dictation works regardless of which panel
/// (notes or whiteboard) has focus, because it uses the native macOS
/// speech recogniser at the Flutter layer.
class StageNotesPanel extends ConsumerStatefulWidget {
  /// Creates a [StageNotesPanel].
  const StageNotesPanel({super.key});

  @override
  ConsumerState<StageNotesPanel> createState() => _StageNotesPanelState();
}

class _StageNotesPanelState extends ConsumerState<StageNotesPanel> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// Tracks the last position where dictated text was inserted so that
  /// partial results can replace the previous partial at the same spot.
  int _dictationInsertOffset = -1;
  int _dictationReplaceLength = 0;

  @override
  void initState() {
    super.initState();
    ref.read(dictationControllerProvider.notifier).onResult =
        _onDictationResult;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Appends recognised dictation text at the current cursor position.
  ///
  /// Partial results replace the previous partial at the same insertion
  /// point so the user sees text "flowing" rather than duplicating.
  void _onDictationResult(String text, {required bool isFinal}) {
    if (text.isEmpty) return;

    // If we have a pending partial result, replace it; otherwise append at
    // the end of the existing text.
    if (_dictationInsertOffset >= 0 && _dictationReplaceLength > 0) {
      final currentText = _controller.text;
      final end = _dictationInsertOffset + _dictationReplaceLength;
      if (end <= currentText.length) {
        _controller.text =
            currentText.substring(0, _dictationInsertOffset) +
            text +
            currentText.substring(end);
      } else {
        _controller.text = '$currentText $text';
        _dictationInsertOffset = currentText.length + 1;
      }
    } else {
      final currentText = _controller.text;
      // Append with a space separator if there's existing text.
      final separator = currentText.isNotEmpty ? ' ' : '';
      _controller.text = currentText + separator + text;
      _dictationInsertOffset = currentText.length + separator.length;
    }

    if (isFinal) {
      _dictationReplaceLength = text.length;
    } else {
      _dictationReplaceLength = text.length;
    }

    // Move cursor to end of inserted text.
    final newOffset = _dictationInsertOffset + text.length;
    _controller.selection = TextSelection.collapsed(
      offset: newOffset.clamp(0, _controller.text.length),
    );

    // Persist the updated text.
    ref.read(sessionControllerProvider.notifier).updateNotes(_controller.text);

    if (isFinal) {
      // Reset insertion tracking after a final result so the next
      // dictated phrase starts fresh.
      _dictationInsertOffset = -1;
      _dictationReplaceLength = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dictationState = ref.watch(dictationControllerProvider);
    final isListening = dictationState is DictationListening;
    final errorMessage = switch (dictationState) {
      DictationError(:final message) => message,
      _ => null,
    };
    final sessionState = ref.watch(sessionControllerProvider);
    final recordingMode = sessionState.recordingMode;
    final isVoiceRecording = recordingMode == RecordingMode.voiceRecording;
    final recorderState = ref.watch(audioRecorderProvider);
    final isRecording = recorderState is AudioRecorderRecording;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Text(
                'STAGE NOTES',
                style: TextStyle(
                  color: AtlasColors.textMuted,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _ModeIndicator(mode: recordingMode, isRecording: isRecording),
              const Spacer(),
              if (errorMessage != null)
                Tooltip(
                  message: errorMessage,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.mic_off_outlined,
                        size: 13,
                        color: AtlasColors.danger,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Mic unavailable',
                        style: TextStyle(
                          color: AtlasColors.danger,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              else if (recordingMode == RecordingMode.notesOnly)
                const SizedBox.shrink()
              else
                Tooltip(
                  message: isListening
                      ? 'Listening… tap to stop'
                      : 'Tap mic to dictate notes',
                  child: _MicButton(
                    isListening: isListening,
                    onPressed: () {
                      ref
                          .read(dictationControllerProvider.notifier)
                          .toggleListening();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Type or dictate your notes here…',
                hintStyle: TextStyle(color: AtlasColors.textMuted),
              ),
              style: const TextStyle(
                color: AtlasColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
              onChanged: (text) {
                ref.read(sessionControllerProvider.notifier).updateNotes(text);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// A mic toggle button that shows a recording pulse when dictation is active.
class _MicButton extends StatelessWidget {
  const _MicButton({required this.isListening, required this.onPressed});

  final bool isListening;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isListening) {
      return _RecordingPulse(onPressed: onPressed);
    }
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(
        Icons.mic_outlined,
        size: 18,
        color: AtlasColors.textMuted,
      ),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}

/// A pulsing mic icon that signals the recogniser is actively listening.
class _RecordingPulse extends StatefulWidget {
  const _RecordingPulse({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<_RecordingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AtlasColors.accent.withValues(
              alpha: 0.15 + _animation.value * 0.2,
            ),
          ),
          child: child,
        );
      },
      child: IconButton(
        onPressed: widget.onPressed,
        icon: Icon(
          Icons.mic,
          size: 18,
          color: AtlasColors.accent.withValues(
            alpha: 0.7 + _animation.value * 0.3,
          ),
        ),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// Shows a small badge indicating the current recording mode.
class _ModeIndicator extends StatelessWidget {
  const _ModeIndicator({required this.mode, required this.isRecording});

  final RecordingMode mode;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRecording) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AtlasColors.danger,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Icon(
          _icon(mode),
          size: 12,
          color: AtlasColors.textMuted,
        ),
        const SizedBox(width: 3),
        Text(
          _label(mode),
          style: const TextStyle(
            color: AtlasColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  IconData _icon(RecordingMode m) => switch (m) {
        RecordingMode.voiceRecording => Icons.mic,
        RecordingMode.speechToText => Icons.record_voice_over_outlined,
        RecordingMode.notesOnly => Icons.note_outlined,
      };

  String _label(RecordingMode m) => switch (m) {
        RecordingMode.voiceRecording => 'REC',
        RecordingMode.speechToText => 'STT',
        RecordingMode.notesOnly => 'Notes',
      };
}
