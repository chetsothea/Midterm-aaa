import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// A band of light that sweeps once across [child] (e.g. the PS168 logo).
// It plays once and stops, so screens still settle; tapping plays it again.
class Shine extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Color color;

  const Shine({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 300),
    this.color = const Color(
      0xFFFCD34D,
    ), // gold: shows clearly on the white logo
  });

  @override
  State<Shine> createState() => _ShineState();
}

class _ShineState extends State<Shine> with SingleTickerProviderStateMixin {
  static const _sweep = Duration(milliseconds: 900);

  // The delay is part of the animation (no timer), so nothing is left pending
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.delay + _sweep,
  );
  late final _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMilliseconds / (widget.delay + _sweep).inMilliseconds,
      1,
      curve: Curves.easeInOut,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // People who turned animations off see the logo as it is
    if (!MediaQuery.of(context).disableAnimations && !_controller.isAnimating) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _controller.forward(from: 0),
      child: AnimatedBuilder(
        animation: _progress,
        child: widget.child,
        builder: (context, child) {
          final t = _progress.value;
          if (t == 0 || t == 1) return child!;
          // The band travels from beyond the left edge to beyond the right edge
          final center = -0.4 + t * 1.8;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0),
                widget.color,
                Colors.white.withValues(alpha: 0),
              ],
              stops: [
                (center - 0.25).clamp(0.0, 1.0),
                center.clamp(0.0, 1.0),
                (center + 0.25).clamp(0.0, 1.0),
              ],
            ).createShader(bounds),
            child: child,
          );
        },
      ),
    );
  }
}

// Shared switches and timings, so every animation in the app moves alike.
class Motion {
  // Effects that loop (a floating picture, a pulsing badge, a title's sheen).
  // Off in widget tests (test/flutter_test_config.dart): something that never
  // stops would keep pumpAndSettle() from ever finishing.
  static bool ambient = true;

  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);

  // Springy settle for things that pop into place
  static const spring = Curves.easeOutBack;

  // The phone asked for no animations
  static bool off(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  // A looping effect may run: not in tests, not with animations turned off
  static bool loops(BuildContext context) => ambient && !off(context);
}

// Fades [child] in while it swings up out of the page in 3D (tipped back,
// lower down) and settles flat. [index] staggers a list so
// the items arrive one after another. Only paint changes, so the layout is
// final from the first frame.
class Entrance extends StatelessWidget {
  final int index;
  final Widget child;

  const Entrance({super.key, this.index = 0, required this.child});

  // Wraps each widget of a list so the whole page arrives one block at a time
  static List<Widget> stagger(List<Widget> children) => [
    for (final (i, child) in children.indexed) Entrance(index: i, child: child),
  ];

  @override
  Widget build(BuildContext context) {
    if (Motion.off(context)) return child;
    final stagger = (index.clamp(0, 6)) * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + stagger),
      curve: Interval(stagger / (520 + stagger), 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, child) {
        final rest = 1 - value;
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // perspective
              ..translateByDouble(0.0, 36 * rest, 0.0, 1.0)
              ..rotateX(0.55 * rest),
            child: child,
          ),
        );
      },
    );
  }
}

// A card that leans towards the pointer in 3D, like a real object lifted off
// the page: with a mouse it follows the cursor, with a finger it presses in
// where it is touched and springs back on release. A soft highlight follows
// the light. Taps still reach [child].
class Tilt3D extends StatefulWidget {
  final Widget child;
  final double maxAngle; // radians at the very edge
  final BorderRadius borderRadius;

