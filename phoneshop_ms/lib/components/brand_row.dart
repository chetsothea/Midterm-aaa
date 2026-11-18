import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'motion.dart';
import '../theme/app_theme.dart';

// Bundled logo files, their width in the circle, and the circle's colour. Apple's is a
// symbol and the others are wide wordmarks, so they need different sizes to look balanced.
const _logos = {
  'apple': ('assets/images/brands/apple.svg', 30.0, Color(0xFF1D1D1F)),
  'samsung': ('assets/images/brands/samsung.svg', 48.0, Color(0xFF1428A0)),
  'oppo': ('assets/images/brands/oppo.svg', 44.0, Color(0xFF008A4B)),
  'honor': ('assets/images/brands/honor.svg', 46.0, Color(0xFF6D28D9)),
  'vivo': ('assets/images/brands/vivo.svg', 44.0, Color(0xFF415FFF)),
  // A rounded square with "mi" cut out, so the orange shows through the letters
  'xiaomi': ('assets/images/brands/xiaomi.svg', 32.0, Color(0xFFFF6900)),
};

// A brand without its own colour
const _otherBrand = Color(0xFF3D7BFF);

// The circle's colour for a brand
Color brandColor(String brand) =>
    _logos[brand.trim().toLowerCase()]?.$3 ?? _otherBrand;

// Shortcut under the banner: one tap on a brand instead of opening the side menu.
// Only brands that have products, from GET /api/menu. A brand without a logo file
// shows its first letter.
//
// When the brands don't all fit, the row drifts slowly to the left and wraps around
// for ever. A finger on it pauses the drift; it picks up again a moment after.
class BrandRow extends StatefulWidget {
  final List<String> brands;
  final ValueChanged<String> onSelected;

  const BrandRow({super.key, required this.brands, required this.onSelected});

  // Off in widget tests (test/flutter_test_config.dart): a row that never stops
  // moving would keep tests from ever settling
  static bool autoScroll = true;

  static const _itemWidth = 72.0;
  static const _gap = 8.0;
  static const _speed = 28.0; // pixels per second

  @override
  State<BrandRow> createState() => _BrandRowState();
}

class _BrandRowState extends State<BrandRow>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  bool _held = false; // a finger is on the row
  DateTime _resumeAt = DateTime(0);

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_held || DateTime.now().isBefore(_resumeAt) || !_scroll.hasClients) {
      return;
    }
    _scroll.jumpTo(_scroll.offset + BrandRow._speed * dt);
  }

  void _setMoving(bool moving) {
    if (moving && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!moving && _ticker.isActive) {
      _ticker.stop();
    }
  }

  Widget _mark(String brand) {
    final logo = _logos[brand.trim().toLowerCase()];
    if (logo == null) {
      return Text(
        brand.characters.first.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    return SvgPicture.asset(
      logo.$1,
      width: logo.$2,
      height: logo.$2,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      semanticsLabel: brand,
    );
  }

  // Each logo pops in turn when the row appears, and squeezes when pressed
  Widget _item(String brand, int index) {
    return PopIn(
      index: index,
      child: PressScale(child: _logoButton(brand)),
    );
  }

  Widget _logoButton(String brand) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => widget.onSelected(brand),
      child: SizedBox(
        width: BrandRow._itemWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The brand's colour with a light sheen at the top, a white ring
            // and a soft glow of the same colour underneath
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(brandColor(brand), Colors.white, 0.18)!,
                    brandColor(brand),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: brandColor(brand).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _mark(brand),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brands = widget.brands;
    return SizedBox(
      height: 92,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final needed =
              brands.length * (BrandRow._itemWidth + BrandRow._gap) + 24;
          final moving =
              BrandRow.autoScroll &&
              !MediaQuery.of(context).disableAnimations &&
              needed > constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _setMoving(moving);
          });
          return Listener(
            onPointerDown: (_) => _held = true,
            onPointerUp: (_) => _letGo(),
            onPointerCancel: (_) => _letGo(),
            child: ListView.builder(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              // Moving: the brands repeat without end, so the row never runs out
              itemCount: moving ? null : brands.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: BrandRow._gap),
                child: _item(brands[index % brands.length], index),
              ),
            ),
          );
        },
      ),
    );
  }

  void _letGo() {
    _held = false;
    _resumeAt = DateTime.now().add(const Duration(seconds: 2));
  }
}
