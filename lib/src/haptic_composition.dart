import 'exceptions.dart';
import 'haptic_pattern.dart';
import 'method_channel.dart';

/// A building block of a [HapticComposition].
///
/// On Android 11+ each value is a hardware-tuned
/// `VibrationEffect.Composition` primitive, rendered by the vibrator itself
/// when [HapticComposition.supportedPrimitives] lists it. Everywhere else
/// (iOS, older Android, or a vibrator without that primitive) it is
/// approximated with intensity and sharpness events, through Core Haptics on
/// iOS and a waveform on Android.
enum HapticPrimitive {
  /// A crisp, strong click. Android: `PRIMITIVE_CLICK` (API 30+).
  click,

  /// A very short, light tick. Android: `PRIMITIVE_TICK` (API 30+).
  tick,

  /// A softer, lower-pitched tick. Android: `PRIMITIVE_LOW_TICK` (API 31+).
  lowTick,

  /// A short ramp up in strength. Android: `PRIMITIVE_QUICK_RISE` (API 30+).
  quickRise,

  /// A long, gradual ramp up in strength.
  /// Android: `PRIMITIVE_SLOW_RISE` (API 30+).
  slowRise,

  /// A short ramp down in strength.
  /// Android: `PRIMITIVE_QUICK_FALL` (API 30+).
  quickFall,

  /// A deep, heavy thud. Android: `PRIMITIVE_THUD` (API 31+).
  thud,

  /// A short spinning sensation that rises and falls.
  /// Android: `PRIMITIVE_SPIN` (API 31+).
  spin,
}

/// Fluent builder for a sequence of [HapticPrimitive]s.
///
/// Compositions are the expressive haptics of modern Android: each
/// primitive is designed by the device maker for its own actuator, so a
/// composition feels crisp instead of buzzy.
///
/// ```dart
/// await HapticComposition.builder()
///     .add(HapticPrimitive.slowRise, scale: 0.6)
///     .add(HapticPrimitive.click, delay: const Duration(milliseconds: 40))
///     .play();
/// ```
///
/// [play] works on every device. When the vibrator cannot render every
/// primitive of the composition natively, the whole composition is played
/// as an approximation instead, so it never comes out half-native.
class HapticComposition {
  HapticComposition._();

  /// Start building a new composition.
  factory HapticComposition.builder() = HapticComposition._;

  final List<_Step> _steps = [];

  /// Append [primitive] at [scale] (`0.0` to `1.0`, relative strength)
  /// after a silent [delay] following the previous primitive.
  ///
  /// Throws [InvalidVibrationArgumentException] when [scale] is outside
  /// `[0, 1]` or [delay] is negative.
  HapticComposition add(
    HapticPrimitive primitive, {
    double scale = 1.0,
    Duration delay = Duration.zero,
  }) {
    if (scale.isNaN || scale < 0.0 || scale > 1.0) {
      throw const InvalidVibrationArgumentException(
        'scale must be in [0, 1]',
      );
    }
    if (delay.isNegative) {
      throw const InvalidVibrationArgumentException(
        'delay must be >= 0 ms',
      );
    }
    _steps.add(_Step(primitive, scale, delay));
    return this;
  }

  /// Number of primitives queued so far.
  int get length => _steps.length;

  /// The [HapticPrimitive]s this device's vibrator renders natively.
  ///
  /// * Android - checked with `Vibrator.arePrimitivesSupported` on API 30+
  ///   (`lowTick`, `thud` and `spin` need API 31). Empty on older versions.
  /// * iOS - always empty: compositions are approximated with Core Haptics.
  ///
  /// [play] works either way. This tells you whether a composition will
  /// feel native or approximated, for example to pick a different effect
  /// on devices that would only approximate it. Like
  /// `HapticCapabilities.query()`, it is a query, so it still reaches the
  /// platform while `HapticSettings.enabled` is false.
  static Future<Set<HapticPrimitive>> supportedPrimitives() async {
    final raw = await HapticKitChannel.invoke<Map<Object?, Object?>>(
      'capabilities.query',
      null,
      false,
    );
    final reported = raw?['supportedPrimitives'];
    if (reported is! List<Object?>) return const {};
    final names = reported.whereType<String>().toSet();
    return {
      for (final primitive in HapticPrimitive.values)
        if (names.contains(primitive.name)) primitive,
    };
  }

