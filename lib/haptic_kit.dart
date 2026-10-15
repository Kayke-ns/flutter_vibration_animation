/// Comprehensive haptic feedback and vibration toolkit for Flutter — Android
/// & iOS — combined with a set of production-ready animated widgets.
///
/// ## Primitives
///
/// * [Haptics] - short, semantic taps (impact, notification, selection,
///   and [SemanticHaptic] platform-native UI signals).
/// * [Vibration] — longer vibrations, custom waveforms, predefined effects.
/// * [HapticPattern] — fluent builder for custom event sequences
///   (Core Haptics on iOS, waveform on Android).
/// * [HapticComposition] - Android 11+ composition primitives
///   ([HapticPrimitive]), approximated on other devices.
/// * [VibrationPatterns] — ready-made patterns (heartbeat, alarm, …).
/// * [HapticCapabilities] — runtime capability detection.
///
/// ## Animated widgets
///
/// * [HapticBounce] — tap wrapper with squash + elastic bounce + impact.
/// * [HapticToggle] — animated switch with selection tick on flip.
/// * [HapticSlider] — slider that ticks each time a detent is crossed.
/// * [HapticStepper] — −/+ counter with bouncing buttons.
/// * [HapticShake] — externally-triggered error wiggle.
/// * [HapticPulse] — looping "breathing" pulse that ticks on every beat.
/// * [HapticRating] — star rating with cascading fill + ticks.
/// * [PressAndHoldToConfirm] — long-press with progress ring + densifying
///   haptic schedule.
/// * [SlideToConfirm] — drag handle to end to confirm with detent ticks.
library;

export 'src/exceptions.dart';
export 'src/haptic_capabilities.dart';
export 'src/haptic_composition.dart';
export 'src/haptic_feedback.dart';
export 'src/haptic_pattern.dart';
export 'src/haptic_settings.dart';
export 'src/predefined_effect.dart';
export 'src/semantic_haptic.dart';
export 'src/vibration.dart';
export 'src/vibration_patterns.dart';
export 'src/widgets/haptic_bounce.dart';
export 'src/widgets/haptic_pulse.dart';
export 'src/widgets/haptic_rating.dart';
export 'src/widgets/haptic_shake.dart';
export 'src/widgets/haptic_slider.dart';
export 'src/widgets/haptic_stepper.dart';
export 'src/widgets/haptic_toggle.dart';
export 'src/widgets/press_and_hold_to_confirm.dart';
export 'src/widgets/slide_to_confirm.dart';
