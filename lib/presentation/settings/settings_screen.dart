import 'package:flutter/material.dart';

/// Settings screen — hosts AI provider configuration.
///
/// Navigate to `/settings/ai` for the AI provider sub-screen.
class SettingsScreen extends StatelessWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Settings',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }
}
