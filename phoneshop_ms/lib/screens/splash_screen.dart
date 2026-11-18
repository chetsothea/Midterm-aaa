import 'dart:async';
import 'package:flutter/material.dart';
import '../components/motion.dart';
import 'home_screen.dart';
import '../theme/theme.dart';
import '../components/brand_wordmark.dart';
import '../components/effects.dart';
import 'package:flutter_svg/flutter_svg.dart';

// The first thing customers see: the logo on the shop's colours, then the store.
// The store is built underneath from the start, so its phones are already loading
// and it's ready the moment the logo fades away. No new route is opened for it: a custom
// route under the other pages crashed Device Preview's iPhones when going back to the store.
class SplashScreen extends StatefulWidget {
  final Widget next;

  const SplashScreen({super.key, this.next = const HomeScreen()});

  static const duration = Duration(seconds: 3);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  // The phone icon spins in on its vertical axis in 3D and lands facing you
  late final _spin = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.8, curve: Curves.easeOutBack),
  );
  // The brand logos fade in after the logo has landed
  late final _products = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final _scale = Tween<double>(begin: 0.7, end: 1).animate(
    // A real spring: overshoots, wobbles, settles
    CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
  );
  // A soft ring that spreads out behind the logo
  late final _ring = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  // The name rises in just after the logo
  late final _textSlide =
      Tween<Offset>(begin: const Offset(0, 0.8), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
        ),
      );
  Timer? _timer;
  bool _fading = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _products.forward();
    });
    _timer = Timer(SplashScreen.duration, () {
      setState(() {
        _fading = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _products.dispose();
    super.dispose();
  }

  // A thin blue line that fills while the store loads underneath, and the
  // shop's name, clear of the home indicator
  Widget _footer() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
      child: Column(
        children: [
          Container(
            width: 120,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withValues(alpha: 0.12),
            ),
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: SplashScreen.duration,
              curve: Curves.easeInOutCubic,
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: AppColors.accent,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.7),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'PS168 Phone Shop',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: AuroraBackground(
        // A dim, slow aurora: atmosphere, not decoration
        blobs: const [
          Color(0xFF1E3A8A),
          Color(0xFF3D7BFF),
          Color(0xFF1E40AF),
          Color(0xFF312E81),
        ],
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A blue spotlight behind the logo
            Center(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.28),
                      AppColors.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            _footer(),
            _centre(),
          ],
        ),
      ),
    );
  }

  Widget _centre() {
    // Shrinks to fit a small phone, clear of the loading line at the bottom
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        96,
      ),
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: _centreContent()),
      ),
    );
  }

  Widget _centreContent() {
    return Center(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // A blue ring that spreads out once as the logo lands
                  AnimatedBuilder(
                    animation: _ring,
                    builder: (context, _) => Container(
                      width: 120 + 100 * _ring.value,
                      height: 120 + 100 * _ring.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accent.withValues(
                            alpha: 0.5 * (1 - _ring.value),
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  // The app icon spins in on its vertical axis in 3D
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, child) {
                      final rest = 1 - _spin.value;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateY(rest * 4.2) // about 1⅓ turns
                          ..rotateX(rest * 0.5),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 112,
                      height: 112,
                      // A hairline glass edge and a blue glow, like the cards
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sheet),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1.5,
                        ),
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sheet),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 48,
                            spreadRadius: 2,
                            color: AppColors.accent.withValues(alpha: 0.45),
                          ),
                          const BoxShadow(
                            blurRadius: 24,
                            color: Color(0x80000000),
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/images/logo.png'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SlideTransition(
                position: _textSlide,
                child: Shine(
                  delay: const Duration(milliseconds: 150),
                  child: const BrandWordmark(height: 36),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SlideTransition(
                position: _textSlide,
                child: Text(
                  'ទូរស័ព្ទថ្មី និងមួយទឹក • តម្លៃល្អ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _products,
                  curve: Curves.easeOut,
                ),
                child: const _BrandMarquee(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.next,
        if (!_done)
          AnimatedOpacity(
            opacity: _fading ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            onEnd: () => setState(() {
              _done = true;
            }),
            child: _logo(),
          ),
      ],
    );
  }
}

// The brands the shop sells, as their real logos in soft white, drifting
// slowly sideways and fading out at both edges. Plain marks, not buttons:
// nothing here looks tappable. Still (and centred) when animations are off.
class _BrandMarquee extends StatefulWidget {
  const _BrandMarquee();

  static const _logos = [
    // The files are square icons; wordmarks are a thin strip across the
    // middle, so they get a bigger square to look as big as the symbols
    ('assets/images/brands/apple.svg', 22.0),
    ('assets/images/brands/samsung.svg', 64.0),
    ('assets/images/brands/oppo.svg', 50.0),
    ('assets/images/brands/honor.svg', 58.0),
    ('assets/images/brands/vivo.svg', 46.0),
    ('assets/images/brands/xiaomi.svg', 22.0),
  ];

  @override
  State<_BrandMarquee> createState() => _BrandMarqueeState();
}

class _BrandMarqueeState extends State<_BrandMarquee>
    with SingleTickerProviderStateMixin {
  static const _gap = 28.0;
  static const _width = 280.0;

  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  Widget _row() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (asset, width) in _BrandMarquee._logos)
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SvgPicture.asset(
            asset,
            width: width,
            height: width,
            colorFilter: ColorFilter.mode(
              Colors.white.withValues(alpha: 0.6),
              BlendMode.srcIn,
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // One full set of logos, end to end
    final setWidth = _BrandMarquee._logos.fold<double>(
      0,
      (sum, logo) => sum + logo.$2 + _gap,
    );
    return Semantics(
      label: 'Apple, Samsung, OPPO, HONOR, vivo, Xiaomi',
      child: SizedBox(
        width: _width,
        height: 32,
        child: ShaderMask(
          // Soft edges: logos fade in on the right and out on the left
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, 0.18, 0.82, 1],
          ).createShader(r),
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, child) => OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Transform.translate(
                  offset: Offset(
                    Motion.loops(context)
                        ? -_drift.value * setWidth
                        : (_width - setWidth) / 2,
                    0,
                  ),
                  child: child,
                ),
              ),
              // Two sets back to back, so the row never runs out
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [_row(), _row()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
