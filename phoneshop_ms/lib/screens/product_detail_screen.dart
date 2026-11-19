import '../data/riel.dart';
import 'package:flutter/material.dart';
import '../data/models/phone.dart';
import '../hooks/cart.dart';
import '../hooks/favorites.dart';
import '../components/brand_row.dart';
import '../components/common.dart';
import '../components/motion.dart';
import '../components/product_card.dart';
import '../components/store_app_bar.dart';
import 'cart_screen.dart';
import 'login_screen.dart';
import '../components/ux.dart';
import '../components/reviews.dart';
import '../components/phone_3d.dart';
import '../hooks/language.dart';
import '../data/api_service.dart';
import 'compare_screen.dart';
import '../theme/app_theme.dart';

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

  // "Tell me when it's back": which ones this customer asked for
  Set<String> _alerts = {};
  bool _alertBusy = false;

  @override
  void initState() {
    super.initState();
    if (ApiService.isLoggedIn && !(ApiService.currentUser?.isTeam ?? false)) {
      ApiService.fetchStockAlerts()
          .then((a) {
            if (mounted) setState(() => _alerts = a);
          })
          .catchError((_) {});
    }
  }

  // This phone, or just the colour/size picked when it is counted that way
  String get _alertKey =>
      '${phone.id}|${phone.hasVariantStock ? Phone.variantKey(_color, _storage) : ''}';

  Future<void> _toggleAlert() async {
    if (!await requireLogin(context) || !mounted) return;
    final on = !_alerts.contains(_alertKey);
    setState(() => _alertBusy = true);
    try {
      await ApiService.setStockAlert(
        phone.id,
        on: on,
        color: phone.hasVariantStock ? _color : '',
        storage: phone.hasVariantStock ? _storage : '',
      );
      if (!mounted) return;
      setState(() => on ? _alerts.add(_alertKey) : _alerts.remove(_alertKey));
      Haptics.success();
      showMessage(
        context,
        on
            ? trf(
                'យើងនឹងជូនដំណឹងអ្នក ពេលមានស្តុកវិញ 🔔',
                "We'll let you know when it's back 🔔",
              )
            : trf('បានបោះបង់ការជូនដំណឹង', 'Alert removed'),
      );
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _alertBusy = false);
    }
  }

  // Sold out (or this colour/size is): instead of buying, ask to be told
  Widget _notifyBar() {
    final on = _alerts.contains(_alertKey);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: on
            ? OutlinedButton.icon(
                onPressed: _alertBusy ? null : _toggleAlert,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.notifications_active),
                label: Text(
                  trf(
                    'នឹងជូនដំណឹងពេលមានស្តុក · ចុចដើម្បីបោះបង់',
                    "We'll tell you · tap to cancel",
                  ),
                ),
              )
            : FilledButton.icon(
                onPressed: _alertBusy ? null : _toggleAlert,
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.notifications_none),
                label: Text(
                  trf('ជូនដំណឹងខ្ញុំពេលមានស្តុក', 'Notify me when in stock'),
                ),
              ),
      ),
    );
  }

  // Drives the picture's parallax as the page scrolls
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // The first colour and size the shop has (first ones if all are sold out);
  // '' when the phone has no colour / size options
  late final (String, String) _firstInStock = () {
    final colors = phone.colors.isEmpty ? [''] : phone.colors;
    final sizes = phone.storageOptions.isEmpty
        ? ['']
        : [for (final o in phone.storageOptions) o.storage];
    for (final c in colors) {
      for (final s in sizes) {
        if (phone.stockFor(c, s) > 0) return (c, s);
      }
    }
    return (colors.first, sizes.first);
  }();
  late String _color = _firstInStock.$1;
  late String _storage = _firstInStock.$2;

  // On the shelf for the colour and size picked
  int get _left => phone.stockFor(_color, _storage);

  // Picking another colour/size keeps the quantity within what is there
  void _pick({String? color, String? storage}) => setState(() {
    _color = color ?? _color;
    _storage = storage ?? _storage;
    if (_qty > _left) _qty = _left < 1 ? 1 : _left;
  });

  Phone get phone => widget.phone;

  String get _picked =>
      [_color, _storage].where((s) => s.isNotEmpty).join(', ');

  void _addToCart({bool buyNow = false}) async {
    if (!await requireLogin(context) || !mounted) return;
    final added = Cart.instance.add(phone, _qty, _color, _storage);
    added ? Haptics.success() : Haptics.warning();
    if (!added) {
      showMessage(
        context,
        trf(
          'ស្តុកមិនគ្រប់គ្រាន់ (នៅសល់ $_left)',
          'Not enough stock ($_left left)',
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

  // Opens Compare with this phone already picked on the left
  Future<void> _compare() async {
    try {
      final phones = await ApiService.fetchPhones();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompareScreen(phones: phones, first: widget.phone),
        ),
      );
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          trf('មិនអាចភ្ជាប់ទៅហាងបានទេ', "Can't reach the shop"),
          error: true,
        );
      }
    }
  }

  Widget _hero(Widget child) {
    final tag = widget.heroTag;
    // Inside a turntable you can spin with a finger (widgets/phone_3d.dart);
    // the picture itself is what flies here from the store card
    final picture = tag == null ? child : Hero(tag: tag, child: child);
    return Phone3DViewer(child: picture);
  }

  static Color get _navy => AppColors.text;
  static const _red = Color(0xFFFF453A);
  static const _orange = Color(0xFF3D7BFF);

  static BoxDecoration get _card => BoxDecoration(
    color: AppColors.glass,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  Widget _pill(String text, Color color, [IconData? icon]) {
    // A very dark brand colour (Apple's near-black) would vanish on the dark
    // page, so its text and icon use the light grey instead
    if (color.computeLuminance() < 0.05) color = AppColors.textSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: AppSpacing.xxs),
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
      backgroundColor: AppColors.surface,
      selectedColor: _navy.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      side: BorderSide(
        color: selected ? _navy : AppColors.line,
        width: selected ? 2 : 1,
      ),
      onSelected: (_) => onTap(),
    );
  }

  // A sold-out choice stays tappable (to see its photo) but reads "sold out"
  Widget _soldOutLabel(Widget label, bool soldOut) {
    if (!soldOut) return label;
    return Opacity(
      opacity: 0.45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          label,
          Text(
            tr('អស់ស្តុក'),
            style: const TextStyle(fontSize: 10, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _heading(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: TextStyle(fontWeight: FontWeight.w700, color: _navy),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: AppColors.muted),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF3D7BFF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF3D7BFF)),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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
          onPressed: () {
            Haptics.tap();
            Favorites.instance.toggle(phone.id);
          },
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
    // This colour/size; with one shared count it is the same as [inStock]
    final pickedInStock = _left > 0;
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
      backgroundColor: AppColors.page,
      // The store's navy-to-teal bar with rounded corners, like the home page
      appBar: storeAppBar(
        title: Text(phone.name, overflow: TextOverflow.ellipsis),
        actions: [
          // Side by side with another phone
          IconButton(
            tooltip: trf('ប្រៀបធៀប', 'Compare'),
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: _compare,
          ),
          _favoriteButton(),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        // Each block of the page rises in after the one above it
        children: Entrance.stagger([
          // The picture on the soft store colours, switching with the picked colour
          // Parallax: the picture slides down slower than the page and fades a
          // little as it scrolls away, so it feels further back than the text
          AnimatedBuilder(
            animation: _scroll,
            child: Container(
              height: 260,
              clipBehavior:
                  Clip.antiAlias, // keeps the zoomed phone in its card
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surfaceHigh, AppColors.tileLow],
                ),
                border: Border.all(color: AppColors.glassEdge), // glass edge
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // A soft white spotlight behind the phone (the turntable adds
                  // the shadow on the "floor" under it)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.1),
                          radius: 0.75,
                          colors: [
                            // A soft electric-blue halo behind the phone
                            const Color(0xFF3D7BFF).withValues(alpha: 0.22),
                            const Color(0xFF3D7BFF).withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
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
            builder: (context, child) {
              if (Motion.off(context) || !_scroll.hasClients) return child!;
              final offset = _scroll.offset.clamp(0.0, 260.0);
              return Transform.translate(
                offset: Offset(0, offset * 0.4),
                child: Opacity(
                  opacity: 1 - offset / 520,
                  child: Transform.scale(
                    scale: 1 - offset / 2600,
                    child: child,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
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
                      const Color(0xFF30D158),
                      Icons.check,
                    ),
                    _pill(
                      pickedInStock
                          ? trf(
                              'មានក្នុងស្តុក: $_left គ្រឿង',
                              'In stock: $_left',
                            )
                          : inStock
                          ? trf('$_picked អស់ស្តុក', '$_picked sold out')
                          : tr('អស់ស្តុក'),
                      pickedInStock ? const Color(0xFF2563EB) : Colors.red,
                      Icons.inventory_2_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  phone.name,
                  style: TextStyle(
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
                    CountUpMoney(
                      price, // follows the picked storage size, counting up
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: oldPrice != null ? _red : _navy,
                      ),
                    ),
                    // "≈ ៛4,920,000" for customers who think in riel
                    ValueListenableBuilder<int>(
                      valueListenable: Riel.rate,
                      builder: (_, _, _) => Riel.shown
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                '≈ ${Riel.of(price)}',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
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
            const SizedBox(height: AppSpacing.sm),
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
                            label: _soldOutLabel(
                              Text(color),
                              !phone.colorAvailable(color),
                            ),
                            selected: _color == color,
                            onTap: () => _pick(color: color),
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
                            label: _soldOutLabel(
                              Column(
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
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                              phone.stockFor(_color, option.storage) <= 0,
                            ),
                            selected: _storage == option.storage,
                            onTap: () => _pick(storage: option.storage),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // The main specifications, then the shop's description, each in a
          // section that folds open and shut
          ExpandableSection(
            title: trf('លក្ខណៈពិសេស', 'Specifications'),
            icon: Icons.memory_rounded,
            // Two tiles a row on a phone
            child: LayoutBuilder(
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
          ),
          if (phone.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ExpandableSection(
              title: trf('អំពីទូរស័ព្ទនេះ', 'About this phone'),
              icon: Icons.notes_rounded,
              initiallyExpanded: false,
              child: Text(
                phone.description,
                style: TextStyle(height: 1.6, color: AppColors.textSoft),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // Stars and words from customers who received this phone
          ExpandableSection(
            title: phone.ratingCount == 0
                ? trf('ការវាយតម្លៃ', 'Reviews')
                : trf(
                    'ការវាយតម្លៃ (${phone.ratingCount})',
                    'Reviews (${phone.ratingCount})',
                  ),
            icon: Icons.star_rounded,
            child: ReviewsSection(phone: phone),
          ),
        ]),
      ),
      // Same bottom bar as Cart and Checkout: quantity, add to cart, buy now
      bottomNavigationBar: pickedInStock
          ? Container(
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
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
                          color: AppColors.page,
                          borderRadius: BorderRadius.circular(AppRadius.xxl),
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
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _qty < _left
                                  ? () => setState(() => _qty++)
                                  : null,
                              icon: const Icon(Icons.add, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickedInStock ? _addToCart : null,
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
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: pickedInStock
                              ? () => _addToCart(buyNow: true)
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _orange,
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            elevation: 2,
                            shadowColor: const Color(0x663D7BFF),
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
          : _notifyBar(),
    );
  }
}
