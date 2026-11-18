import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../hooks/language.dart';
import '../theme/theme.dart';
import 'motion.dart';

// The moment an order goes through: the screen dims, a green circle springs
// in, a check mark draws itself, confetti bursts out with a firm haptic, and
// the order number shows with what happens next. It sits over whatever page
// opens underneath and fades away by itself (or with a tap).
void celebrateOrder(
  BuildContext context, {
  required String orderRef,
  required bool payNow, // KHQR: payment is the next step
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Celebration(
      orderRef: orderRef,
      payNow: payNow,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _Celebration extends StatefulWidget {
  final String orderRef;
  final bool payNow;
  final VoidCallback onDone;

  const _Celebration({
    required this.orderRef,
    required this.payNow,
    required this.onDone,
  });

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  // One timeline: in (0–0.15), check draws (0.15–0.4), confetti (0.3–0.9),
  // hold, then fade out (0.85–1)
  late final _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final List<_Piece> _pieces = _Piece.burst(70);
  bool _buzzed = false;

  @override
  void initState() {
    super.initState();
    _t.addListener(() {
      if (!_buzzed && _t.value > 0.38) {
        _buzzed = true;
        HapticFeedback.heavyImpact();
      }
    });
    _t.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  // Tap: skip ahead to the fade out
  void _skip() {
    if (_t.value < 0.85) _t.forward(from: 0.85);
  }

  double _phase(double from, double to) =>
      ((_t.value - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final still = Motion.off(context);
    return GestureDetector(
      onTap: _skip,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final appear = still ? 1.0 : _phase(0, 0.15);
          final fade = 1 - _phase(0.85, 1);
          final check = still ? 1.0 : _phase(0.15, 0.4);
          final circle = still
              ? 1.0
              : Curves.elasticOut.transform(_phase(0.02, 0.35));
          return Opacity(
            opacity: (appear * fade).clamp(0.0, 1.0),
            child: Stack(
              children: [
                // Dim the page underneath
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
                if (!still)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ConfettiPainter(
                        pieces: _pieces,
                        t: _phase(0.3, 0.95),
                      ),
                    ),
                  ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: circle,
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.green,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.green.withValues(alpha: 0.5),
                                blurRadius: 36,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: _CheckPainter(progress: check),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Opacity(
                        opacity: _phase(0.3, 0.45),
                        child: Column(
                          children: [
                            Text(
                              trf('បញ្ជាទិញជោគជ័យ!', 'Order placed!'),
                              style: AppText.headline.copyWith(
                                color: Colors.white,
                                fontFamily: appFontFamily,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Order ${widget.orderRef}',
                              style: const TextStyle(
                                fontFamily: appFontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              widget.payNow
                                  ? trf(
                                      'បន្ទាប់៖ បង់ប្រាក់តាម KHQR',
                                      'Next: pay with KHQR',
                                    )
                                  : trf(
                                      'បង់ប្រាក់ពេលទទួលទំនិញ',
                                      'Pay when it arrives',
                                    ),
                              style: const TextStyle(
                                fontFamily: appFontFamily,
                                fontSize: 14,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

// The white check mark, drawn stroke by stroke as [progress] goes 0 -> 1
class _CheckPainter extends CustomPainter {
  final double progress;

  _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.73, size.height * 0.36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

// One scrap of confetti: where it flies, how it spins, its colour and shape
class _Piece {
  final double angle, speed, spin, size;
  final Color color;
  final bool round;

  _Piece(this.angle, this.speed, this.spin, this.size, this.color, this.round);

  static const _colors = [
    Color(0xFF3D7BFF),
    Color(0xFF30D158),
    Color(0xFFFFD60A),
    Color(0xFFFF453A),
    Color(0xFFBF5AF2),
    Colors.white,
  ];

  static List<_Piece> burst(int count) {
    final r = math.Random();
    return [
      for (var i = 0; i < count; i++)
        _Piece(
          // Mostly upwards, fanning out
          -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.4,
          0.5 + r.nextDouble() * 0.7,
          (r.nextDouble() - 0.5) * 14,
          5 + r.nextDouble() * 6,
          _colors[r.nextInt(_colors.length)],
          r.nextBool(),
        ),
    ];
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t; // 0..1 through the burst

  _ConfettiPainter({required this.pieces, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final origin = Offset(size.width / 2, size.height / 2 - 40);
    final reach = size.shortestSide * 0.75;
    for (final p in pieces) {
      // Shoots out fast, slows down, then gravity pulls it down
      final travel = Curves.easeOutCubic.transform(t) * reach * p.speed;
      final pos =
          origin +
          Offset(math.cos(p.angle), math.sin(p.angle)) * travel +
          Offset(0, t * t * size.height * 0.45);
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
