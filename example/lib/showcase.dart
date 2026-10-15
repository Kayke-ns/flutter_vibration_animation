import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:haptic_kit/haptic_kit.dart';

import 'haptic_indicator.dart';

/// Logical size of the stage every scene is drawn in. The README GIFs are
/// cropped to exactly this box, so keep it in sync with the recording
/// script.
const Size kShowcaseStage = Size(393, 480);

const Color _kStageColor = Color(0xFF121218);
const Duration _kSceneLead = Duration(milliseconds: 1200);
const Duration _kSceneTail = Duration(milliseconds: 900);
const Duration _kBetweenScenes = Duration(milliseconds: 700);

/// Auto-playing tour of every animated widget. A scripted finger drives
/// each one with real pointer events, and [HapticIndicator] shows each
/// haptic as it fires, so the tour can be screen-recorded.
///
/// Each scene prints `SHOWCASE_START <id>` and `SHOWCASE_END <id>` so a
/// recording script can cut one clip per widget.
class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key, this.loop = false});

  /// Restart from the first scene after the last one.
  final bool loop;

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  final _finger = _Finger();
  final _target = GlobalKey();
  final _secondary = GlobalKey();
  late final List<_Scene> _scenes = _buildScenes();
  int _index = 0;
  int _generation = 0;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _running = false;
    _finger.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    do {
      for (var i = 0; i < _scenes.length && _running; i++) {
        setState(() {
          _index = i;
          _generation++;
        });
        final scene = _scenes[i];
        debugPrint('SHOWCASE_START ${scene.id}');
        await Future<void>.delayed(_kSceneLead);
        if (!_running) return;
        await scene.script(this);
        await Future<void>.delayed(_kSceneTail);
        debugPrint('SHOWCASE_END ${scene.id}');
        await Future<void>.delayed(_kBetweenScenes);
      }
    } while (widget.loop && _running);
    if (_running) debugPrint('SHOWCASE_DONE');
  }

  Rect _rectOf(GlobalKey key) {
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _pause(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  List<_Scene> _buildScenes() => [
        _Scene(
          id: 'bounce',
          title: 'HapticBounce',
          caption: 'Squash, recoil, elastic settle. Light tap on press, '
              'medium on release.',
          builder: (s) => HapticBounce(key: s._target, child: const _Orb()),
          script: (s) async {
            final center = s._rectOf(s._target).center;
            await s._finger.tap(center, hold: 140);
            await s._pause(900);
            await s._finger.tap(center, hold: 450);
            await s._pause(700);
          },
        ),
        _Scene(
          id: 'press_and_hold',
          title: 'PressAndHoldToConfirm',
          caption: 'Hold for 2 s. Ticks speed up and get stronger until the '
              'final heavy impact.',
          builder: (s) => _HoldScene(target: s._target),
          script: (s) async {
            final center = s._rectOf(s._target).center;
            await s._finger.down(center);
            await s._pause(2300);
            await s._finger.up();
            await s._pause(900);
          },
        ),
        _Scene(
          id: 'toggle',
          title: 'HapticToggle',
          caption: 'Spring-back thumb with a selection tick on every flip.',
          builder: (s) => _ToggleScene(target: s._target),
          script: (s) async {
            final center = s._rectOf(s._target).center;
            for (var i = 0; i < 3; i++) {
              await s._finger.tap(center);
              await s._pause(650);
            }
          },
        ),
        _Scene(
          id: 'slider',
          title: 'HapticSlider',
          caption: 'A tick at every detent, a stronger one at both ends.',
          builder: (s) => _SliderScene(target: s._target),
          script: (s) async {
            final rect = s._rectOf(s._target);
            final start = Offset(rect.left + 24, rect.center.dy);
            final end = Offset(rect.right - 24, rect.center.dy);
            await s._finger.down(start);
            await s._finger.moveTo(end, 1600);
            await s._pause(250);
            await s._finger.moveTo(Offset.lerp(start, end, 0.4)!, 900);
            await s._finger.up();
            await s._pause(400);
          },
        ),
        _Scene(
          id: 'stepper',
          title: 'HapticStepper',
          caption: 'Bouncing buttons, a sliding number and a heavy tap at '
              'the limit.',
          builder: (s) => _StepperScene(target: s._target),
          script: (s) async {
            final rect = s._rectOf(s._target);
            final minus = Offset(rect.left + 22, rect.center.dy);
            final plus = Offset(rect.right - 22, rect.center.dy);
            for (var i = 0; i < 3; i++) {
              await s._finger.tap(plus);
              await s._pause(420);
            }
            await s._finger.tap(plus);
            await s._pause(600);
            await s._finger.tap(minus);
            await s._pause(500);
          },
        ),
        _Scene(
          id: 'shake',
          title: 'HapticShake',
          caption: 'Wrong PIN: a decaying wiggle with an error notification.',
          builder: (s) => _ShakeScene(target: s._target),
          script: (s) async {
            final center = s._rectOf(s._target).center;
            await s._finger.tap(center);
            await s._pause(1300);
            await s._finger.tap(center);
            await s._pause(800);
          },
        ),
        _Scene(
          id: 'pulse',
          title: 'HapticPulse',
          caption: 'A looping, breathing pulse with a light tap on every '
              'beat.',
          builder: (s) => const _PulseScene(),
          script: (s) => s._pause(3600),
        ),
        _Scene(
          id: 'slide_to_confirm',
          title: 'SlideToConfirm',
          caption: 'Ticks at 25, 50 and 75 %, a heavy impact at the end.',
          builder: (s) => _SlideScene(target: s._target),
          script: (s) async {
            final rect = s._rectOf(s._target);
            final handle = Offset(rect.left + 32, rect.center.dy);
            final end = Offset(rect.right - 20, rect.center.dy);
            await s._finger.down(handle);
            await s._finger.moveTo(end, 1500);
            await s._pause(150);
            await s._finger.up();
            await s._pause(900);
          },
        ),
        _Scene(
          id: 'rating',
          title: 'HapticRating',
          caption: 'Stars fill one by one, with a tick for each.',
          builder: (s) => _RatingScene(target: s._target),
          script: (s) async {
            final rect = s._rectOf(s._target);
            Offset star(int i) =>
                Offset(rect.left + i * 42 + 18, rect.center.dy);
            await s._finger.tap(star(4));
            await s._pause(1100);
            await s._finger.tap(star(2));
            await s._pause(900);
          },
        ),
        _Scene(
          id: 'semantic_composition',
          title: 'Semantic + composition',
          caption: 'Haptics.semantic plays the platform signal for a UI '
              'event. HapticComposition chains primitives.',
          builder: (s) =>
              _SemanticScene(target: s._target, second: s._secondary),
          script: (s) async {
            for (final key in [s._target, s._secondary]) {
              final rect = s._rectOf(key);
              final rowY = rect.center.dy;
              final xs = [
                rect.left + rect.width * 0.25,
                rect.left + rect.width * 0.75
              ];
              for (final x in xs) {
                await s._finger.tap(Offset(x, rowY));
                await s._pause(850);
              }
            }
          },
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final scene = _scenes[_index];
    return Scaffold(
      backgroundColor: _kStageColor,
      body: Stack(
        children: [
          Center(
            child: SizedBox.fromSize(
              size: kShowcaseStage,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  children: [
                    Text(
                      scene.title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      scene.caption,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                    Expanded(
                      child: Center(
                        child: KeyedSubtree(
                          key: ValueKey(_generation),
                          child: scene.builder(this),
                        ),
                      ),
                    ),
                    const SizedBox(height: 44, child: HapticIndicator()),
                  ],
                ),
              ),
            ),
          ),
          _FingerOverlay(finger: _finger),
        ],
      ),
    );
  }
}

class _Scene {
  const _Scene({
    required this.id,
    required this.title,
    required this.caption,
    required this.builder,
    required this.script,
  });

  final String id;
  final String title;
  final String caption;
  final Widget Function(_ShowcasePageState state) builder;
  final Future<void> Function(_ShowcasePageState state) script;
}

/// A scripted touch that sends real pointer events through the gesture
/// system, so widgets react exactly as they would to a finger.
class _Finger {
  static const int _pointer = 7;
  static const Duration _frame = Duration(milliseconds: 16);

  final ValueNotifier<Offset?> position = ValueNotifier(null);
  final ValueNotifier<bool> pressed = ValueNotifier(false);
  final Stopwatch _clock = Stopwatch()..start();

  void dispose() {
    position.dispose();
    pressed.dispose();
  }

  void _dispatch(PointerEvent event) =>
      GestureBinding.instance.handlePointerEvent(event);

  Future<void> down(Offset at) async {
    position.value = at;
    pressed.value = true;
    _dispatch(
      PointerDownEvent(
        pointer: _pointer,
        position: at,
        timeStamp: _clock.elapsed,
      ),
    );
  }

  Future<void> moveTo(Offset to, int durationMs) async {
    final from = position.value!;
    final steps = (durationMs / _frame.inMilliseconds).ceil();
    var last = from;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(_frame);
      final t = Curves.easeInOut.transform(i / steps);
      final next = Offset.lerp(from, to, t)!;
      _dispatch(
        PointerMoveEvent(
          pointer: _pointer,
          position: next,
          delta: next - last,
          timeStamp: _clock.elapsed,
        ),
      );
      position.value = next;
      last = next;
    }
  }

  Future<void> up() async {
    final at = position.value!;
    pressed.value = false;
    _dispatch(
      PointerUpEvent(
        pointer: _pointer,
        position: at,
        timeStamp: _clock.elapsed,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!pressed.value) position.value = null;
  }

  Future<void> tap(Offset at, {int hold = 110}) async {
    await down(at);
    await Future<void>.delayed(Duration(milliseconds: hold));
    await up();
  }
}

class _FingerOverlay extends StatelessWidget {
  const _FingerOverlay({required this.finger});

  final _Finger finger;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<Offset?>(
        valueListenable: finger.position,
        builder: (context, at, _) {
          if (at == null) return const SizedBox.expand();
          return ValueListenableBuilder<bool>(
            valueListenable: finger.pressed,
            builder: (context, pressed, _) => Stack(
              children: [
                Positioned(
                  left: at.dx - 22,
                  top: at.dy - 22,
                  child: AnimatedScale(
                    scale: pressed ? 0.85 : 1.15,
                    duration: const Duration(milliseconds: 120),
                    child: AnimatedOpacity(
                      opacity: pressed ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.28),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// Scene bodies. Each is rebuilt fresh per scene, so state starts clean.
// ---------------------------------------------------------------------------

class _Orb extends StatelessWidget {
  const _Orb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C4DFF), Color(0xFFFF4081)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'Press me',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _HoldScene extends StatefulWidget {
  const _HoldScene({required this.target});

  final GlobalKey target;

  @override
  State<_HoldScene> createState() => _HoldSceneState();
}

class _HoldSceneState extends State<_HoldScene> {
  bool _unboxed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressAndHoldToConfirm(
          key: widget.target,
          onConfirm: () => setState(() => _unboxed = true),
          child: Container(
            width: 220,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  _unboxed ? Icons.celebration : Icons.card_giftcard,
                  key: ValueKey(_unboxed),
                  size: 88,
                  color: _unboxed ? Colors.amber : Colors.white70,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedOpacity(
          opacity: _unboxed ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Text('Unboxed!', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class _ToggleScene extends StatefulWidget {
  const _ToggleScene({required this.target});

  final GlobalKey target;

  @override
  State<_ToggleScene> createState() => _ToggleSceneState();
}

class _ToggleSceneState extends State<_ToggleScene> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _on ? 'Haptics on' : 'Haptics off',
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(width: 16),
        Transform.scale(
          scale: 1.4,
          child: HapticToggle(
            key: widget.target,
            value: _on,
            onChanged: (v) => setState(() => _on = v),
          ),
        ),
      ],
    );
  }
}

class _SliderScene extends StatefulWidget {
  const _SliderScene({required this.target});

  final GlobalKey target;

  @override
  State<_SliderScene> createState() => _SliderSceneState();
}

class _SliderSceneState extends State<_SliderScene> {
  double _value = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_value.round()}',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 320,
          child: HapticSlider(
            key: widget.target,
            value: _value,
            max: 100,
            divisions: 10,
            onChanged: (v) => setState(() => _value = v),
          ),
        ),
      ],
    );
  }
}

class _StepperScene extends StatefulWidget {
  const _StepperScene({required this.target});

  final GlobalKey target;

  @override
  State<_StepperScene> createState() => _StepperSceneState();
}

class _StepperSceneState extends State<_StepperScene> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HapticStepper(
          key: widget.target,
          value: _count,
          max: 3,
          onChanged: (v) => setState(() => _count = v),
        ),
        const SizedBox(height: 12),
        const Text('max 3', style: TextStyle(color: Colors.white38)),
      ],
    );
  }
}

class _ShakeScene extends StatefulWidget {
  const _ShakeScene({required this.target});

  final GlobalKey target;

  @override
  State<_ShakeScene> createState() => _ShakeSceneState();
}

class _ShakeSceneState extends State<_ShakeScene> {
  final _shake = GlobalKey<HapticShakeState>();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HapticShake(
          key: _shake,
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.redAccent, width: 1.5),
            ),
            child: const Text(
              '0 0 0 0',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, letterSpacing: 6),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: widget.target,
          onPressed: () => _shake.currentState?.shake(),
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}

