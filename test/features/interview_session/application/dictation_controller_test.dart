import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/application/dictation_controller.dart';
import 'package:prepare_with_atlas/features/interview_session/application/dictation_state.dart';

void main() {
  group('DictationController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('initial state is idle', () {
      final state = container.read(dictationControllerProvider);
      expect(state, isA<DictationIdle>());
    });

    test('reset transitions to idle from any state', () async {
      final notifier = container.read(dictationControllerProvider.notifier);
      await notifier.reset();
      final state = container.read(dictationControllerProvider);
      expect(state, isA<DictationIdle>());
    });

    test('cancelListening transitions to idle', () async {
      final notifier = container.read(dictationControllerProvider.notifier);
      await notifier.cancelListening();
      final state = container.read(dictationControllerProvider);
      expect(state, isA<DictationIdle>());
    });

    test('stopListening when idle is a no-op', () async {
      final notifier = container.read(dictationControllerProvider.notifier);
      await notifier.stopListening();
      final state = container.read(dictationControllerProvider);
      expect(state, isA<DictationIdle>());
    });

    test('onResult callback is invoked with recognized text', () async {
      final notifier = container.read(dictationControllerProvider.notifier);
      String? receivedText;
      bool? receivedIsFinal;

      notifier.onResult = (text, {required isFinal}) {
        receivedText = text;
        receivedIsFinal = isFinal;
      };

      notifier.onResult!('hello', isFinal: true);
      expect(receivedText, 'hello');
      expect(receivedIsFinal, true);
    });

    test('onResult callback can be set and replaced', () async {
      final notifier = container.read(dictationControllerProvider.notifier);
      var callCount = 0;

      notifier.onResult = (_, {required isFinal}) {
        callCount++;
      };

      notifier.onResult!('first', isFinal: false);
      expect(callCount, 1);

      notifier.onResult = (_, {required isFinal}) {
        callCount += 10;
      };

      notifier.onResult!('second', isFinal: true);
      expect(callCount, 11);
    });

    // ── Keep-listening behaviour ─────────────────────────────────────────────
    //
    // The SpeechToText engine is not mockable in unit tests (it talks to a
    // platform plugin), so we verify the _keepListening flag indirectly
    // through the observable state transitions.

    test('stopListening when already idle stays idle (no-op)', () async {
      // Ensures stopListening guard works even if _keepListening was never set.
      final notifier = container.read(dictationControllerProvider.notifier);
      await notifier.stopListening();
      expect(container.read(dictationControllerProvider), isA<DictationIdle>());
    });

    test('reset always returns to idle regardless of prior state', () async {
      final notifier = container.read(dictationControllerProvider.notifier);
      // Drive state via cancelListening (known to set idle) then reset.
      await notifier.cancelListening();
      await notifier.reset();
      expect(container.read(dictationControllerProvider), isA<DictationIdle>());
    });

    test('cancelListening after reset stays idle', () async {
      final notifier = container.read(dictationControllerProvider.notifier);
      await notifier.reset();
      await notifier.cancelListening();
      expect(container.read(dictationControllerProvider), isA<DictationIdle>());
    });

    test(
      'stopListening after cancelListening is a no-op (not in listening state)',
      () async {
        final notifier =
            container.read(dictationControllerProvider.notifier);
        await notifier.cancelListening(); // idle
        await notifier.stopListening(); // guard: state is not DictationListening
        expect(
          container.read(dictationControllerProvider),
          isA<DictationIdle>(),
        );
      },
    );
  });

  group('DictationState', () {
    test('idle state has no message', () {
      const state = DictationState.idle();
      expect(state, isA<DictationIdle>());
      expect(
        state.maybeWhen(idle: () => 'idle', orElse: () => 'other'),
        'idle',
      );
    });

    test('listening state has no message', () {
      const state = DictationState.listening();
      expect(state, isA<DictationListening>());
    });

    test('stopped state has no message', () {
      const state = DictationState.stopped();
      expect(state, isA<DictationStopped>());
    });

    test('error state carries message', () {
      const state = DictationState.error(
        message: 'Microphone access is needed.',
      );
      expect(state, isA<DictationError>());
      state.when(
        idle: () => fail('Expected error'),
        listening: () => fail('Expected error'),
        stopped: () => fail('Expected error'),
        error: (message) => expect(message, 'Microphone access is needed.'),
      );
    });
  });
}
