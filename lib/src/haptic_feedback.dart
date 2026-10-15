import 'method_channel.dart';
import 'semantic_haptic.dart';

/// Style of an impact tap.
///
/// Maps to:
/// * iOS — `UIImpactFeedbackGenerator.FeedbackStyle`
/// * Android — `VibrationEffect.EFFECT_*` predefined effects (API 29+),
///   or a short `oneShot` fallback on older devices.
enum HapticImpactStyle {
  /// Subtle tap. iOS: `.light`. Android: `EFFECT_TICK`.
  light,

  /// Standard tap. iOS: `.medium`. Android: `EFFECT_CLICK`.
  medium,

  /// Strong tap. iOS: `.heavy`. Android: `EFFECT_HEAVY_CLICK`.
  heavy,

  /// Soft tap (iOS 13+). Falls back to [light] on older iOS / Android.
  soft,

  /// Rigid tap (iOS 13+). Falls back to [heavy] on older iOS / Android.
  rigid,
}

/// Style of a notification haptic.
///
/// Maps to `UINotificationFeedbackGenerator.FeedbackType` on iOS, and to a
/// distinctive short waveform on Android.
enum HapticNotificationStyle {
  /// Confirms a successful action.
  success,

  /// Warns the user about a non-fatal issue.
  warning,

  /// Signals a failure.
  error,
}

/// Short, semantic haptic taps tied to UI events.
///
/// For longer vibrations, custom waveforms or repeating patterns use
/// `Vibration` or [HapticPattern] instead.
///
/// ```dart
/// await Haptics.impact(HapticImpactStyle.medium);
/// await Haptics.notification(HapticNotificationStyle.success);
/// await Haptics.selection();
/// ```
///
/// Named `Haptics` (not `HapticFeedback`) to avoid clashing with Flutter's
/// own `HapticFeedback` from `package:flutter/services.dart`.
class Haptics {
  const Haptics._();

  /// Trigger an impact-style tap.
  ///
  /// On iOS the generator is automatically prepared — repeated calls within
  /// a short window are cheap. On Android API 29+ the matching predefined
  /// effect is used; on older devices a short `oneShot` fallback runs.
  static Future<void> impact(
    HapticImpactStyle style,
  ) =>
      HapticKitChannel.invoke<void>('haptic.impact', {
        'style': style.name,
      });

  /// Trigger a notification haptic — success / warning / error.
  static Future<void> notification(
    HapticNotificationStyle style,
  ) =>
      HapticKitChannel.invoke<void>('haptic.notification', {
        'style': style.name,
      });

  /// Trigger a selection-changed tap. Use when scrolling through discrete
  /// values (pickers, sliders, segmented controls).
  static Future<void> selection() =>
      HapticKitChannel.invoke<void>('haptic.selection');

  /// Play the platform's native haptic for a UI event, named by its
  /// meaning rather than its strength.
  ///
  /// On Android this goes through `View.performHapticFeedback`, which
  /// follows the user's system touch-feedback setting: when they turned it
  /// off, nothing plays. Newer `HapticFeedbackConstants` are used on the OS
  /// versions that have them, with the closest older constant elsewhere. If
  /// no activity is attached (for example a background engine), the call
  /// falls back to the matching predefined vibration. On iOS the closest
  /// `UIFeedbackGenerator` plays. See [SemanticHaptic] for the mapping.
  ///
  /// ```dart
  /// onChanged: (on) {
  ///   Haptics.semantic(on ? SemanticHaptic.toggleOn : SemanticHaptic.toggleOff);
  /// }
  /// ```
  static Future<void> semantic(SemanticHaptic type) =>
      HapticKitChannel.invoke<void>('haptic.semantic', {
        'type': type.name,
      });

  /// Pre-warm haptic generators so the next call has the lowest possible
  /// latency. Optional — calling [impact] / [notification] / [selection]
  /// directly works fine.
  ///
  /// Returns `true` when the platform actually pre-warmed something (iOS),
  /// and `false` when the call is a no-op on this platform (Android).
  static Future<bool> prepare() async {
    final result = await HapticKitChannel.invoke<bool>('haptic.prepare');
    return result ?? false;
  }
}
