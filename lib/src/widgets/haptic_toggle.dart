import 'package:flutter/material.dart';

import '../haptic_feedback.dart';
import 'widget_haptics.dart';

/// Animated switch with a haptic tick on toggle.
///
/// Custom-drawn pill + thumb with a spring-back animation on every change.
/// Behaves like a `Switch` (controlled — caller owns [value], handles
/// changes through [onChanged]).
///
/// ```dart
/// HapticToggle(
///   value: _enabled,
///   onChanged: (v) => setState(() => _enabled = v),
/// )
/// ```
class HapticToggle extends StatefulWidget {
  /// Creates a toggle showing [value]. Pass a null [onChanged] to disable it.
  const HapticToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor = const Color(0xFF3A3A3C),
    this.thumbColor = Colors.white,
    this.width = 56,
    this.height = 32,
    this.duration = const Duration(milliseconds: 220),
  });

  /// Whether the toggle is on.
  final bool value;

  /// Called with the flipped value on tap. When null the toggle is disabled
  /// and ignores taps.
  final ValueChanged<bool>? onChanged;

  /// Track colour when on. Defaults to the theme's primary colour.
  final Color? activeColor;

  /// Track colour when off. Defaults to a dark grey.
  final Color inactiveColor;

  /// Colour of the sliding thumb. Defaults to [Colors.white].
  final Color thumbColor;

  /// Width of the track in logical pixels. Defaults to `56`.
  final double width;

  /// Height of the track in logical pixels. Defaults to `32`.
  final double height;

  /// Duration of the thumb animation. Defaults to `220 ms`.
  final Duration duration;

  @override
  State<HapticToggle> createState() => _HapticToggleState();
}

class _HapticToggleState extends State<HapticToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.value ? 1.0 : 0.0,
    );
    _slide = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void didUpdateWidget(HapticToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.onChanged == null) return;
    playWidgetHaptic(Haptics.selection());
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor =
        widget.activeColor ?? Theme.of(context).colorScheme.primary;
    final thumbDiameter = widget.height - 4;
    final travel = widget.width - thumbDiameter - 4;

    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, _) {
          final t = _slide.value.clamp(0.0, 1.0);
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.lerp(widget.inactiveColor, activeColor, t),
              borderRadius: BorderRadius.circular(widget.height),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 2 + travel * _slide.value,
                  top: 2,
                  child: Container(
                    width: thumbDiameter,
                    height: thumbDiameter,
                    decoration: BoxDecoration(
                      color: widget.thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
