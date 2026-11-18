import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../data/models/phone.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'motion.dart';
import 'ux.dart';

// The big card at the top of the store: a headline on the left and the
// shop's flagship phone on the right, slowly turning in 3D on a blue glow.
// Tapping anywhere opens that phone.
class HeroPhoneCard extends StatelessWidget {
  final Phone phone;
  final VoidCallback onOpen;
  final Object? heroTag; // the picture flies from here to the detail page
  final int rank; // 1 = best seller
  final int sold; // units sold; 0 = featured (no sales yet)

  const HeroPhoneCard({
    super.key,
    required this.phone,
    required this.onOpen,
    this.heroTag,
    this.rank = 1,
    this.sold = 0,
  });

  // The phone to show: the most expensive one in stock that has a picture
  static Phone? pickFlagship(List<Phone> phones) {
    final candidates = phones.where((p) => p.stock > 0).toList()
      ..sort((a, b) {
        final pictures = (b.imageUrl.isNotEmpty ? 1 : 0).compareTo(
          a.imageUrl.isNotEmpty ? 1 : 0,
        );
        return pictures != 0 ? pictures : b.price.compareTo(a.price);
      });
    return candidates.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.97,
      child: GestureDetector(
        onTap: () {
          Haptics.tap();
          onOpen();
        },
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: AppColors.glassEdge),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surface, AppColors.tileLower],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Blue glow behind the phone
              Positioned(
                right: -40,
                top: -20,
                bottom: -20,
                width: 240,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.35),
                        AppColors.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    flex: 11,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 4, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // "#1 Best seller · 12 sold", or "Featured" while
                          // a phone has no sales yet
                          Container(
                            padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
                            decoration: BoxDecoration(
                              color:
                                  (sold > 0
                                          ? const Color(0xFFFF9F0A)
                                          : AppColors.accent)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  sold > 0
                                      ? Icons.emoji_events_rounded
                                      : Icons.auto_awesome_rounded,
                                  size: 13,
                                  color: sold > 0
                                      ? const Color(0xFFFF9F0A)
                                      : AppColors.accent,
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                Flexible(
                                  child: Text(
                                    sold > 0
                                        ? trf(
                                            '#$rank លក់ដាច់ · លក់បាន $sold',
                                            '#$rank best seller · $sold sold',
                                          )
                                        : trf('ពិសេស', 'Featured'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: sold > 0
                                          ? const Color(0xFFFF9F0A)
                                          : AppColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            phone.brand.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: Text(
                              phone.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            money(phone.price).replaceFirst('.00', ''),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: phone.hasDiscount
                                  ? AppColors.red
                                  : AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  trf('មើលឥឡូវ', 'Shop now'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 9,
                    child: _TurningPhone(url: phone.imageUrl, heroTag: heroTag),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The flagship turning slowly back and forth in 3D, with its floor shadow
class _TurningPhone extends StatefulWidget {
  final String url;
  final Object? heroTag;

  const _TurningPhone({required this.url, this.heroTag});

  @override
  State<_TurningPhone> createState() => _TurningPhoneState();
}

class _TurningPhoneState extends State<_TurningPhone>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
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
    final image = PhoneImage(url: widget.url, size: 150);
    final tag = widget.heroTag;
    final picture = tag == null ? image : Hero(tag: tag, child: image);
    return AnimatedBuilder(
      animation: _controller,
      child: picture,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        final turn = Motion.loops(context) ? math.sin(t) * 0.6 : -0.25;
        final bob = Motion.loops(context) ? math.sin(t * 2) * 4 : 0.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 18,
              child: Transform.translate(
                offset: Offset(-turn * 24, 0),
                child: Container(
                  width: 96 * (1 + turn.abs() * 0.2),
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(60, 6),
                    ),
                    gradient: RadialGradient(
                      colors: [AppColors.shadowStrong, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018)
                ..translateByDouble(0.0, -bob - 6, 0.0, 1.0)
                ..rotateY(turn)
                ..rotateZ(-0.06),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

// The top of the store: the best sellers one after another, each turning in
// 3D. Slides by itself every few seconds (pausing while a finger is on it),
// can be swiped, and the cards turn on their edge as they slide past.
class HeroCarousel extends StatefulWidget {
  final List<(Phone, int)> phones; // (phone, units sold), best first
  final void Function(Phone phone) onOpen;

  const HeroCarousel({super.key, required this.phones, required this.onOpen});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    // Not in tests or with animations off (Motion.loops); one phone: nothing to slide
    if (!Motion.loops(context) || widget.phones.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients || !TickerMode.valuesOf(context).enabled) {
        return;
      }
      _controller.animateToPage(
        (_page + 1) % widget.phones.length,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phones = widget.phones;
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: Listener(
            // A finger on it pauses the sliding; it starts again after
            onPointerDown: (_) => _timer?.cancel(),
            onPointerUp: (_) => _restart(),
            child: PageView.builder(
              controller: _controller,
              itemCount: phones.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final (phone, sold) = phones[i];
                final card = HeroPhoneCard(
                  phone: phone,
                  rank: i + 1,
                  sold: sold,
                  heroTag: 'phone-hero-${phone.id}',
                  onOpen: () => widget.onOpen(phone),
                );
                // Cover-flow: the card turns on its edge while sliding
                return AnimatedBuilder(
                  animation: _controller,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: card,
                  ),
                  builder: (context, child) {
                    if (Motion.off(context) ||
                        !_controller.hasClients ||
                        !_controller.position.haveDimensions) {
                      return child!;
                    }
                    final delta = ((_controller.page ?? 0) - i).clamp(
                      -1.0,
                      1.0,
                    );
                    return Transform(
                      alignment: delta > 0
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(delta * 0.6)
                        ..scaleByDouble(
                          1 - 0.08 * delta.abs(),
                          1 - 0.08 * delta.abs(),
                          1.0,
                          1.0,
                        ),
                      child: Opacity(
                        opacity: (1 - delta.abs() * 0.5).clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (phones.length > 1) ...[
          const SizedBox(height: 10),
          // Which slide: the current one is a longer blue bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < phones.length; i++)
                AnimatedContainer(
                  duration: Motion.medium,
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.accent : AppColors.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
