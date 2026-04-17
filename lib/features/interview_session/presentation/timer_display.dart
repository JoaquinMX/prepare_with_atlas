import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';
import 'package:prepare_with_atlas/features/interview_session/application/timer_state.dart';

/// Displays the current timer value in MM:SS format.
///
/// Color transitions: accent (normal) → amber (warning) → red (overtime).
class TimerDisplay extends ConsumerWidget {
  /// Creates a [TimerDisplay].
  const TimerDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(stageTimerControllerProvider);

    return switch (timerState) {
      TimerIdle() => _buildLabel('--:--', AtlasColors.textMuted),
      TimerRunning(:final remainingSeconds) =>
        _buildLabel(_format(remainingSeconds), AtlasColors.accent),
      TimerPaused(:final remainingSeconds) =>
        _buildLabel(_format(remainingSeconds), AtlasColors.textSecondary),
      TimerWarning(:final remainingSeconds) =>
        _buildLabel(_format(remainingSeconds), AtlasColors.warning),
      TimerOvertime(:final overtimeSeconds) =>
        _buildLabel(_formatOvertime(overtimeSeconds), AtlasColors.danger),
      TimerGracePeriod(:final remainingGraceSeconds) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLabel(_format(0), AtlasColors.danger),
            Text(
              'Grace: ${_format(remainingGraceSeconds)}',
              style: const TextStyle(
                color: AtlasColors.warning,
                fontSize: 12,
                fontFamily: 'Courier',
              ),
            ),
          ],
        ),
      TimerStageEnded() =>
        _buildLabel('00:00', AtlasColors.danger),
    };
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 28,
        fontFamily: 'Courier',
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }

  /// Formats [seconds] as MM:SS (e.g. 420 → "07:00").
  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Formats [overtimeSeconds] as -MM:SS (e.g. 90 → "-01:30").
  String _formatOvertime(int overtimeSeconds) {
    final m = overtimeSeconds ~/ 60;
    final s = overtimeSeconds % 60;
    return '-${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
