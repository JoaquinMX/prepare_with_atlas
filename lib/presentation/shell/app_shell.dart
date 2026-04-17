import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';
import 'package:prepare_with_atlas/features/settings/application/preferences_controller.dart';

/// The root shell widget that wraps every page with the Atlas sidebar.
class AppShell extends StatelessWidget {
  /// Creates an [AppShell].
  const AppShell({required this.child, super.key});

  /// The current page rendered inside the shell.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentPath =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;

    return Row(
      children: [
        _Sidebar(currentPath: currentPath),
        Expanded(child: child),
      ],
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(
      preferencesControllerProvider.select((p) => p.isLightTheme),
    );
    return SizedBox(
      width: 240,
      child: Container(
        decoration: const BoxDecoration(
          color: AtlasColors.surface,
          border: Border(
            right: BorderSide(color: AtlasColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // App name row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AtlasColors.accent,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Atlas',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AtlasColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AtlasColors.border, thickness: 1, height: 1),
            const SizedBox(height: 8),
            _NavItem(
              label: 'Home',
              icon: Icons.home_outlined,
              route: '/',
              isActive: currentPath == '/',
            ),
            _NavItem(
              label: 'Problems',
              icon: Icons.list_alt_outlined,
              route: '/problems',
              isActive: currentPath == '/problems',
            ),
            _NavItem(
              label: 'History',
              icon: Icons.history_outlined,
              route: '/history',
              isActive: currentPath == '/history',
            ),
            _NavItem(
              label: 'Settings',
              icon: Icons.settings_outlined,
              route: '/settings',
              isActive: currentPath == '/settings',
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => ref
                    .read(preferencesControllerProvider.notifier)
                    .setLightTheme(value: !isLight),
                child: Icon(
                  isLight
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: AtlasColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.isActive,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? AtlasColors.surfaceElevated : Colors.transparent,
          border: isActive
              ? const Border(
                  left: BorderSide(color: AtlasColors.accent, width: 3),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? AtlasColors.textPrimary
                  : AtlasColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight:
                    isActive ? FontWeight.w500 : FontWeight.w400,
                color: isActive
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
