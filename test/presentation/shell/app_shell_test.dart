import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/settings/data/preferences_repository.dart';
import 'package:prepare_with_atlas/features/settings/domain/app_preferences.dart';
import 'package:prepare_with_atlas/presentation/shell/app_shell.dart';

import 'app_shell_test.mocks.dart';

@GenerateMocks([PreferencesRepository])
void main() {
  late MockPreferencesRepository mockRepo;

  setUp(() {
    mockRepo = MockPreferencesRepository();
    when(mockRepo.load()).thenAnswer((_) async => const AppPreferences());
    when(mockRepo.save(any)).thenAnswer((_) async {});
  });

  Widget buildSubject() {
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (c, s) => const SizedBox()),
            GoRoute(path: '/problems', builder: (c, s) => const SizedBox()),
            GoRoute(path: '/history', builder: (c, s) => const SizedBox()),
            GoRoute(path: '/settings', builder: (c, s) => const SizedBox()),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('AppShell', () {
    testWidgets('renders 4 nav items', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Problems'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders Atlas app name in sidebar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Atlas'), findsOneWidget);
    });
  });
}
