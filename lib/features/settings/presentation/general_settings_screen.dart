import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/timer_behavior.dart';
import 'package:prepare_with_atlas/features/settings/application/preferences_controller.dart';

/// Settings screen for general app preferences — theme, sound, and timer
/// behavior.
class GeneralSettingsScreen extends ConsumerWidget {
  /// Creates a [GeneralSettingsScreen].
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesControllerProvider);
    final notifier = ref.read(preferencesControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AtlasColors.background,
      body: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 12),
          _SettingsTile(
            title: 'Light Theme',
            subtitle: 'Switch between dark and light appearance.',
            trailing: Switch(
              value: prefs.isLightTheme,
              onChanged: (v) => notifier.setLightTheme(value: v),
              activeThumbColor: AtlasColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'AI Provider'),
          const SizedBox(height: 12),
          _NavigationTile(
            title: 'Configure AI Provider',
            subtitle:
                'Set up OpenAI, Anthropic, Gemini, OpenRouter, or Ollama.',
            onTap: () => context.go('/settings/ai'),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Interview'),
          const SizedBox(height: 12),
          _SettingsTile(
            title: 'Timer Sound',
            subtitle: 'Play a sound when the stage timer reaches zero.',
            trailing: Switch(
              value: prefs.timerSoundEnabled,
              onChanged: (v) => notifier.setTimerSoundEnabled(value: v),
              activeThumbColor: AtlasColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          _TimerBehaviorPicker(
            current: prefs.defaultTimerBehavior,
            onChanged: notifier.setDefaultTimerBehavior,
          ),
        ],
      ),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AtlasColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: AtlasColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AtlasColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AtlasColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AtlasColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AtlasColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: AtlasColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AtlasColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AtlasColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _TimerBehaviorPicker extends StatelessWidget {
  const _TimerBehaviorPicker({
    required this.current,
    required this.onChanged,
  });

  final TimerBehavior current;
  final ValueChanged<TimerBehavior> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AtlasColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: AtlasColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Default Timer Behavior',
            style: TextStyle(
              color: AtlasColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'What happens when a stage timer reaches zero.',
            style: TextStyle(
              color: AtlasColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          RadioGroup<TimerBehavior>(
            groupValue: current,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            child: Column(
              children: [
                _BehaviorOption(
                  label: 'Soft Warning',
                  description:
                      'Timer continues into overtime; you decide when to '
                      'move on.',
                  value: TimerBehavior.softWarning,
                  current: current,
                  onChanged: onChanged,
                ),
                _BehaviorOption(
                  label: 'Warning + Auto Advance',
                  description:
                      'A grace-period countdown starts and the stage '
                      'auto-advances when it expires.',
                  value: TimerBehavior.warningAutoAdvance,
                  current: current,
                  onChanged: onChanged,
                ),
                _BehaviorOption(
                  label: 'Hard Stop',
                  description:
                      'Timer stops immediately and the stage is marked ended.',
                  value: TimerBehavior.hardStop,
                  current: current,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BehaviorOption extends StatelessWidget {
  const _BehaviorOption({
    required this.label,
    required this.description,
    required this.value,
    required this.current,
    required this.onChanged,
  });

  final String label;
  final String description;
  final TimerBehavior value;
  final TimerBehavior current;
  final ValueChanged<TimerBehavior> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<TimerBehavior>(
              value: value,
              activeColor: AtlasColors.accent,
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
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    description,
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
