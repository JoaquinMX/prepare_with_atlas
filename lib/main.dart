import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/core/routing/app_router.dart';
import 'package:prepare_with_atlas/core/theme/atlas_theme.dart';
import 'package:prepare_with_atlas/features/settings/application/preferences_controller.dart';
import 'package:prepare_with_atlas/features/settings/data/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry point — initializes platform bindings and shared preferences before
/// handing off to [ProviderScope].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          PreferencesRepository(prefs),
        ),
      ],
      child: const PrepareWithAtlasApp(),
    ),
  );
}

/// Root application widget.
class PrepareWithAtlasApp extends ConsumerWidget {
  /// Creates a [PrepareWithAtlasApp].
  const PrepareWithAtlasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight =
        ref.watch(preferencesControllerProvider.select((p) => p.isLightTheme));
    return MaterialApp.router(
      title: 'PrepareWithAtlas',
      theme: isLight ? AtlasTheme.light : AtlasTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
