import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/models/phone.dart';
import '../hooks/favorites.dart';
import 'common.dart';
import 'motion.dart';
import 'effects.dart';
import 'ux.dart';
import '../hooks/language.dart';
import 'cart_flight.dart';
import 'reviews.dart';
import '../theme/app_theme.dart';

const _orange = Color(0xFF3D7BFF);
const _discountRed = Color(0xFFFF453A);
Color get _navy => AppColors.text;

// "%33.33", "%20" — at most 2 decimals, no trailing zeros
String discountLabel(double percent) {
  final text = percent.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '%$text';
}

// The red "%10" pill shown on top of a discounted phone's picture
class DiscountBadge extends StatelessWidget {
  final double percent;
  final double fontSize;

  const DiscountBadge({super.key, required this.percent, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: _discountRed,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        discountLabel(percent),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Store card: image with discount badge, name, price / old price,
// condition + stock chips, and the cart and ♥ buttons.
class ProductCard extends StatelessWidget {
  final Phone phone;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  // Ties the picture to the detail page's, so it flies there when tapped.
  // Unique per place: the same phone can be on the page twice (deals and the list).
  final Object? heroTag;

  const ProductCard({
    this.heroTag,
    super.key,
    required this.phone,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final outOfStock = phone.stock <= 0;
    final picture = _CardImage(phone: phone);
    // The picture's place on screen, where the add-to-cart flight lifts off
    BuildContext? pictureContext;
    return DecoratedBox(
      // A white card with a hairline border and a soft, wide navy shadow
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.glassEdge),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The picture sits on its own rounded, tinted tile inside the card,
              // with the sale % on its top-left and the ♥ on its top-right
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Builder(
                          builder: (context) {
                            pictureContext = context;
                            return heroTag == null
                                ? picture
                                : Hero(
                                    tag: heroTag!,
                                    // The phone hovers above its tile
                                    child: Floating(height: 5, child: picture),
                                  );
                          },
                        ),
                        if (phone.hasDiscount)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Pulse(
                              child: DiscountBadge(
                                percent: phone.discountPercent,
                              ),
                            ),
                          ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _FavoriteButton(phoneId: phone.id),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand on the left, ★ rating on the right (when reviewed)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            phone.brand.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        RatingChip(phone: phone),
                      ],
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 38, // always 2 lines tall so cards line up
                      child: Text(
                        phone.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.3,
                          // The shop's dark navy, like the section titles
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _InfoChip(
                          icon: Icons.check,
                          label: tr(
                            phone.condition,
                          ), // "New" / "Used" follow the language; "98%" stays
                          color: const Color(0xFF30D158),
                        ),
                        _InfoChip(
                          icon: Icons.inventory_2_outlined,
                          label: outOfStock
                              ? tr('អស់ស្តុក')
                              : trf(
                                  'នៅសល់ ${phone.stock}',
                                  '${phone.stock} in stock',
                                ),
                          color: outOfStock
                              ? Colors.red
                              : const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Price on the left, a round add-to-cart button on the right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (phone.hasDiscount)
                                Text(
                                  money(
                                    phone.oldPrice!,
                                  ).replaceFirst('.00', ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  money(phone.price).replaceFirst('.00', ''),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: phone.hasDiscount
                                        ? _discountRed
                                        : _navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        PressScale(
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: FilledButton(
                              onPressed: outOfStock
                                  ? null
                                  : () {
                                      // If the add goes through, a thumbnail
                                      // flies from the picture into the cart
                                      final from = pictureContext;
                                      if (from != null) {
                                        CartFlight.prepare(
                                          from,
                                          phone.imageUrl,
                                        );
                                      }
                                      onAddToCart();
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: _orange,
                                padding: EdgeInsets.zero,
                                elevation: 3,
                                shadowColor: _orange.withValues(alpha: 0.5),
                                shape: const CircleBorder(),
                              ),
                              child: Icon(
                                Icons.shopping_cart,
                                size: 20,
                                semanticLabel: trf(
                                  'ដាក់ក្នុង Cart',
                                  'Add to cart',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// How long each colour stays on a store card
const cardColorInterval = Duration(seconds: 3);

// The picture of each colour in turn, fading from one to the next.
// A phone with one picture just shows it.
class _CardImage extends StatefulWidget {
  final Phone phone;

  const _CardImage({required this.phone});

  @override
  State<_CardImage> createState() => _CardImageState();
}

class _CardImageState extends State<_CardImage> {
  Timer? _timer;
  int _index = 0;

  // Each picture once, in the order of the colours
  List<String> get _urls {
    final phone = widget.phone;
    final urls = phone.colors
        .map(phone.imageFor)
        .where((u) => u.isNotEmpty)
        .toSet();
    return urls.isEmpty ? [phone.imageUrl] : urls.toList();
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(cardColorInterval, (_) {
      // Not while another page covers the store
      if (_urls.length > 1 && TickerMode.valuesOf(context).enabled) {
        setState(() {
          _index++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = Center(
      child: Icon(Icons.phone_android, size: 64, color: Colors.grey),
    );
    final urls = _urls;
    final url = urls[_index % urls.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceHigh, AppColors.tileLow],
        ),
      ),
      child: url.isEmpty
          ? placeholder
          // contain + padding: the whole phone shows, never cropped by the card
          : Padding(
              padding: const EdgeInsets.all(14),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: SizedBox.expand(
                  key: ValueKey(url),
                  // Mock mode's pictures are bundled with the app
                  child: url.startsWith('asset:')
                      ? Image.asset(
                          url.substring(6),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => placeholder,
                        )
                      : Image.network(
                          // A small WebP copy (≈20KB instead of ≈500KB)
                          sizedImageUrl(url, 500),
                          fit: BoxFit.contain,
                          // Decode at card size, so scrolling stays smooth on a phone.
                          // Not on the web, where the plain <img> fallback can't be resized.
                          cacheWidth: kIsWeb ? null : 500,
                          // On Web, fall back to a plain <img> tag so images load without CORS headers
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.fallback,
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                ),
              ),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          // Shrinks with "…" instead of overflowing on narrow phones
          // Rolls to the new number when the live refresh changes the stock
          Flexible(
            child: RollingText(
              label,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final int phoneId;

  const _FavoriteButton({required this.phoneId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Favorites.instance,
      builder: (context, _) {
        final liked = Favorites.instance.contains(phoneId);
        // A small white disc floating on the picture's corner
        return PressScale(
          scale: 0.8,
          child: Material(
            color: AppColors.glass,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: AppColors.shadow,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Haptics.tap();
                Favorites.instance.toggle(phoneId);
              },
              child: SizedBox(
                width: 36,
                height: 36,
                // A liked heart pops bigger and settles; un-liking just shrinks back
                child: AnimatedScale(
                  scale: liked ? 1.15 : 1,
                  duration: Motion.slow,
                  curve: liked ? Curves.elasticOut : Curves.easeOut,
                  child: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 19,
                    color: _discountRed,
                    semanticLabel: liked ? 'Unlike' : 'Like',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
