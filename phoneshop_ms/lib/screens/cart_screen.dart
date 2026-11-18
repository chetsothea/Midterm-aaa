import 'package:flutter/material.dart';
import '../hooks/cart.dart';
import '../components/common.dart';
import '../components/store_app_bar.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';
import '../components/ux.dart';
import '../components/cart_undo_bar.dart';
import '../components/motion.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';

Color get _navy => AppColors.text;
Color get _muted => AppColors.muted;
const _discountRed = Color(0xFFFF453A);
const _orange = Color(0xFF3D7BFF);

// White card with a soft shadow, the same as the other pages
BoxDecoration get _cardDecoration => BoxDecoration(
  color: AppColors.glass,
  borderRadius: BorderRadius.circular(AppRadius.lg),
  boxShadow: const [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ],
);

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  // − and + in the quantity pill; + is filled navy, the way forward
  Widget _qtyButton(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    bool filled = false,
  }) {
    return SizedBox.square(
      dimension: 32,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 18,
        color: filled ? Colors.white : _navy,
        style: filled
            ? IconButton.styleFrom(
                backgroundColor: _navy,
                disabledBackgroundColor: AppColors.outline,
              )
            : null,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }

  Widget _item(Cart cart, CartItem item) {
    final hasDiscount = item.regularPrice > item.unitPrice;
    // Swipe left to take it out, as well as the bin button
    return Dismissible(
      key: ValueKey('cart-${item.key}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => cart.remove(item.key),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: _discountRed,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      child: _itemCard(cart, item, hasDiscount),
    );
  }

  Widget _itemCard(Cart cart, CartItem item, bool hasDiscount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 84,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surfaceHigh, AppColors.tileLow],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  PhoneImage(url: item.phone.imageFor(item.color), size: 76),
                  if (item.phone.hasDiscount)
                    Positioned(
                      top: -6,
                      left: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _discountRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '-${item.phone.discountPercent.round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.phone.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                      ),
                      SizedBox.square(
                        dimension: 28,
                        child: IconButton(
                          tooltip: 'ដកចេញ',
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          color: _discountRed,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => cart.remove(item.key),
                        ),
                      ),
                    ],
                  ),
                  if (item.phone.brand.isNotEmpty)
                    Text(
                      item.phone.brand,
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  if (item.options.isNotEmpty) CartOptionsLabel(item: item),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              money(item.unitPrice),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: hasDiscount ? _discountRed : _navy,
                              ),
                            ),
                            if (hasDiscount)
                              Text(
                                money(item.regularPrice),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.page,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _qtyButton(
                              Icons.remove,
                              tr('បន្ថយ'),
                              () => cart.setQty(item.key, item.qty - 1),
                            ),
                            SizedBox(
                              width: 22,
                              child: Text(
                                '${item.qty}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _navy,
                                ),
                              ),
                            ),
                            _qtyButton(
                              Icons.add,
                              tr('បន្ថែម'),
                              // Stock is shared by every colour of this phone in the cart
                              cart.qtyOf(item.phone.id) < item.phone.stock
                                  ? () => cart.setQty(item.key, item.qty + 1)
                                  : null,
                              filled: true,
                            ),
                          ],
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
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: TextStyle(color: _muted)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _summary(Cart cart) {
    return Container(
      decoration: _cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined, size: 18, color: _navy),
                const SizedBox(width: 6),
                // Wraps on a narrow phone instead of running past the edge
                Expanded(
                  child: Text(
                    tr('សង្ខេបការបញ្ជាទិញ'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _summaryRow(tr('ចំនួន'), '${cart.count}'),
            _summaryRow(tr('តម្លៃសរុបមុនបញ្ចុះ'), money(cart.regularTotal)),
            if (cart.discount > 0)
              _summaryRow(
                tr('បញ្ចុះតម្លៃ'),
                '-${money(cart.discount)}',
                color: _discountRed,
              ),
            // What the discounts add up to, in green, so the saving is felt
            if (cart.discount > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.savings_outlined,
                      size: 18,
                      color: Color(0xFF30D158),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        trf(
                          'អ្នកសន្សំបាន ${money(cart.discount)}',
                          'You save ${money(cart.discount)}',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF30D158),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr('សរុប'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                // Counts to the new total when a quantity changes
                CountUpMoney(
                  cart.total,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Cart.instance;
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(
        title: Text(tr('កន្ត្រកទំនិញ')),
        actions: [
          // How many phones, in a small gold pill
          ListenableBuilder(
            listenable: cart,
            builder: (context, _) => cart.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    margin: const EdgeInsets.only(right: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Text(
                      trf('${cart.count} គ្រឿង', '${cart.count} items'),
                      style: TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      // The list, with the "Undo" bar sliding up over its bottom edge
      body: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: cart,
              builder: (context, _) {
                if (cart.isEmpty) {
                  return StatusView(
                    icon: Icons.shopping_cart_outlined,
                    title: tr('Cart ទទេ'),
                    message: trf(
                      'រើសទូរស័ព្ទដែលអ្នកចូលចិត្ត ហើយដាក់ក្នុង Cart',
                      'Pick a phone you like and add it here',
                    ),
                    actionLabel: trf('ទៅមើលទូរស័ព្ទ', 'Browse phones'),
                    actionIcon: Icons.storefront_outlined,
                    onAction: () => Navigator.maybePop(context),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  children: [
                    // Each line slides up in turn
                    for (final (i, item) in cart.items.indexed)
                      Entrance(index: i, child: _item(cart, item)),
                    const SizedBox(height: AppSpacing.xxs),
                    _summary(cart),
                  ],
                );
              },
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: CartUndoBar()),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: cart,
        builder: (context, _) => cart.isEmpty
            ? const SizedBox.shrink()
            : Container(
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
                    child: Row(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trf(
                                'សរុប (${cart.count})',
                                'Total (${cart.count})',
                              ),
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                            CountUpMoney(
                              cart.total,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _orange,
                              minimumSize: const Size.fromHeight(50),
                              elevation: 2,
                              shadowColor: const Color(0x663D7BFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              if (!await requireLogin(context) ||
                                  !context.mounted) {
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CheckoutScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Checkout'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
