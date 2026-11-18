import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'motion.dart';
import '../theme/app_theme.dart';

// GPU-drawn effects: a living aurora behind the top bars, a pulsing "LIVE"
// dot for data that refreshes on its own, and numbers that roll when they
// change.

// Soft blobs of colour drifting slowly behind [child], blurred by the GPU into
// a moving aurora. Static (but still coloured) when animations are off.
class AuroraBackground extends StatefulWidget {
  final Widget? child;
  final Color? base;
  final List<Color> blobs;
  final BorderRadius borderRadius;

  const AuroraBackground({
    super.key,
    this.child,
    this.base, // default: near black (dark mode) or deep blue (light mode)
    this.blobs = const [
      Color(0xFF3D7BFF), // electric blue, the accent
      Color(0xFF1E3A8A), // deep blue
      Color(0xFF3D7BFF),
      Color(0xFF5B5BD6), // a whisper of violet
    ],
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_controller.isAnimating) _controller.repeat();
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
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: CustomPaint(
        painter: _AuroraPainter(
          animation: _controller,
          base:
              widget.base ??
              (AppColors.isDark
                  ? const Color(0xFF0A0A0A)
                  : const Color(0xFF1D3F9E)),
          blobs: widget.blobs,
        ),
        // Fills the space it is given (a painter with no child has no size)
        child: widget.child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> animation;
  final Color base;
  final List<Color> blobs;

  _AuroraPainter({
    required this.animation,
    required this.base,
    required this.blobs,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);
    final t = animation.value * 2 * math.pi;
    final radius = math.max(size.width, size.height) * 0.42;
    for (var i = 0; i < blobs.length; i++) {
      // Each blob circles its own spot at its own pace
      final phase = i * 1.7;
      final center = Offset(
        size.width * (0.15 + 0.7 * (i / math.max(1, blobs.length - 1))) +
            math.sin(t + phase) * size.width * 0.12,
        size.height * 0.5 + math.cos(t * 1.3 + phase) * size.height * 0.45,
      );
      canvas.drawCircle(
        center,
        radius * (0.75 + 0.15 * math.sin(t * 2 + phase)),
        Paint()
          ..color = blobs[i].withValues(
            alpha: i == blobs.length - 1 ? 0.18 : 0.32,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38),
      );
    }
    // A faint sheen across the top, like light on glass
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.base != base || old.blobs != blobs;
}

// A green dot with a ring that keeps rippling out, next to "LIVE": this data
// refreshes by itself.
class LiveDot extends StatefulWidget {
  final String label;
  final Color color;
  final Color textColor;

  const LiveDot({
    super.key,
    this.label = 'LIVE',
    this.color = const Color(0xFF22C55E),
    this.textColor = const Color(0xFF30D158),
  });

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_controller.isAnimating) _controller.repeat();
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
    return Semantics(
      label: 'Updates live',
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // The ripple
                      Container(
                        width: 6 + 8 * t,
                        height: 6 + 8 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withValues(alpha: 0.5 * (1 - t)),
                        ),
                      ),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: widget.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Text that rolls up to its new value (a stock count that just changed),
// like a ticker board.
class RollingText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  const RollingText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      key: ValueKey(text),
      maxLines: maxLines,
      overflow: overflow,
      style: style,
    );
    if (Motion.off(context)) return label;
    return AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(text);
        return ClipRect(
          child: SlideTransition(
            position: Tween(
              begin: Offset(0, incoming ? 1 : -1),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: label,
    );
  }
}