class _PulseScene extends StatelessWidget {
  const _PulseScene();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return HapticPulse(
      maxScale: 1.12,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.2),
          border: Border.all(color: accent, width: 2),
        ),
        child: Icon(Icons.notifications_active, size: 56, color: accent),
      ),
    );
  }
}

class _SlideScene extends StatefulWidget {
  const _SlideScene({required this.target});

  final GlobalKey target;

  @override
  State<_SlideScene> createState() => _SlideSceneState();
}

class _SlideSceneState extends State<_SlideScene> {
  bool _paid = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 320,
          child: SlideToConfirm(
            key: widget.target,
            label: 'Slide to pay',
            onConfirmed: () => setState(() => _paid = true),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          opacity: _paid ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Text(
            'Paid',
            style: TextStyle(fontSize: 18, color: Colors.greenAccent),
          ),
        ),
      ],
    );
  }
}

class _RatingScene extends StatefulWidget {
  const _RatingScene({required this.target});

  final GlobalKey target;

  @override
  State<_RatingScene> createState() => _RatingSceneState();
}

class _RatingSceneState extends State<_RatingScene> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return HapticRating(
      key: widget.target,
      value: _rating,
      onChanged: (v) => setState(() => _rating = v),
    );
  }
}

class _SemanticScene extends StatelessWidget {
  const _SemanticScene({required this.target, required this.second});

  final GlobalKey target;
  final GlobalKey second;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ButtonRow(
          key: target,
          children: [
            ('toggle on', () => Haptics.semantic(SemanticHaptic.toggleOn)),
            ('confirm', () => Haptics.semantic(SemanticHaptic.confirm)),
          ],
        ),
        const SizedBox(height: 16),
        _ButtonRow(
          key: second,
          children: [
            (
              'rise + click',
              () => HapticComposition.builder()
                  .add(HapticPrimitive.slowRise, scale: 0.6)
                  .add(HapticPrimitive.click)
                  .play(),
            ),
            (
              'spin',
              () =>
                  HapticComposition.builder().add(HapticPrimitive.spin).play(),
            ),
          ],
        ),
      ],
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({super.key, required this.children});

  final List<(String, VoidCallback)> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Row(
        children: [
          for (final (label, onPressed) in children)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: FilledButton.tonal(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(label),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
