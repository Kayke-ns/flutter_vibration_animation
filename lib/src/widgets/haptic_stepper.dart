import 'package:flutter/material.dart';

import '../haptic_feedback.dart';
import 'haptic_bounce.dart';
import 'widget_haptics.dart';

/// Numeric stepper with bouncing −/+ buttons and a number that slides up
/// (on increment) or down (on decrement).
///
/// Each button press fires a light haptic. Hitting [min] or [max] fires
/// a heavy haptic to signal the boundary.
///
/// ```dart
/// HapticStepper(
///   value: _count,
///   min: 0,
///   max: 99,
///   onChanged: (v) => setState(() => _count = v),
/// )
/// ```
class HapticStepper extends StatelessWidget {
  /// Creates a stepper showing [value] within `[min, max]`.
  ///
  /// [step] must be greater than zero and [min] must be less than [max].
  const HapticStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.step = 1,
  })  : assert(step > 0, 'step must be > 0'),
        assert(min < max, 'min must be < max');

  /// Current value shown between the buttons.
  final int value;

  /// Called with the new value, already clamped to `[min, max]`.
  final ValueChanged<int> onChanged;

  /// Lowest allowed value. Defaults to `0`.
  final int min;

  /// Highest allowed value. Defaults to `99`.
  final int max;

  /// Amount added or subtracted by each button press. Defaults to `1`.
  final int step;

  void _bump(int delta) {
    final next = (value + delta).clamp(min, max);
    if (next == value) {
      playWidgetHaptic(Haptics.impact(HapticImpactStyle.heavy)); // boundary
      return;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HapticBounce(
          onTap: () => _bump(-step),
          child: _StepperButton(icon: Icons.remove, theme: theme),
        ),
        SizedBox(
          width: 64,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) {
              final increasing =
                  child.key == ValueKey<int>(value); // current is the "in"
              final dy = increasing ? 1.0 : -1.0;
              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, dy),
                  end: Offset.zero,
                ).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              );
            },
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.center,
              children: [...previous, if (current != null) current],
            ),
            child: Text(
              '$value',
              key: ValueKey<int>(value),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        HapticBounce(
          onTap: () => _bump(step),
          child: _StepperButton(icon: Icons.add, theme: theme),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.theme});

  final IconData icon;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: theme.colorScheme.primary),
    );
  }
}