  /// Send the composition to the native side and play it.
  ///
  /// Throws [InvalidVibrationArgumentException] when nothing was added.
  Future<void> play() {
    if (_steps.isEmpty) {
      throw const InvalidVibrationArgumentException(
        'composition has no primitives - add at least one',
      );
    }
    return HapticKitChannel.invoke<void>('composition.play', {
      'primitives': [
        for (final step in _steps)
          {
            'primitive': step.primitive.name,
            'scale': step.scale,
            'delayMs': step.delay.inMilliseconds,
          },
      ],
      'fallbackEvents': [
        for (final event in _fallbackEvents()) event.toMap(),
      ],
    });
  }

  /// Lays the composition out on a timeline of [HapticEvent]s, used where
  /// the primitives cannot be rendered natively.
  List<HapticEvent> _fallbackEvents() {
    final events = <HapticEvent>[];
    var cursor = Duration.zero;
    for (final step in _steps) {
      cursor += step.delay;
      final shape = _shapes[step.primitive]!;
      events.addAll(shape.eventsAt(cursor, step.scale));
      cursor += shape.duration;
    }
    return events;
  }
}

class _Step {
  const _Step(this.primitive, this.scale, this.delay);

  final HapticPrimitive primitive;
  final double scale;
  final Duration delay;
}

// Ramps are drawn as this many continuous segments of stepped intensity,
// enough to feel smooth without flooding the platform with events.
const int _kRampSegments = 5;

/// How a primitive is approximated without native support. The values are
/// hand-tuned to feel close to the Android originals; they are not read
/// from the device.
class _PrimitiveShape {
  const _PrimitiveShape.transient({
    required this.intensity,
    required this.sharpness,
    required this.duration,
  })  : rampTo = null,
        peakAt = null;

  const _PrimitiveShape.ramp({
    required this.intensity,
    required double to,
    required this.sharpness,
    required this.duration,
    this.peakAt,
  }) : rampTo = to;

  /// Strength at full scale. For a ramp, the strength it starts from.
  final double intensity;

  /// Strength a ramp ends at (or peaks at, see [peakAt]). Null for a tap.
  final double? rampTo;

  /// For a rise-and-fall ramp, the fraction of [duration] at which the
  /// strength peaks at [rampTo] before falling back to [intensity].
  final double? peakAt;

  final double sharpness;

  /// Time the primitive occupies on the timeline.
  final Duration duration;

  List<HapticEvent> eventsAt(Duration start, double scale) {
    final to = rampTo;
    if (to == null) {
      return [
        HapticEvent(
          intensity: intensity * scale,
          sharpness: sharpness,
          relativeTime: start,
        ),
      ];
    }
    final segment = duration ~/ _kRampSegments;
    return [
      for (var i = 0; i < _kRampSegments; i++)
        HapticEvent(
          intensity: _rampAt(i / (_kRampSegments - 1), to) * scale,
          sharpness: sharpness,
          duration: segment,
          relativeTime: start + segment * i,
        ),
    ];
  }

  double _rampAt(double t, double to) {
    final peak = peakAt;
    if (peak == null) return intensity + (to - intensity) * t;
    final distance = t <= peak ? t / peak : (1 - t) / (1 - peak);
    return intensity + (to - intensity) * distance;
  }
}

const Map<HapticPrimitive, _PrimitiveShape> _shapes = {
  HapticPrimitive.click: _PrimitiveShape.transient(
    intensity: 1.0,
    sharpness: 0.8,
    duration: Duration(milliseconds: 12),
  ),
  HapticPrimitive.tick: _PrimitiveShape.transient(
    intensity: 0.5,
    sharpness: 1.0,
    duration: Duration(milliseconds: 6),
  ),
  HapticPrimitive.lowTick: _PrimitiveShape.transient(
    intensity: 0.35,
    sharpness: 0.2,
    duration: Duration(milliseconds: 12),
  ),
  HapticPrimitive.quickRise: _PrimitiveShape.ramp(
    intensity: 0.1,
    to: 1.0,
    sharpness: 0.5,
    duration: Duration(milliseconds: 150),
  ),
  HapticPrimitive.slowRise: _PrimitiveShape.ramp(
    intensity: 0.1,
    to: 1.0,
    sharpness: 0.3,
    duration: Duration(milliseconds: 450),
  ),
  HapticPrimitive.quickFall: _PrimitiveShape.ramp(
    intensity: 1.0,
    to: 0.1,
    sharpness: 0.5,
    duration: Duration(milliseconds: 100),
  ),
  HapticPrimitive.thud: _PrimitiveShape.ramp(
    intensity: 0.9,
    to: 0.3,
    sharpness: 0.05,
    duration: Duration(milliseconds: 100),
  ),
  HapticPrimitive.spin: _PrimitiveShape.ramp(
    intensity: 0.3,
    to: 1.0,
    sharpness: 0.7,
    duration: Duration(milliseconds: 150),
    peakAt: 0.5,
  ),
};
