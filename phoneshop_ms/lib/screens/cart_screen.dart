import 'package:flutter/material.dart';
import '../services/cart.dart';
import '../widgets/common.dart';
import '../widgets/store_app_bar.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';
import '../services/language.dart';

const _navy = Color(0xFF0F2A5F);
const _muted = Color(0xFF64748B);
const _discountRed = Color(0xFFE11D48);
const _orange = Color(0xFFF97316);

// White card with a soft shadow, the same as the other pages
final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
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
                disabledBackgroundColor: const Color(0xFFCBD5E1),
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
          borderRadius: BorderRadius.circular(16),
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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE0F2FE), Color(0xFFEDE9FE)],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F1D4ED8),
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
                          style: const TextStyle(
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
                      style: const TextStyle(fontSize: 12, color: _muted),
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
                                style: const TextStyle(
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
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
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
                                style: const TextStyle(
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: const TextStyle(color: _muted)),
          ),
          const SizedBox(width: 12),
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
                const Icon(Icons.receipt_long_outlined, size: 18, color: _navy),
                const SizedBox(width: 6),
                // Wraps on a narrow phone instead of running past the edge
                Expanded(
                  child: Text(
                    tr('សង្ខេបការបញ្ជាទិញ'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.savings_outlined,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trf(
                          'អ្នកសន្សំបាន ${money(cart.discount)}',
                          'You save ${money(cart.discount)}',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
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
                Text(
                  money(cart.total),
                  style: const TextStyle(
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
      backgroundColor: const Color(0xFFF1F5F9),
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      trf('${cart.count} គ្រឿង', '${cart.count} items'),
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          if (cart.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFE0F2FE), Color(0xFFEDE9FE)],
                      ),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      size: 52,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr('Cart ទទេ'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.maybePop(context),
                    style: FilledButton.styleFrom(backgroundColor: _orange),
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(trf('ទៅមើលទូរស័ព្ទ', 'Browse phones')),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final item in cart.items) _item(cart, item),
              const SizedBox(height: 4),
              _summary(cart),
            ],
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: cart,
        builder: (context, _) => cart.isEmpty
            ? const SizedBox.shrink()
            : Container(
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
                              style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                            Text(
                              money(cart.total),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _orange,
                              minimumSize: const Size.fromHeight(50),
                              elevation: 2,
                              shadowColor: const Color(0x66F97316),
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
