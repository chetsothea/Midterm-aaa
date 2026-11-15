import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/motion.dart';
import 'home_screen.dart';
import '../widgets/brand_wordmark.dart';

// The first thing customers see: the logo on the shop's colours, then the store.
// The store is built underneath from the start, so its phones are already loading
// and it's ready the moment the logo fades away. No new route is opened for it: a custom
// route under the other pages crashed Device Preview's iPhones when going back to the store.
class SplashScreen extends StatefulWidget {
  final Widget next;

  const SplashScreen({super.key, this.next = const HomeScreen()});

  static const duration = Duration(seconds: 3);

  // What the shop sells, shown one after another under the name
  static const products = [
    'iPhone',
    'Samsung Galaxy',
    'OPPO',
    'HONOR',
    'vivo',
    'iPad',
  ];

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  // The product names appear one by one, after the logo has landed
  late final _products = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final _scale = Tween<double>(
    begin: 0.7,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
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

  // A soft see-through circle in the background
  static Widget _bubble(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }

  // A thin bar that fills while the store loads underneath, and the shop's name
  Widget _footer() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 56,
      child: Column(
        children: [
          SizedBox(
            width: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: SplashScreen.duration,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  color: const Color(0xFFFBBF24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'PS168 Phone Shop',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1F4D), Color(0xFF0F2A5F), Color(0xFF0E7490)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(top: -90, right: -70, child: _bubble(260, 0.06)),
            Positioned(bottom: -120, left: -90, child: _bubble(320, 0.05)),
            Positioned(top: 140, left: -40, child: _bubble(110, 0.04)),
            _footer(),
            _centre(),
          ],
        ),
      ),
    );
  }

  Widget _centre() {
    // Shrinks to fit a small phone, clear of the loading bar at the bottom
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
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
                  AnimatedBuilder(
                    animation: _ring,
                    builder: (context, _) => Container(
                      width: 120 + 90 * _ring.value,
                      height: 120 + 90 * _ring.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: 0.35 * (1 - _ring.value),
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // The app icon itself (it has its own rounded tile), with a thin
                  // light edge so its navy doesn't melt into the navy background
                  Container(
                    width: 120,
                    height: 120,
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white70, width: 2),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      // A cyan glow behind the icon, and its shadow
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 40,
                          spreadRadius: 4,
                          color: Color(0x6622D3EE),
                        ),
                        BoxShadow(
                          blurRadius: 24,
                          color: Color(0x55000000),
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Image.asset('assets/images/logo.png'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SlideTransition(
                position: _textSlide,
                child: Shine(
                  delay: const Duration(milliseconds: 150),
                  child: const BrandWordmark(height: 34),
                ),
              ),
              const SizedBox(height: 10),
              SlideTransition(
                position: _textSlide,
                child: const Text(
                  'ទូរស័ព្ទថ្មី និងមួយទឹក • តម្លៃល្អ',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              const SizedBox(height: 28),
              _productList(),
            ],
          ),
        ),
      ),
    );
  }

  // "ផលិតផលរបស់យើង" and a pill for each product, each fading and rising in turn
  Widget _productList() {
    final count = SplashScreen.products.length;
    return SizedBox(
      width: 300,
      child: Column(
        children: [
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _products,
              curve: const Interval(0, 0.3),
            ),
            child: const Text(
              'ផលិតផលរបស់យើង',
              style: TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < count; i++)
                _productPill(
                  SplashScreen.products[i],
                  CurvedAnimation(
                    parent: _products,
                    curve: Interval(
                      0.1 + 0.8 * i / count,
                      (0.1 + 0.8 * (i + 1) / count).clamp(0, 1),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _productPill(String name, Animation<double> appear) {
    return FadeTransition(
      opacity: appear,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ).animate(appear),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                name == 'iPad' ? Icons.tablet_mac : Icons.smartphone,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 5),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
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
