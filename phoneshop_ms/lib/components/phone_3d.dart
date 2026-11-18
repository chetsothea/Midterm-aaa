import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../hooks/language.dart';
import 'motion.dart';
import '../theme/theme.dart';
import 'ux.dart';

// The phone on the detail page as an object you can turn: drag sideways and
// it rotates in real perspective (up to ~55° each way, leaning back a little), the light moves across it, and its shadow on the "floor" slides the
// other way. Let go and it springs back to face you. When idle it sways
// gently, like it stands on a slowly turning display stand.
class Phone3DViewer extends StatefulWidget {
  final Widget child; // the phone picture
  final double height;

  const Phone3DViewer({super.key, required this.child, this.height = 230});

  @override
  State<Phone3DViewer> createState() => _Phone3DViewerState();
}

class _Phone3DViewerState extends State<Phone3DViewer>
    with TickerProviderStateMixin {
  static const _maxY = 0.95; // radians left / right
  static const _maxX = 0.35; // radians up / down

  // Where the finger has turned it to
  double _y = 0;
  double _x = 0;
  bool _dragging = false;
  // Zoom: pinch with two fingers, or double-tap to jump between 1x and 2x
  double _zoom = 1;
  double _pinchStartZoom = 1;
  double? _pinchStartDistance;
  final Map<int, Offset> _pointers = {};

  void _pointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      final p = _pointers.values.toList();
      _pinchStartDistance = (p[0] - p[1]).distance;
      _pinchStartZoom = _zoom;
    }
  }

  void _pointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _pinchStartDistance;
    if (_pointers.length == 2 && start != null && start > 0) {
      final p = _pointers.values.toList();
      setState(() {
        _zoom = (_pinchStartZoom * (p[0] - p[1]).distance / start).clamp(
          1.0,
          2.5,
        );
        _turnedOnce = true;
      });
    }
  }

  void _pointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStartDistance = null;
  }

  void _toggleZoom() {
    Haptics.tap();
    setState(() {
      _zoom = _zoom > 1.2 ? 1 : 2;
      _turnedOnce = true;
    });
  }

  bool _turnedOnce =
      false; // the "drag to rotate" hint goes after the first turn

  // Springs it back to the front after a drag
  late final AnimationController _spring = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => setState(() => _y = _spring.value));
  late final AnimationController _springX = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => setState(() => _x = _springX.value));

  // The idle sway
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  static const _springDesc = SpringDescription(
    mass: 1,
    stiffness: 120,
    damping: 11, // a little under-damped: it overshoots once, like a real stand
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_idle.isAnimating) _idle.repeat();
    } else {
      _idle.stop();
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    _springX.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails _) {
    _spring.stop();
    _springX.stop();
    setState(() {
      _dragging = true;
      _turnedOnce = true;
    });
    Haptics.tap();
  }

  void _onUpdate(DragUpdateDetails d) {
    setState(() {
      _y = (_y + d.delta.dx * 0.012).clamp(-_maxY, _maxY);
      // Leans back a little the further it turns, so it reads as 3D
      _x = (-_y.abs() * 0.15).clamp(-_maxX, _maxX);
    });
  }

  void _onEnd(DragEndDetails d) {
    setState(() => _dragging = false);
    final vy = d.velocity.pixelsPerSecond.dx * 0.012;
    const vx = 0.0;
    _spring.animateWith(SpringSimulation(_springDesc, _y, 0, vy));
    _springX.animateWith(SpringSimulation(_springDesc, _x, 0, vx));
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.off(context)) {
      return SizedBox(
        height: widget.height,
        child: Center(child: widget.child),
      );
    }
    // A Listener (not a gesture) follows the two pinching fingers, so a
    // single finger still scrolls the page and turns the phone
    return Listener(
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerUp,
      onPointerCancel: _pointerUp,
      child: GestureDetector(
        onDoubleTap: _toggleZoom,
        // Sideways only, so dragging up and down still scrolls the page
        onHorizontalDragStart: _onStart,
        onHorizontalDragUpdate: _onUpdate,
        onHorizontalDragEnd: _onEnd,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _idle,
            builder: (context, _) {
              // Idle sway only while nobody is turning it and it has settled
              final settled = !_dragging && !_spring.isAnimating;
              final sway = settled && _idle.isAnimating
                  ? math.sin(_idle.value * 2 * math.pi) * 0.28
                  : 0.0;
              final bob = settled && _idle.isAnimating
                  ? math.sin(_idle.value * 4 * math.pi) * 5
                  : 0.0;
              final y = _y + sway;
              final x = _x;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Shadow on the floor: stretches and slides opposite the turn,
                  // shrinks while the phone bobs up
                  Positioned(
                    bottom: 6,
                    child: Transform.translate(
                      offset: Offset(-y * 40, 0),
                      child: Container(
                        width: 150 * (1 + y.abs() * 0.25) - bob * 2,
                        height: 18,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(
                            Radius.elliptical(90, 9),
                          ),
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF101318).withValues(alpha: 0.26),
                              const Color(0xFF101318).withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0016)
                      ..translateByDouble(0.0, -bob, 0.0, 1.0)
                      ..rotateX(x)
                      ..rotateY(y)
                      ..scaleByDouble(
                        (_dragging ? 1.06 : 1.0) * _zoom,
                        (_dragging ? 1.06 : 1.0) * _zoom,
                        1.0,
                        1.0,
                      ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        widget.child,
                        // A band of light that slides across as it turns
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ShaderMask(
                              blendMode: BlendMode.dstIn,
                              shaderCallback: (r) => const RadialGradient(
                                colors: [Colors.white, Colors.transparent],
                              ).createShader(r),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment(-1 + y * 2, -1),
                                    end: Alignment(1 + y * 2, 1),
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: 0.35),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                    stops: const [0.35, 0.5, 0.65],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // "Drag to rotate", until the first turn
                  Positioned(
                    bottom: 26,
                    child: AnimatedOpacity(
                      opacity: _turnedOnce ? 0 : 1,
                      duration: Motion.medium,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC1C1C1F),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.threesixty_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              trf(
                                'អូសដើម្បីបង្វិល · ចុចពីរដងដើម្បីពង្រីក',
                                'Drag to rotate · double-tap to zoom',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
