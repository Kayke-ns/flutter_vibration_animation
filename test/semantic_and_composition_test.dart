import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haptic_kit/haptic_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.erykkruk/haptic_kit');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];
  Object? capabilitiesReply;

  setUp(() {
    calls.clear();
    capabilitiesReply = null;
    HapticSettings.enabled = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'capabilities.query') return capabilitiesReply;
      return null;
    });
  });

  tearDown(() {
    HapticSettings.enabled = true;
    messenger.setMockMethodCallHandler(channel, null);
  });

  List<Map<Object?, Object?>> argList(String key) =>
      ((calls.single.arguments as Map<Object?, Object?>)[key]! as List<Object?>)
          .cast<Map<Object?, Object?>>();

  group('Haptics.semantic', () {
    test('sends the enum name as the type', () async {
      await Haptics.semantic(SemanticHaptic.gestureThresholdActivate);

      expect(calls.single.method, 'haptic.semantic');
      expect(calls.single.arguments, {'type': 'gestureThresholdActivate'});
    });

    test('is a no-op while HapticSettings is disabled', () async {
      HapticSettings.enabled = false;

      await Haptics.semantic(SemanticHaptic.confirm);

      expect(calls, isEmpty);
    });
  });

  group('HapticComposition', () {
    test('sends primitives with scale and delay', () async {
      await HapticComposition.builder()
          .add(HapticPrimitive.tick, scale: 0.5)
          .add(
            HapticPrimitive.thud,
            delay: const Duration(milliseconds: 40),
          )
          .play();

      expect(calls.single.method, 'composition.play');
      expect(argList('primitives'), [
        {'primitive': 'tick', 'scale': 0.5, 'delayMs': 0},
        {'primitive': 'thud', 'scale': 1.0, 'delayMs': 40},
      ]);
    });

    test('lays out a tap fallback at the cursor, scaled', () async {
      await HapticComposition.builder()
          .add(HapticPrimitive.click, scale: 0.5)
          .add(HapticPrimitive.click, delay: const Duration(milliseconds: 50))
          .play();

      final events = argList('fallbackEvents');
      expect(events, hasLength(2));
      expect(events[0]['intensity'], 0.5);
      expect(events[0]['durationMs'], 0);
      expect(events[0]['relativeTimeMs'], 0);
      // 12 ms click slot + 50 ms delay.
      expect(events[1]['intensity'], 1.0);
      expect(events[1]['relativeTimeMs'], 62);
    });

    test('draws a rise as contiguous segments of growing intensity', () async {
      await HapticComposition.builder().add(HapticPrimitive.quickRise).play();

      final events = argList('fallbackEvents');
      final intensities = [for (final e in events) e['intensity']! as double];
      expect(events, hasLength(5));
      for (var i = 1; i < events.length; i++) {
        expect(intensities[i], greaterThan(intensities[i - 1]));
        expect(
          events[i]['relativeTimeMs'],
          (events[i - 1]['relativeTimeMs']! as int) +
              (events[i - 1]['durationMs']! as int),
        );
      }
    });

    test('draws a spin as a rise then a fall', () async {
      await HapticComposition.builder().add(HapticPrimitive.spin).play();

      final intensities = [
        for (final e in argList('fallbackEvents')) e['intensity']! as double,
      ];
      expect(intensities[2], 1.0);
      expect(intensities.first, lessThan(intensities[2]));
      expect(intensities.last, lessThan(intensities[2]));
    });

    test('rejects scale outside [0, 1]', () {
      final builder = HapticComposition.builder();

      expect(
        () => builder.add(HapticPrimitive.click, scale: 1.1),
        throwsA(isA<InvalidVibrationArgumentException>()),
      );
      expect(
        () => builder.add(HapticPrimitive.click, scale: -0.1),
        throwsA(isA<InvalidVibrationArgumentException>()),
      );
      expect(builder.length, 0);
    });

    test('rejects a negative delay', () {
      expect(
        () => HapticComposition.builder().add(
          HapticPrimitive.tick,
          delay: const Duration(milliseconds: -1),
        ),
        throwsA(isA<InvalidVibrationArgumentException>()),
      );
    });

    test('rejects an empty composition without a platform call', () {
      expect(
        () => HapticComposition.builder().play(),
        throwsA(isA<InvalidVibrationArgumentException>()),
      );
      expect(calls, isEmpty);
    });
  });

  group('HapticCapabilities.supportedPrimitives', () {
    test('parses known names and ignores unknown ones', () async {
      capabilitiesReply = <String, Object?>{
        'hasVibrator': true,
        'supportedPrimitives': ['click', 'spin', 'futurePrimitive'],
      };

      final caps = await HapticCapabilities.query();

      expect(caps.supportedPrimitives, {
        HapticPrimitive.click,
        HapticPrimitive.spin,
      });
    });

    test('defaults to empty when the platform omits it', () async {
      capabilitiesReply = <String, Object?>{'hasVibrator': true};

      final caps = await HapticCapabilities.query();

      expect(caps.supportedPrimitives, isEmpty);
    });
  });
}
