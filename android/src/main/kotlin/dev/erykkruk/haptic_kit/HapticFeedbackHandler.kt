package dev.erykkruk.haptic_kit

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View

/**
 * Translates Dart-side `HapticImpactStyle` / `HapticNotificationStyle` enum
 * names into the closest Android equivalent. Android does not have a direct
 * counterpart to `UIImpactFeedbackGenerator`, so we layer:
 *
 * 1. `VibrationEffect.createPredefined` (API 29+) for impact styles, then
 * 2. short `createOneShot` calls (API 26+) with style-specific durations and
 *    amplitudes, falling back to legacy `Vibrator.vibrate(long)` on older
 *    devices.
 */
internal class HapticFeedbackHandler(private val vibrationManager: VibrationManager) {

    fun impact(style: String) {
        when (style) {
            "light", "soft" -> vibrationManager.predefined("tick")
            "medium" -> vibrationManager.predefined("click")
            "heavy", "rigid" -> vibrationManager.predefined("heavyClick")
            else -> throw IllegalArgumentException("Unknown impact style: $style")
        }
    }

    fun notification(style: String) {
        when (style) {
            // Two short pulses, ascending.
            "success" -> vibrationManager.waveform(
                longArrayOf(0, 60, 60, 80),
                intArrayOf(0, 120, 0, 200),
                -1,
            )
            // Single mid pulse + short tail.
            "warning" -> vibrationManager.waveform(
                longArrayOf(0, 100, 80, 100),
                intArrayOf(0, 180, 0, 180),
                -1,
            )
            // Three rapid heavy taps.
            "error" -> vibrationManager.waveform(
                longArrayOf(0, 80, 60, 80, 60, 100),
                intArrayOf(0, 255, 0, 255, 0, 255),
                -1,
            )
            else -> throw IllegalArgumentException("Unknown notification style: $style")
        }
    }

    fun selection() {
        vibrationManager.predefined("tick")
    }

    /**
     * Plays a Dart `SemanticHaptic` through [View.performHapticFeedback],
     * which honours the user's touch-feedback setting. Its boolean result is
     * ignored on purpose: false usually means the user turned haptics off,
     * and falling back to the vibrator would override that choice. Only a
     * missing view (no activity attached) falls back to a predefined effect.
     */
    fun semantic(type: String, view: View?) {
        val constant = semanticConstant(type)
        if (view != null) {
            view.performHapticFeedback(constant)
        } else {
            vibrationManager.predefined(semanticFallbackEffect(type))
        }
    }

    private fun semanticConstant(type: String): Int {
        val sdk = Build.VERSION.SDK_INT
        val r = Build.VERSION_CODES.R
        val u = Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        val contextClick = if (sdk >= Build.VERSION_CODES.M) {
            HapticFeedbackConstants.CONTEXT_CLICK
        } else {
            HapticFeedbackConstants.VIRTUAL_KEY
        }
        val tick = HapticFeedbackConstants.CLOCK_TICK
        return when (type) {
            "confirm" -> if (sdk >= r) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY
            "reject" -> if (sdk >= r) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS
            "toggleOn" -> if (sdk >= u) HapticFeedbackConstants.TOGGLE_ON else contextClick
            "toggleOff" -> if (sdk >= u) HapticFeedbackConstants.TOGGLE_OFF else tick
            "gestureStart" -> if (sdk >= r) HapticFeedbackConstants.GESTURE_START else contextClick
            "gestureEnd" -> if (sdk >= r) HapticFeedbackConstants.GESTURE_END else tick
            "gestureThresholdActivate" ->
                if (sdk >= u) HapticFeedbackConstants.GESTURE_THRESHOLD_ACTIVATE else contextClick
            "gestureThresholdDeactivate" ->
                if (sdk >= u) HapticFeedbackConstants.GESTURE_THRESHOLD_DEACTIVATE else tick
            "dragStart" -> if (sdk >= u) HapticFeedbackConstants.DRAG_START else contextClick
            "segmentTick" -> if (sdk >= u) HapticFeedbackConstants.SEGMENT_TICK else tick
            "segmentFrequentTick" -> when {
                sdk >= u -> HapticFeedbackConstants.SEGMENT_FREQUENT_TICK
                sdk >= Build.VERSION_CODES.O_MR1 -> HapticFeedbackConstants.TEXT_HANDLE_MOVE
                else -> tick
            }
            "longPress" -> HapticFeedbackConstants.LONG_PRESS
            else -> throw IllegalArgumentException("Unknown semantic haptic: $type")
        }
    }

    private fun semanticFallbackEffect(type: String): String = when (type) {
        "reject", "longPress" -> "heavyClick"
        "toggleOff", "gestureEnd", "gestureThresholdDeactivate",
        "segmentTick", "segmentFrequentTick" -> "tick"
        else -> "click"
    }
}
