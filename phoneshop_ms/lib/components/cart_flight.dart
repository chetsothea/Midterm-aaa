import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../hooks/cart.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'motion.dart';
import 'ux.dart';

// "Add to cart" made visible: a round thumbnail of the phone lifts off its
// picture, arcs over the page and drops into the cart icon in the bottom
// menu, which then bounces its number.
//
// A card calls [prepare] with its picture just before adding; the flight only
// starts if the cart really grows within a moment (not when stock ran out or
// the customer had to log in first), and only when the cart icon is on screen.
class CartFlight {
  // Put on the cart icon the thumbnail flies to (the bottom menu's)
  static final target = GlobalKey(debugLabel: 'cart-flight-target');

  static BuildContext? _from;
  static String _url = '';
  static int _countBefore = 0;
  static Timer? _expire;

  static void prepare(BuildContext from, String imageUrl) {
    _from = from;
    _url = imageUrl;
    _countBefore = Cart.instance.count;
    Cart.instance.removeListener(_onCart);
    Cart.instance.addListener(_onCart);
    _expire?.cancel();
    // Long enough for the add itself, not for a login detour
    _expire = Timer(const Duration(milliseconds: 1500), _reset);
  }

  static void _reset() {
    Cart.instance.removeListener(_onCart);
    _expire?.cancel();
    _from = null;
  }

  static void _onCart() {
    final from = _from;
    if (Cart.instance.count <= _countBefore || from == null) return;
    _reset();
    // After this frame, once the badge's new number is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) => _fly(from, _url));
  }

  static void _fly(BuildContext from, String url) {
    final targetContext = target.currentContext;
    if (!from.mounted ||
        targetContext == null ||
        !targetContext.mounted ||
        Motion.off(from) ||
        // The cart icon belongs to a page that is covered right now
        ModalRoute.of(targetContext)?.isCurrent == false) {
      return;
    }
    final overlay = Overlay.maybeOf(from, rootOverlay: true);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    final fromBox = from.findRenderObject() as RenderBox?;
    final toBox = targetContext.findRenderObject() as RenderBox?;
    if (overlay == null ||
        overlayBox == null ||
        fromBox == null ||
        toBox == null ||
        !fromBox.hasSize ||
        !toBox.hasSize) {
      return;
    }
    Offset centre(RenderBox box) => overlayBox.globalToLocal(
      box.localToGlobal(box.size.center(Offset.zero)),
    );
    final start = centre(fromBox);
    final end = centre(toBox);
    final size = math.min(fromBox.size.shortestSide * 0.6, 110.0);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Flight(
        start: start,
        end: end,
        size: size,
        url: url,
        onDone: () {
          entry.remove();
          Haptics.success();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _Flight extends StatelessWidget {
  final Offset start, end;
  final double size;
  final String url;
  final VoidCallback onDone;

  const _Flight({
    required this.start,
    required this.end,
    required this.size,
    required this.url,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    // The arc's peak: above both ends, so it rises before it drops in
    final peak = Offset(
      (start.dx + end.dx) / 2,
      math.min(start.dy, end.dy) - 140,
    );
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeInOutCubic,
        onEnd: onDone,
        builder: (context, t, child) {
          // Quadratic Bézier: start -> peak -> cart icon
          final p =
              start * ((1 - t) * (1 - t)) +
              peak * (2 * (1 - t) * t) +
              end * (t * t);
          final s = size + (26 - size) * t;
          return Stack(
            children: [
              Positioned(
                left: p.dx - s / 2,
                top: p.dy - s / 2,
                width: s,
                height: s,
                child: Opacity(
                  opacity: t < 0.85 ? 1 : (1 - (t - 0.85) / 0.15),
                  child: Transform.rotate(angle: t * 0.9, child: child),
                ),
              ),
            ],
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.45),
                blurRadius: 18,
              ),
            ],
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FittedBox(child: PhoneImage(url: url, size: 80)),
            ),
          ),
        ),
      ),
    );
  }
}
