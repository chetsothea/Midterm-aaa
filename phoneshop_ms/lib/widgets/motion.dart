import 'package:flutter/material.dart';

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

// Fades and slides [child] up into place the first time it is built.
// [index] staggers a list so the items arrive one after another.
class Entrance extends StatelessWidget {
  final int index;
  final Widget child;

  const Entrance({super.key, this.index = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final stagger = (index.clamp(0, 6)) * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + stagger),
      curve: Interval(stagger / (380 + stagger), 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
