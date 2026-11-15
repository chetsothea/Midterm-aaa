import 'package:flutter/material.dart';
import '../models/phone.dart';
import '../services/cart.dart';
import '../services/favorites.dart';
import '../widgets/brand_row.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import '../widgets/store_app_bar.dart';
import 'cart_screen.dart';
import 'login_screen.dart';
import '../services/language.dart';

class ProductDetailScreen extends StatefulWidget {
  final Phone phone;

  // The tapped card's tag, so its picture flies into place here
  final Object? heroTag;

  const ProductDetailScreen({super.key, required this.phone, this.heroTag});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  // First colour is picked by default; '' when the phone has no colour options
  late String _color = phone.colors.isEmpty ? '' : phone.colors.first;
  // Smallest size is picked by default; '' when the phone is sold in one size only
  late String _storage = phone.storageOptions.isEmpty
      ? ''
      : phone.storageOptions.first.storage;

  Phone get phone => widget.phone;

  String get _picked =>
      [_color, _storage].where((s) => s.isNotEmpty).join(', ');

  void _addToCart({bool buyNow = false}) async {
    if (!await requireLogin(context) || !mounted) return;
    if (!Cart.instance.add(phone, _qty, _color, _storage)) {
      showMessage(
        context,
        trf(
          'ស្តុកមិនគ្រប់គ្រាន់ (នៅសល់ ${phone.stock})',
          'Not enough stock (${phone.stock} left)',
        ),
        error: true,
      );
      return;
    }
    if (buyNow) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } else {
      showMessage(
        context,
        _picked.isEmpty
            ? tr('បានបន្ថែមទៅ Cart')
            : trf('បានបន្ថែម ($_picked) ទៅ Cart', 'Added ($_picked) to cart'),
      );
    }
  }

  Widget _hero(Widget child) {
    final tag = widget.heroTag;
    return tag == null ? child : Hero(tag: tag, child: child);
  }

  static const _navy = Color(0xFF0F2A5F);
  static const _red = Color(0xFFE11D48);
  static const _orange = Color(0xFFF97316);

  static final _card = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  Widget _pill(String text, Color color, [IconData? icon]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          // Shortened with … rather than running past the card on a narrow phone
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A rounded choice that lights up in navy when picked
  ChoiceChip _choice({
    Widget? avatar,
    required Widget label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      avatar: avatar,
      label: label,
      selected: selected,
      showCheckmark: false,
      backgroundColor: const Color(0xFFF8FAFC),
      selectedColor: _navy.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(
        color: selected ? _navy : const Color(0xFFE2E8F0),
        width: selected ? 2 : 1,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _heading(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // One specification as a small tile: tinted icon square, name, value
  Widget _spec(IconData icon, String label, String value, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF0E7490).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF0E7490)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _navy,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ♥ in the bar: the same favourites as the heart on the store cards
  Widget _favoriteButton() {
    return ListenableBuilder(
      listenable: Favorites.instance,
      builder: (context, _) {
        final saved = Favorites.instance.contains(phone.id);
        return IconButton(
          tooltip: saved
              ? trf('ដកចេញពី Favourites', 'Remove from favourites')
              : trf('ដាក់ក្នុង Favourites', 'Add to favourites'),
          onPressed: () => Favorites.instance.toggle(phone.id),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              saved ? Icons.favorite : Icons.favorite_border,
              key: ValueKey(saved),
              color: saved ? const Color(0xFFFF6B8A) : Colors.white,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inStock = phone.stock > 0;
    final price = phone.priceFor(_storage);
    final oldPrice = phone.oldPriceFor(_storage);
    final specs = [
      if (phone.ram.isNotEmpty) (Icons.memory, 'RAM', phone.ram),
      if (_storage.isNotEmpty)
        (Icons.sd_storage_outlined, 'Storage', _storage)
      else if (phone.storage.isNotEmpty)
        (Icons.sd_storage_outlined, 'Storage', phone.storage),
      if (phone.colors.isNotEmpty)
        (
          Icons.palette_outlined,
          trf('ពណ៌', 'Colours'),
          '${phone.colors.length}',
        ),
      (Icons.verified_outlined, trf('ស្ថានភាព', 'Condition'), phone.condition),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // The store's navy-to-teal bar with rounded corners, like the home page
      appBar: storeAppBar(
        title: Text(phone.name, overflow: TextOverflow.ellipsis),
        actions: [_favoriteButton(), const SizedBox(width: 4)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          // The picture on the soft store colours, switching with the picked colour
          Container(
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE0F2FE), Color(0xFFEDE9FE)],
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x261D4ED8),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: _hero(
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: PhoneImage(
                        key: ValueKey(phone.imageFor(_color)),
                        url: phone.imageFor(_color),
                        size: 220,
                      ),
                    ),
                  ),
                ),
                if (phone.hasDiscount)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: DiscountBadge(
                      percent: phone.discountPercent,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Name, price and stock
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _pill(phone.brand, brandColor(phone.brand)),
                    _pill(
                      phone.condition,
                      const Color(0xFF16A34A),
                      Icons.check,
                    ),
                    _pill(
                      inStock
                          ? trf(
                              'មានក្នុងស្តុក: ${phone.stock} គ្រឿង',
                              'In stock: ${phone.stock}',
                            )
                          : tr('អស់ស្តុក'),
                      inStock ? const Color(0xFF2563EB) : Colors.red,
                      Icons.inventory_2_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  phone.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      money(price), // follows the picked storage size
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: oldPrice != null ? _red : _navy,
                      ),
                    ),
                    if (oldPrice != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          money(oldPrice),
                          style: const TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _pill(
                          trf(
                            'សន្សំ ${(oldPrice - price).toStringAsFixed(0)}\$',
                            'Save \$${(oldPrice - price).toStringAsFixed(0)}',
                          ),
                          _red,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (phone.colors.isNotEmpty || phone.storageOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (phone.colors.isNotEmpty) ...[
                    _heading(tr('ពណ៌: '), _color),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final color in phone.colors)
                          _choice(
                            avatar: ColorDot(color: color, size: 18),
                            label: Text(color),
                            selected: _color == color,
                            onTap: () => setState(() => _color = color),
                          ),
                      ],
                    ),
                  ],
                  if (phone.colors.isNotEmpty &&
                      phone.storageOptions.isNotEmpty)
                    const Divider(height: 28),
                  if (phone.storageOptions.isNotEmpty) ...[
                    _heading('Storage: ', _storage),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in phone.storageOptions)
                          _choice(
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  option.storage,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  money(option.price),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            selected: _storage == option.storage,
                            onTap: () =>
                                setState(() => _storage = option.storage),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // The main specifications, then the shop's description
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trf('លក្ខណៈពិសេស', 'Specifications'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 10),
                // Two tiles a row on a phone
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (icon, label, value) in specs)
                          _spec(icon, label, value, width),
                      ],
                    );
                  },
                ),
                if (phone.description.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(phone.description, style: const TextStyle(height: 1.5)),
                ],
              ],
            ),
          ),
        ],
      ),
      // Same bottom bar as Cart and Checkout: quantity, add to cart, buy now
      bottomNavigationBar: inStock
          ? Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      // − n + in one rounded pill
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _qty > 1
                                  ? () => setState(() => _qty--)
                                  : null,
                              icon: const Icon(Icons.remove, size: 18),
                            ),
                            Text(
                              '$_qty',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _qty < phone.stock
                                  ? () => setState(() => _qty++)
                                  : null,
                              icon: const Icon(Icons.add, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addToCart,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _orange,
                            side: const BorderSide(color: _orange, width: 1.5),
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 19,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(tr('ដាក់ Cart')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _addToCart(buyNow: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: _orange,
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            elevation: 2,
                            shadowColor: const Color(0x66F97316),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.bolt_rounded, size: 20),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(tr('ទិញឥឡូវ')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
