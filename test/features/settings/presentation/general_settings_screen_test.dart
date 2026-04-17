import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/settings/data/preferences_repository.dart';
import 'package:prepare_with_atlas/features/settings/domain/app_preferences.dart';
import 'package:prepare_with_atlas/features/settings/presentation/general_settings_screen.dart';

import 'general_settings_screen_test.mocks.dart';

@GenerateMocks([PreferencesRepository])
void main() {
  late MockPreferencesRepository mockRepo;

  setUp(() {
    mockRepo = MockPreferencesRepository();
    when(mockRepo.load()).thenAnswer((_) async => const AppPreferences());
    when(mockRepo.save(any)).thenAnswer((_) async {});
  });

  Widget buildSubject({AppPreferences? initial}) {
    if (initial != null) {
      when(mockRepo.load()).thenAnswer((_) async => initial);
    }
    return ProviderScope(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: const MaterialApp(
        home: Scaffold(body: GeneralSettingsScreen()),
      ),
    );
  }

  group('GeneralSettingsScreen', () {
    testWidgets('shows Light Theme switch', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Light Theme'), findsOneWidget);
      expect(find.byType(Switch), findsAtLeastNWidgets(1));
    });

    testWidgets('theme switch reflects isLightTheme=false by default',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final switchWidget = tester.widgetList<Switch>(find.byType(Switch)).first;
      expect(switchWidget.value, isFalse);
    });

    testWidgets('theme switch reflects isLightTheme=true when set',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(initial: const AppPreferences(isLightTheme: true)),
      );
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      final themeSwitch = switches.firstWhere(
        (_) => true, // first switch is theme
        orElse: () => switches.first,
      );
      expect(themeSwitch.value, isTrue);
    });

    testWidgets('shows Timer Sound switch', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Timer Sound'), findsOneWidget);
      expect(find.byType(Switch), findsAtLeastNWidgets(2));
    });

    testWidgets('timer sound switch reflects timerSoundEnabled=true by default',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, greaterThanOrEqualTo(2));
      expect(switches[1].value, isTrue);
    });

    testWidgets('shows 3 timer behavior options', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Soft Warning'), findsOneWidget);
      expect(find.text('Warning + Auto Advance'), findsOneWidget);
      expect(find.text('Hard Stop'), findsOneWidget);
    });

    testWidgets('toggling theme switch calls setLightTheme', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final switches = find.byType(Switch);
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      verify(mockRepo.save(any)).called(greaterThanOrEqualTo(1));
    });
  });
}
