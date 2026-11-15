import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/phone.dart';
import '../services/favorites.dart';
import 'common.dart';
import '../services/language.dart';

const _orange = Color(0xFFF97316);
const _discountRed = Color(0xFFE11D48);
const _navy = Color(0xFF0F2A5F);

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
    return Card(
      elevation: 3,
      shadowColor: const Color(0x331D4ED8),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  heroTag == null
                      ? _CardImage(phone: phone)
                      : Hero(
                          tag: heroTag!,
                          child: _CardImage(phone: phone),
                        ),
                  if (phone.hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: DiscountBadge(percent: phone.discountPercent),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 38, // always 2 lines tall so cards line up
                    child: Text(
                      phone.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.3,
                        // The shop's dark navy, like the section titles
                        color: Color(0xFF0F2A5F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(phone.price).replaceFirst('.00', ''),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: phone.hasDiscount ? _discountRed : _navy,
                        ),
                      ),
                      if (phone.hasDiscount) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              money(phone.oldPrice!).replaceFirst('.00', ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _InfoChip(
                        icon: Icons.check,
                        label: tr(
                          phone.condition,
                        ), // "New" / "Used" follow the language; "98%" stays
                        color: const Color(0xFF16A34A),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: FilledButton(
                            onPressed: outOfStock ? null : onAddToCart,
                            style: FilledButton.styleFrom(
                              backgroundColor: _orange,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Icon(Icons.shopping_cart, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FavoriteButton(phoneId: phone.id),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0F2FE), Color(0xFFEDE9FE)],
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
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    // Decode at card size, so scrolling stays smooth on a phone.
                    // Not on the web, where the plain <img> fallback can't be resized.
                    cacheWidth: kIsWeb ? null : 500,
                    // On Web, fall back to a plain <img> tag so images load without CORS headers
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          // Shrinks with "…" instead of overflowing on narrow phones
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        return SizedBox(
          width: 44,
          height: 36,
          child: OutlinedButton(
            onPressed: () => Favorites.instance.toggle(phoneId),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: _discountRed),
              backgroundColor: liked ? _discountRed : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Icon(
              Icons.favorite,
              size: 18,
              color: liked ? Colors.white : _discountRed,
            ),
          ),
        );
      },
    );
  }
}