  const Tilt3D({
    super.key,
    required this.child,
    this.maxAngle = 0.16,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> with SingleTickerProviderStateMixin {
  // Where the pointer is, -1..1 on each axis; (0, 0) is flat
  Offset _target = Offset.zero;
  Offset _from = Offset.zero;
  bool _pressed = false;
  bool _hovering = false;

  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  Offset get _current =>
      Offset.lerp(_from, _target, _curve.value) ?? Offset.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _aim(Offset target, {Duration? duration}) {
    _from = _current; // start from wherever it is: interruptible
    _target = target;
    _controller.duration = duration ?? Motion.medium;
    _controller.forward(from: 0);
  }

  void _aimAt(Offset local) {
    final box = context.size;
    if (box == null || box.isEmpty) return;
    _aim(
      Offset(
        (local.dx / box.width * 2 - 1).clamp(-1.0, 1.0),
        (local.dy / box.height * 2 - 1).clamp(-1.0, 1.0),
      ),
      duration: Motion.fast,
    );
  }

  void _release() {
    setState(() => _pressed = false);
    if (!_hovering) _aim(Offset.zero, duration: Motion.slow);
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.off(context)) return widget.child;
    return MouseRegion(
      onEnter: (_) => _hovering = true,
      onHover: (e) => _aimAt(e.localPosition),
      onExit: (_) {
        _hovering = false;
        _aim(Offset.zero, duration: Motion.slow);
      },
      child: Listener(
        onPointerDown: (e) {
          setState(() => _pressed = true);
          _aimAt(e.localPosition);
        },
        onPointerMove: (e) {
          if (_pressed) _aimAt(e.localPosition);
        },
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: AnimatedBuilder(
          animation: _curve,
          child: widget.child,
          builder: (context, child) {
            final p = _current;
            final lift = p.distance.clamp(0.0, 1.0);
            final scale = _pressed ? 0.97 : 1 + 0.03 * lift;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(-p.dy * widget.maxAngle)
                ..rotateY(p.dx * widget.maxAngle)
                ..scaleByDouble(scale, scale, 1.0, 1.0),
              child: Stack(
                children: [
                  child!,
                  // Glare: a soft white spot on the side tipped towards the light
                  if (lift > 0.01)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: widget.borderRadius,
                            gradient: RadialGradient(
                              center: Alignment(p.dx, p.dy),
                              radius: 1.1,
                              colors: [
                                Colors.white.withValues(alpha: 0.28 * lift),
                                Colors.white.withValues(alpha: 0),
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
      ),
    );
  }
}

// Shrinks a little while pressed and springs back: a tactile tap for buttons
// and chips. Doesn't take the tap; [child] keeps its own onTap.
class PressScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final bool haptic; // a light tick through the phone on touch

  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.haptic = true,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (Motion.off(context)) return widget.child;
    return Listener(
      onPointerDown: (_) {
        if (widget.haptic) HapticFeedback.selectionClick();
        setState(() => _down = true);
      },
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        // In quickly; out on a spring that overshoots a touch and settles
        duration: _down ? Motion.fast : Motion.slow,
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

// Pops [child] in from nothing with a springy overshoot. [index] staggers it.
class PopIn extends StatelessWidget {
  final int index;
  final Widget child;

  const PopIn({super.key, this.index = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Motion.off(context)) return child;
    final stagger = index.clamp(0, 8) * 60;
    final total = 560 + stagger;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(stagger / total, 1, curve: Curves.easeOutBack),
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY((1 - v) * -0.9)
            ..scaleByDouble(0.4 + 0.6 * v, 0.4 + 0.6 * v, 1.0, 1.0),
          child: child,
        ),
      ),
    );
  }
}

// Bobs [child] gently up and down with a slight 3D sway, like it floats.
class Floating extends StatefulWidget {
  final Widget child;
  final double height;
  final Duration period;

  const Floating({
    super.key,
    required this.child,
    this.height = 8,
    this.period = const Duration(milliseconds: 3200),
  });

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Motion.loops(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOutSine.transform(_controller.value);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..translateByDouble(0.0, -widget.height * t, 0.0, 1.0)
            ..rotateY((t - 0.5) * 0.18)
            ..rotateZ((t - 0.5) * 0.03),
          child: child,
        );
      },
    );
  }
}

// Breathes [child] (a sale badge) slightly bigger and back, to draw the eye.
class Pulse extends StatefulWidget {
  final Widget child;

  const Pulse({super.key, required this.child});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Motion.loops(context)) return widget.child;
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1.12,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

// A section title that flips up into view in 3D, then lets a gleam of light
// run across its letters every few seconds.
class MotionTitle extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<Color>? colors;

  const MotionTitle(
    this.text, {
    super.key,
    required this.style,
    this.colors, // default: the mode's text colour to the blue accent
  });

  @override
  State<MotionTitle> createState() => _MotionTitleState();
}

class _MotionTitleState extends State<MotionTitle>
    with TickerProviderStateMixin {
  // Arrival: once
  late final _enter = AnimationController(vsync: this, duration: Motion.slow);
  // Gleam: a 0.9s sweep, then a rest, repeated
  late final _gleam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.off(context)) {
      _enter.value = 1;
      return;
    }
    if (_enter.value == 0 && !_enter.isAnimating) _enter.forward();
    if (Motion.loops(context) && !_gleam.isAnimating) _gleam.repeat();
  }

  @override
  void dispose() {
    _enter.dispose();
    _gleam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      widget.text,
      maxLines: 1,
      style: widget.style.copyWith(color: Colors.white),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _gleam]),
      builder: (context, _) {
        final colors = widget.colors ?? [AppColors.text, AppColors.accent];
        final e = Curves.easeOutBack.transform(_enter.value);
        // The gleam crosses during the first ~22% of each cycle, then rests
        final g = (_gleam.value / 0.22).clamp(0.0, 1.0);
        final sweeping = g > 0 && g < 1;
        final center = -0.3 + g * 1.6;
        return Opacity(
          opacity: _enter.value,
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateX((1 - e) * 1.2)
              ..translateByDouble(0.0, 10 * (1 - e), 0.0, 1.0),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: sweeping
                    ? [
                        colors.first,
                        colors.last,
                        const Color(0xFFFCD34D),
                        colors.last,
                        colors.first,
                      ]
                    : colors,
                stops: sweeping
                    ? [
                        0,
                        (center - 0.15).clamp(0.0, 1.0),
                        center.clamp(0.0, 1.0),
                        (center + 0.15).clamp(0.0, 1.0),
                        1,
                      ]
                    : null,
              ).createShader(bounds),
              child: text,
            ),
          ),
        );
      },
    );
  }
}

// Every pushed page arrives in 3D: it swings in from the right edge like a
// door turning towards you, while the page underneath sinks back and dims.
// Set once in the theme, so every MaterialPageRoute uses it.
class Depth3DPageTransitionsBuilder extends PageTransitionsBuilder {
  const Depth3DPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 460);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 340);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.off(context)) return child;
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final behind = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([enter, behind]),
      child: child,
      builder: (context, child) {
        final t = enter.value;
        final b = behind.value;
        final width = MediaQuery.sizeOf(context).width;
        return Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0011)
            // Incoming: from the right, turned away, then flat
            ..translateByDouble(width * 0.35 * (1 - t), 0.0, 0.0, 1.0)
            ..rotateY(-0.6 * (1 - t))
            // Underneath: sinks back a little
            ..scaleByDouble(1 - 0.06 * b, 1 - 0.06 * b, 1.0, 1.0),
          child: Opacity(
            opacity: (t * 1.4).clamp(0.0, 1.0) * (1 - 0.35 * b),
            child: child,
          ),
        );
      },
    );
  }
}
