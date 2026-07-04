import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_config.dart';
import 'package:prepare_with_atlas/features/recording/application/audio_recorder_state.dart';

/// Screen for configuring and starting an interview session.
///
/// Route: `/session-setup?problemId=<id>`
class SessionSetupScreen extends ConsumerStatefulWidget {
  /// Creates a [SessionSetupScreen].
  const SessionSetupScreen({required this.problemId, super.key});

  /// The ID of the problem to practise.
  final int problemId;

  @override
  ConsumerState<SessionSetupScreen> createState() =>
      _SessionSetupScreenState();
}

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  SessionMode _mode = SessionMode.full;
  InterviewStage? _focusStage;
  TimerBehavior _behavior = TimerBehavior.softWarning;
  RecordingMode _recordingMode = RecordingMode.notesOnly;
  final Map<String, int> _durationOverrides = {};

  bool get _canBegin =>
      _mode == SessionMode.full || _focusStage != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtlasColors.background,
      body: Center(
        child: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Problem title card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AtlasColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AtlasColors.border),
                  ),
                  child: Text(
                    'Problem #${widget.problemId}',
                    style: const TextStyle(
                      color: AtlasColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Session mode
                const Text(
                  'Session Mode',
                  style: TextStyle(
                    color: AtlasColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _ModeCard(
                  label: 'Full Interview',
                  subtitle: 'Practise all 5 stages in sequence',
                  isSelected: _mode == SessionMode.full,
                  onTap: () => setState(() {
                    _mode = SessionMode.full;
                    _focusStage = null;
                  }),
                ),
                _ModeCard(
                  label: 'Single Stage Drill',
                  subtitle: 'Focus on one stage only',
                  isSelected: _mode == SessionMode.singleStage,
                  onTap: () => setState(() => _mode = SessionMode.singleStage),
                ),
                // Stage picker — visible only in single-stage mode
                if (_mode == SessionMode.singleStage) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Choose a Stage',
                    style: TextStyle(
                      color: AtlasColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...InterviewStage.values.map(
                    (s) => _StagePickerCard(
                      stage: s,
                      isSelected: _focusStage == s,
                      onTap: () => setState(() => _focusStage = s),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Timer behaviour
                const Text(
                  'Timer Behaviour',
                  style: TextStyle(
                    color: AtlasColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...TimerBehavior.values.map(
                  (b) => _BehaviorCard(
                    behavior: b,
                    isSelected: _behavior == b,
                    onTap: () => setState(() => _behavior = b),
                  ),
                ),
                const SizedBox(height: 24),
                // Stage duration sliders
                // Full mode: show all stages.
                // Single-stage mode: show only the selected stage (or all if
                // none chosen yet so the user can still adjust before picking).
                const Text(
                  'Stage Durations',
                  style: TextStyle(
                    color: AtlasColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ..._visibleStages.map(
                  (s) => _StageDurationSlider(
                    stage: s,
                    currentMinutes:
                        (_durationOverrides[s.key] ??
                                s.defaultDurationMinutes * 60) ~/
                            60,
                    onChanged: (minutes) {
                      setState(() {
                        _durationOverrides[s.key] = minutes * 60;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                // Recording mode
                const Text(
                  'Recording Mode',
                  style: TextStyle(
                    color: AtlasColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...RecordingMode.values.map(
                  (m) => _RecordingModeCard(
                    mode: m,
                    isSelected: _recordingMode == m,
                    onTap: () => setState(() => _recordingMode = m),
                  ),
                ),
                const SizedBox(height: 32),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AtlasColors.textSecondary,
                          side: const BorderSide(color: AtlasColors.border),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _canBegin ? _beginInterview : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AtlasColors.accent,
                          disabledBackgroundColor: AtlasColors.surface,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Begin Interview'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<InterviewStage> get _visibleStages {
    if (_mode == SessionMode.singleStage && _focusStage != null) {
      return [_focusStage!];
    }
    return InterviewStage.values;
  }

  Future<void> _beginInterview() async {
    dev.log(
      '_beginInterview: mode=$_mode problemId=${widget.problemId}',
      name: 'SessionSetupScreen',
    );
    final config = TimerConfig(
      stageDurationsSeconds: Map.of(_durationOverrides),
    );

    final notifier = ref.read(sessionControllerProvider.notifier);

    if (_mode == SessionMode.singleStage) {
      await notifier.startSingleStageSession(
        problemId: widget.problemId,
        stage: _focusStage!,
        behavior: _behavior,
        config: config,
        recordingMode: _recordingMode,
      );
    } else {
      await notifier.startFullSession(
        problemId: widget.problemId,
        behavior: _behavior,
        config: config,
        recordingMode: _recordingMode,
      );
    }

    if (!mounted) return;
    final sessionState = ref.read(sessionControllerProvider);
    dev.log(
      '_beginInterview: currentSession=${sessionState.currentSession?.id} '
      'error=${sessionState.errorMessage}',
      name: 'SessionSetupScreen',
    );
    if (sessionState.currentSession != null) {
      context.go('/interview');
    } else {
      // Surface any error so the user knows why nothing happened.
      final msg =
          sessionState.errorMessage ?? 'Failed to start session.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AtlasColors.danger,
        ),
      );
    }
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AtlasColors.accent.withAlpha(30)
              : AtlasColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AtlasColors.accent : AtlasColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AtlasColors.accent : AtlasColors.border,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? AtlasColors.textPrimary
                          : AtlasColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AtlasColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StagePickerCard extends StatelessWidget {
  const _StagePickerCard({
    required this.stage,
    required this.isSelected,
    required this.onTap,
  });

  final InterviewStage stage;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AtlasColors.accent.withAlpha(30)
              : AtlasColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AtlasColors.accent : AtlasColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AtlasColors.accent : AtlasColors.border,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              stage.displayName,
              style: TextStyle(
                color: isSelected
                    ? AtlasColors.textPrimary
                    : AtlasColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BehaviorCard extends StatelessWidget {
  const _BehaviorCard({
    required this.behavior,
    required this.isSelected,
    required this.onTap,
  });

  final TimerBehavior behavior;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AtlasColors.accent.withAlpha(30)
              : AtlasColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AtlasColors.accent : AtlasColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AtlasColors.accent : AtlasColors.border,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _label(behavior),
              style: TextStyle(
                color: isSelected
                    ? AtlasColors.textPrimary
                    : AtlasColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(TimerBehavior b) => switch (b) {
        TimerBehavior.softWarning =>
          'Soft Warning — timer continues into overtime',
        TimerBehavior.warningAutoAdvance =>
          'Auto Advance — grace period then next stage',
        TimerBehavior.hardStop =>
          'Hard Stop — stage ends when time is up',
      };
}

class _StageDurationSlider extends StatelessWidget {
  const _StageDurationSlider({
    required this.stage,
    required this.currentMinutes,
    required this.onChanged,
  });

  final InterviewStage stage;
  final int currentMinutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              stage.displayName,
              style: const TextStyle(
                color: AtlasColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: currentMinutes.toDouble(),
              min: stage.minDurationMinutes.toDouble(),
              max: stage.maxDurationMinutes.toDouble(),
              divisions:
                  stage.maxDurationMinutes - stage.minDurationMinutes,
              activeColor: AtlasColors.accent,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${currentMinutes}m',
              style: const TextStyle(
                color: AtlasColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingModeCard extends StatelessWidget {
  const _RecordingModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final RecordingMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AtlasColors.accent.withAlpha(30)
              : AtlasColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AtlasColors.accent : AtlasColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AtlasColors.accent : AtlasColors.border,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(mode),
                    style: TextStyle(
                      color: isSelected
                          ? AtlasColors.textPrimary
                          : AtlasColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    _subtitle(mode),
                    style: const TextStyle(
                      color: AtlasColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(RecordingMode m) => switch (m) {
        RecordingMode.voiceRecording => 'Voice Recording',
        RecordingMode.speechToText => 'Speech to Text',
        RecordingMode.notesOnly => 'Notes Only',
      };

  String _subtitle(RecordingMode m) => switch (m) {
        RecordingMode.voiceRecording =>
          'Records FLAC audio with live STT display',
        RecordingMode.speechToText =>
          'Real-time transcription into notes',
        RecordingMode.notesOnly => 'No audio capture',
      };
}
