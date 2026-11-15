import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/cart.dart';
import '../services/favorites.dart';
import 'common.dart';
import '../services/language.dart';

// What the customer picked in the store menu
class StoreFilter {
  final String section; // 'home', 'sale', 'brands' or the category name
  final int? categoryId;
  final String brand;

  const StoreFilter({this.section = 'home', this.categoryId, this.brand = ''});

  static const home = StoreFilter();
  static const sale = StoreFilter(section: 'sale'); // every discounted phone

  String get label {
    if (section == 'home') return '';
    if (section == 'sale') return tr('កំពុងបញ្ចុះតម្លៃ');
    if (section == 'brands') return brand;
    return brand.isEmpty ? section : '$section › $brand';
  }

  @override
  bool operator ==(Object other) =>
      other is StoreFilter &&
      other.section == section &&
      other.categoryId == categoryId &&
      other.brand == brand;

  @override
  int get hashCode => Object.hash(section, categoryId, brand);
}

// Bottom menu: Home | Cart | Telegram | My orders | Account
class StoreMenuBar extends StatelessWidget {
  final StoreFilter current;
  final ValueChanged<StoreFilter> onSelected;
  final VoidCallback onTelegram;
  final VoidCallback onAccount;
  final VoidCallback onOrders;
  final VoidCallback onCart;
  final int
  activeOrders; // orders not yet delivered or cancelled, shown on Order
  final User? user; // the logged-in customer, whose picture goes on Account

  const StoreMenuBar({
    super.key,
    this.user,
    required this.current,
    required this.onSelected,
    required this.onTelegram,
    required this.onAccount,
    required this.onOrders,
    required this.onCart,
    this.activeOrders = 0,
  });

  static const activeColor = Color(0xFFC08A2E);

  @override
  Widget build(BuildContext context) {
    // A rounded bar floating just above the bottom edge, with Telegram as a big
    // round button rising out of its middle. The space above the bar is part of
    // the menu, so the whole round button can be tapped.
    // Low on the screen: it may sit a little into the phone's gesture-bar space,
    // but never closer than 6px to the edge
    final bottom = max(6.0, MediaQuery.viewPaddingOf(context).bottom - 14);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom),
      child: SizedBox(
        height: 62 + _rise,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: _rise,
              // Frosted glass: the page shows through, blurred, behind a light veil
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 20,
                      color: Color(0x330F2A5F),
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.88),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      // Equal widths, so all five always fit without scrolling
                      child: Row(
                        children: [
                          Expanded(
                            child: _MenuButton(
                              label: tr('Home'),
                              icon: Icons
                                  .phone_iphone, // a phone shop: the store page shows a phone
                              active: current.section == 'home',
                              onTap: () => onSelected(StoreFilter.home),
                            ),
                          ),
                          Expanded(
                            child: ListenableBuilder(
                              listenable: Cart.instance,
                              builder: (context, _) => _MenuButton(
                                label: tr('កន្ត្រក'),
                                icon: Icons.shopping_cart_outlined,
                                count: Cart.instance.count,
                                onTap: onCart,
                              ),
                            ),
                          ),
                          // The label under the round button; tapping it opens Telegram too
                          Expanded(
                            child: InkWell(
                              onTap: onTelegram,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Telegram',
                                      maxLines: 1,
                                      style: _labelStyle(false),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _MenuButton(
                              label: tr('Order'),
                              icon: Icons.receipt_long_outlined,
                              count: activeOrders,
                              onTap: onOrders,
                            ),
                          ),
                          Expanded(
                            child: _MenuButton(
                              label: tr('Account'),
                              icon: Icons.account_circle_outlined,
                              picture:
                                  user != null && user!.avatarUrl.isNotEmpty
                                  ? UserAvatar(user: user!, radius: 13)
                                  : null,
                              onTap: onAccount,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: _TelegramBubble(onTap: onTelegram)),
            ),
          ],
        ),
      ),
    );
  }

  // How far the Telegram button rises above the bar
  static const _rise = 14.0;
}

// ♥ in the top bar with how many phones are liked; opens the favourites
class FavoritesButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FavoritesButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Favorites.instance,
      builder: (context, _) => IconButton(
        tooltip: 'Favourites',
        icon: Badge(
          isLabelVisible: Favorites.instance.count > 0,
          label: Text('${Favorites.instance.count}'),
          child: const Icon(Icons.favorite_border),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

// Telegram's logo in a big circle with a white ring, standing out from the bar
class _TelegramBubble extends StatelessWidget {
  final VoidCallback onTap;

  const _TelegramBubble({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x552AABEE), // Telegram blue glow
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // The picture has a white margin around its circle: zoom past it
          child: Transform.scale(
            scale: 1.24,
            child: Image.asset('assets/images/telegram.jpg', fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

TextStyle _labelStyle(bool active) => TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: active ? StoreMenuBar.activeColor : const Color(0xFF333333),
);

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? picture; // shown instead of [icon]
  final bool active;
  final VoidCallback onTap;
  final int count; // a red number on the icon, like the cart's; hidden at 0

  const _MenuButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.picture,
    this.active = false,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Same height for icons and images, so all the labels line up
          SizedBox(
            height: 26,
            child: picture != null
                ? picture!
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      // A soft pill behind the selected item
                      color: active
                          ? StoreMenuBar.activeColor.withValues(alpha: 0.16)
                          : null,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: Icon(
                        icon,
                        size: 24,
                        color: active
                            ? StoreMenuBar.activeColor
                            : const Color(0xFF333333),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 3),
          // Shrinks a little on very narrow phones rather than overflowing
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: _labelStyle(active)),
          ),
        ],
      ),
    );
  }
}

// Slides in from the left (☰ next to the shop name). Categories and brands are only
// the ones that actually have products, from GET /api/menu.
class StoreDrawer extends StatelessWidget {
  final Map<String, dynamic>? menu;
  final StoreFilter current;
  final ValueChanged<StoreFilter> onSelected;

  const StoreDrawer({
    super.key,
    required this.menu,
    required this.current,
    required this.onSelected,
  });

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Color(0xFF94A3B8),
      ),
    ),
  );

  Widget _item(BuildContext context, StoreFilter filter, String text) {
    final selected = filter == current;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? StoreMenuBar.activeColor : const Color(0xFF1E293B),
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check, size: 18, color: StoreMenuBar.activeColor)
          : null,
      onTap: () {
        Navigator.pop(context); // close the drawer
        onSelected(filter);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brands = List<String>.from(menu?['brands'] ?? []);
    final categories = List<Map<String, dynamic>>.from(
      menu?['categories'] ?? [],
    );

    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', height: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('Menu'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  _header(tr('BROWSE')),
                  _item(context, StoreFilter.home, tr('Home')),
                  if (categories.isNotEmpty) _header(tr('CATEGORIES')),
                  for (final category in categories)
                    _item(
                      context,
                      StoreFilter(
                        section: category['name'],
                        categoryId: category['id'],
                      ),
                      category['name'],
                    ),
                  if (brands.isNotEmpty) _header(tr('BRANDS')),
                  for (final brand in brands)
                    _item(
                      context,
                      StoreFilter(section: 'brands', brand: brand),
                      brand,
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
