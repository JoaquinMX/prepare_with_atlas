import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/history/application/history_providers.dart';
import 'package:prepare_with_atlas/features/history/application/history_state.dart';
import 'package:prepare_with_atlas/features/settings/data/preferences_repository.dart';
import 'package:prepare_with_atlas/features/settings/domain/app_preferences.dart';
import 'package:prepare_with_atlas/main.dart';

import 'widget_test.mocks.dart';

/// Stub history controller that returns an empty [HistoryState] without
/// touching the real database, preventing pending-timer failures in tests.
class _StubHistoryController extends HistoryController {
  @override
  HistoryState build() => const HistoryState();

  @override
  void toggleView() {}

  @override
  Future<void> deleteSession(int sessionId) async {}
}

@GenerateMocks([PreferencesRepository])
void main() {
  testWidgets('App smoke test - renders without crashing',
      (WidgetTester tester) async {
    final mockRepo = MockPreferencesRepository();
    when(mockRepo.load()).thenAnswer((_) async => const AppPreferences());
    when(mockRepo.save(any)).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(mockRepo),
          historyControllerProvider
              .overrideWith(_StubHistoryController.new),
        ],
        child: const PrepareWithAtlasApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
