import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Channel used by haptic_kit. The demo listens to it only to show what
/// fired; the calls still reach the native plugin unchanged.
const String _kHapticChannel = 'dev.erykkruk/haptic_kit';

/// Calls that do not play anything, so they are not shown.
const Set<String> _kSilentMethods = {
  'capabilities.query',
  'haptic.prepare',
  'vibration.cancel',
};

/// How long the indicator stays visible after the last haptic.
const Duration _kIndicatorHold = Duration(milliseconds: 900);

/// The most recent haptic the app sent to the platform, as a short label.
///
/// Haptics cannot be seen in a screen recording, so the demo app mirrors
/// each one on screen.
class HapticEventLog {
  HapticEventLog._();

  /// Latest event. A new [HapticLogEntry] per call, so listeners fire
  /// even when the same haptic repeats.
  static final ValueNotifier<HapticLogEntry?> latest = ValueNotifier(null);

  /// Installs a binding whose messenger reports every haptic_kit call to
  /// [latest]. Call once, before `runApp`.
  static void install() => _HapticLoggingBinding();

  static void _record(MethodCall call) {
    if (_kSilentMethods.contains(call.method)) return;
    latest.value = HapticLogEntry(_describe(call));
  }

  static String _describe(MethodCall call) {
    final args = call.arguments;
    final map = args is Map ? args : const <Object?, Object?>{};
    switch (call.method) {
      case 'haptic.impact':
        return 'impact: ${map['style']}';
      case 'haptic.notification':
        return 'notification: ${map['style']}';
      case 'haptic.selection':
        return 'selection';
      case 'haptic.semantic':
        return 'semantic: ${map['type']}';
      case 'composition.play':
        final steps = (map['primitives'] as List?) ?? const [];
        final names = [for (final s in steps) (s as Map)['primitive']];
        return 'composition: ${names.join('+')}';
      case 'pattern.play':
        return 'pattern: ${(map['events'] as List?)?.length ?? 0} events';
      case 'vibration.oneShot':
        return 'vibrate: ${map['durationMs']} ms';
      case 'vibration.waveform':
        return 'waveform';
      case 'vibration.predefined':
        return 'predefined: ${map['effect']}';
      default:
        return call.method;
    }
  }
}

/// One entry of [HapticEventLog.latest].
class HapticLogEntry {
  HapticLogEntry(this.label);

  /// Human-readable description, such as `impact: light`.
  final String label;
}

class _HapticLoggingBinding extends WidgetsFlutterBinding {
  @override
  BinaryMessenger createBinaryMessenger() =>
      _HapticLoggingMessenger(super.createBinaryMessenger());
}

class _HapticLoggingMessenger implements BinaryMessenger {
  _HapticLoggingMessenger(this._inner);

  final BinaryMessenger _inner;
  static const MethodCodec _codec = StandardMethodCodec();

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    if (channel == _kHapticChannel && message != null) {
      HapticEventLog._record(_codec.decodeMethodCall(message));
    }
    return _inner.send(channel, message);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) =>
      _inner.setMessageHandler(channel, handler);

  @override
  // ignore: deprecated_member_use
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) =>
      // ignore: deprecated_member_use
      _inner.handlePlatformMessage(channel, data, callback);
}

/// Pill that flashes the latest haptic, with a ring pulse on each one.
class HapticIndicator extends StatefulWidget {
  const HapticIndicator({super.key});

  @override
  State<HapticIndicator> createState() => _HapticIndicatorState();
}

class _HapticIndicatorState extends State<HapticIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  Timer? _hide;
  bool _visible = false;
  String _label = '';

  @override
  void initState() {
    super.initState();
    HapticEventLog.latest.addListener(_onHaptic);
  }

  @override
  void dispose() {
    HapticEventLog.latest.removeListener(_onHaptic);
    _hide?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _onHaptic() {
    final entry = HapticEventLog.latest.value;
    if (entry == null || !mounted) return;
    setState(() {
      _label = entry.label;
      _visible = true;
    });
    _pulse.forward(from: 0);
    _hide?.cancel();
    _hide = Timer(_kIndicatorHold, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_pulse.value);
            return Transform.scale(
              scale: 1 + 0.08 * (1 - t) * (_pulse.isAnimating ? 1 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Color.lerp(accent, Colors.white24, t)!,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45 * (1 - t)),
                      blurRadius: 18,
                      spreadRadius: 4 * (1 - t),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.vibration, size: 18, color: accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'haptic fired: $_label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
