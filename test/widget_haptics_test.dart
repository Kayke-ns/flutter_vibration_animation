import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haptic_kit/haptic_kit.dart';
import 'package:haptic_kit/src/widgets/widget_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.erykkruk/haptic_kit');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // A platform channel reply takes several event-loop turns, so a single
  // zero delay would return before a channel failure could surface.
  const settleDelay = Duration(milliseconds: 50);

  Future<List<Object>> uncaughtErrorsOf(void Function() body) async {
    final errors = <Object>[];
    runZonedGuarded(body, (error, _) => errors.add(error));
    await Future<void>.delayed(settleDelay);
    return errors;
  }

  group('playWidgetHaptic', () {
    test('absorbs a VibrationException', () async {
      final errors = await uncaughtErrorsOf(
        () => playWidgetHaptic(
          Future<void>.error(
            const PlatformVibrationException('boom', code: 'native_error'),
          ),
        ),
      );

      expect(errors, isEmpty);
    });

    test('still surfaces errors that are not a VibrationException', () async {
      final errors = await uncaughtErrorsOf(
        () => playWidgetHaptic(Future<void>.error(StateError('bug'))),
      );

      expect(errors.single, isA<StateError>());
    });

    test('absorbs a missing plugin (web, desktop, unmocked tests)', () async {
      messenger.setMockMethodCallHandler(channel, null);

      final errors = await uncaughtErrorsOf(
        () => playWidgetHaptic(Haptics.impact(HapticImpactStyle.light)),
      );

      expect(errors, isEmpty);
    });
  });

  group('widgets on a platform that rejects haptics', () {
    setUp(() {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'native_error'),
      );
    });

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    testWidgets('HapticBounce still taps without an uncaught error',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HapticBounce(
            onTap: () => taps++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      await tester.tap(find.byType(HapticBounce));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HapticToggle still flips without an uncaught error',
        (tester) async {
      bool? flipped;
      await tester.pumpWidget(
        MaterialApp(
          home: HapticToggle(
            value: false,
            onChanged: (value) => flipped = value,
          ),
        ),
      );

      await tester.tap(find.byType(HapticToggle));
      await tester.pumpAndSettle();

      expect(flipped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
