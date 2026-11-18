import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'motion.dart';
import 'ux.dart';

// Pull-to-refresh in the shop's own style instead of the plain spinner: as
// you pull, a glass bubble drops in with a phone that turns in 3D and a blue
// ring that fills. Once the ring is full, letting go refreshes, and the phone
// keeps flipping until the new data has arrived.
class ShopRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const ShopRefresh({super.key, required this.onRefresh, required this.child});

  @override
  State<ShopRefresh> createState() => _ShopRefreshState();
}

class _ShopRefreshState extends State<ShopRefresh>
    with SingleTickerProviderStateMixin {
  static const _reach = 110.0; // pixels of pull for a full ring

  double _pull = 0; // 0..1
  bool _armed = false;
  bool _refreshing = false;
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  // Follows the finger: overscroll past the top (clamping lists) or the
  // bounce (iOS-style lists) both count as pulling
  bool _onScroll(ScrollNotification n) {
    if (_refreshing || n.depth != 0) return false;
    double? pulled;
    if (n is OverscrollNotification &&
        n.overscroll < 0 &&
        n.dragDetails != null) {
      pulled = _pull * _reach - n.overscroll;
    } else if (n is ScrollUpdateNotification && n.metrics.pixels < 0) {
      pulled = -n.metrics.pixels;
    } else if (n is ScrollEndNotification ||
        (n is ScrollUpdateNotification && n.metrics.pixels > 0)) {
      pulled = 0;
    }
    if (pulled != null) {
      final next = (pulled / _reach).clamp(0.0, 1.0);
      if (next != _pull) setState(() => _pull = next);
    }
    return false;
  }

  Future<void> _run() async {
    Haptics.success();
    setState(() {
      _refreshing = true;
      _pull = 1;
    });
    if (!Motion.off(context)) _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      _spin.stop();
      if (mounted) {
        setState(() {
          _refreshing = false;
          _pull = 0;
          _armed = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _refreshing ? 1.0 : _pull;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: RefreshIndicator.noSpinner(
            onRefresh: _run,
            onStatusChange: (status) {
              final armed = status == RefreshIndicatorStatus.armed;
              if (armed && !_armed) Haptics.tap(); // "let go now"
              if (armed != _armed) setState(() => _armed = armed);
            },
            child: widget.child,
          ),
        ),
        // The bubble, sliding down from above the list
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, -56 + 72 * shown),
                child: Opacity(
                  opacity: shown.clamp(0.0, 1.0),
                  child: _bubble(shown),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(double shown) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.glassEdge),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25 * shown),
            blurRadius: 18,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The ring fills with the pull
          SizedBox(
            width: 40,
            height: 40,
            child: CustomPaint(
              painter: _Ring(
                progress: _refreshing ? 1 : _pull,
                color: _armed || _refreshing
                    ? AppColors.accent
                    : AppColors.muted,
              ),
            ),
          ),
          // The phone turns with the pull, then flips round while loading
          AnimatedBuilder(
            animation: _spin,
            builder: (context, child) {
              final angle = _refreshing
                  ? _spin.value * 2 * math.pi
                  : _pull * math.pi;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.003)
                  ..rotateY(angle),
                child: child,
              );
            },
            child: Icon(
              Icons.smartphone_rounded,
              size: 20,
              color: _armed || _refreshing ? AppColors.accent : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends CustomPainter {
  final double progress;
  final Color color;

  _Ring({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(1.5),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.progress != progress || old.color != color;
}
