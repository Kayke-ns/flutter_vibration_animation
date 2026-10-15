/// A UI meaning to signal with the platform's own haptic for it.
///
/// Pass one to `Haptics.semantic`. Instead of picking an intensity, you name
/// what happened (a toggle turned on, a drag started, a threshold was
/// crossed) and each platform plays its native signal for that event:
///
/// * Android - `View.performHapticFeedback` with the matching
///   `HapticFeedbackConstants` value. Newer constants are used where the OS
///   has them (API 30 for confirm / reject / gestures, API 34 for toggles,
///   thresholds, drag and segment ticks) and the closest older constant
///   otherwise. This path respects the user's system touch-feedback setting
///   and needs no `VIBRATE` permission.
/// * iOS - the closest `UIFeedbackGenerator` (notification, impact or
///   selection), listed on each value.
enum SemanticHaptic {
  /// A user action succeeded, such as a confirmed dialog.
  ///
  /// Android: `CONFIRM` (API 30+), else `VIRTUAL_KEY`.
  /// iOS: notification `.success`.
  confirm,

  /// A user action was refused or failed, such as an invalid input.
  ///
  /// Android: `REJECT` (API 30+), else `LONG_PRESS`.
  /// iOS: notification `.error`.
  reject,

  /// A switch or checkbox turned on.
  ///
  /// Android: `TOGGLE_ON` (API 34+), else `CONTEXT_CLICK`.
  /// iOS: impact `.medium`.
  toggleOn,

  /// A switch or checkbox turned off.
  ///
  /// Android: `TOGGLE_OFF` (API 34+), else `CLOCK_TICK`.
  /// iOS: impact `.light`.
  toggleOff,

  /// A gesture such as a swipe began.
  ///
  /// Android: `GESTURE_START` (API 30+), else `CONTEXT_CLICK`.
  /// iOS: impact `.light`.
  gestureStart,

  /// A gesture finished.
  ///
  /// Android: `GESTURE_END` (API 30+), else `CLOCK_TICK`.
  /// iOS: impact `.soft` (`.light` before iOS 13).
  gestureEnd,

  /// A gesture crossed the point where releasing it would trigger an
  /// action, such as swipe-to-delete passing its threshold.
  ///
  /// Android: `GESTURE_THRESHOLD_ACTIVATE` (API 34+), else `CONTEXT_CLICK`.
  /// iOS: impact `.rigid` (`.heavy` before iOS 13).
  gestureThresholdActivate,

  /// A gesture moved back before its threshold, so releasing it now does
  /// nothing.
  ///
  /// Android: `GESTURE_THRESHOLD_DEACTIVATE` (API 34+), else `CLOCK_TICK`.
  /// iOS: impact `.soft` (`.light` before iOS 13).
  gestureThresholdDeactivate,

  /// An item was picked up to be dragged.
  ///
  /// Android: `DRAG_START` (API 34+), else `CONTEXT_CLICK`.
  /// iOS: impact `.medium`.
  dragStart,

  /// A value moved to the next step of a coarse scale, such as a slider
  /// with a few detents.
  ///
  /// Android: `SEGMENT_TICK` (API 34+), else `CLOCK_TICK`.
  /// iOS: selection changed.
  segmentTick,

  /// A value moved to the next step of a fine scale, where ticks arrive
  /// quickly, such as scrubbing through a long list of values.
  ///
  /// Android: `SEGMENT_FREQUENT_TICK` (API 34+), else `TEXT_HANDLE_MOVE`
  /// (API 27+) or `CLOCK_TICK`.
  /// iOS: selection changed.
  segmentFrequentTick,

  /// A long press was recognised.
  ///
  /// Android: `LONG_PRESS`.
  /// iOS: impact `.heavy`.
  longPress,
}
