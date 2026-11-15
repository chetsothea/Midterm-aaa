import 'package:flutter/material.dart';
import '../models/phone.dart';
import '../services/api_service.dart';
import '../services/cart.dart';
import '../services/favorites.dart';
import '../services/language.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';

const _navy = Color(0xFF0F2A5F);
const _muted = Color(0xFF64748B);
const _red = Color(0xFFE11D48);
const _orange = Color(0xFFF97316);

// Its own page, opened from ♡ in the top bar
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: Text(tr('ចូលចិត្ត'))),
      body: const FavoritesView(),
    );
  }
}

// The phones the customer tapped ♥ on, with their current price and stock
class FavoritesView extends StatefulWidget {
  const FavoritesView({super.key});

  @override
  State<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<FavoritesView> {
  late Future<List<Phone>> _phones = ApiService.fetchPhones();

  Future<void> _refresh() async {
    setState(() {
      _phones = ApiService.fetchPhones();
    });
    await _phones;
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFE4E6), Color(0xFFEDE9FE)],
                ),
              ),
              child: const Icon(Icons.favorite_border, size: 52, color: _red),
            ),
            const SizedBox(height: 14),
            Text(
              tr('មិនទាន់មានទូរស័ព្ទដែលអ្នកចូលចិត្តទេ'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _navy,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('ចុច ♥ លើទូរស័ព្ទ ដើម្បីរក្សាទុកនៅទីនេះ'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            if (Navigator.canPop(context)) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.maybePop(context),
                style: FilledButton.styleFrom(backgroundColor: _orange),
                icon: const Icon(Icons.storefront_outlined),
                label: Text(trf('ទៅមើលទូរស័ព្ទ', 'Browse phones')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetail(Phone phone) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(phone: phone)),
    );
    _refresh(); // price or stock may have changed
  }

  // Same as the store cards: a phone with several colours or sizes is picked on its page
  void _addToCart(Phone phone) async {
    if (phone.colors.length > 1 || phone.storageOptions.length > 1) {
      _openDetail(phone);
      showMessage(context, tr('សូមជ្រើសពណ៌ / Storage'), info: true);
      return;
    }
    if (!await requireLogin(context) || !mounted) return;
    final ok = Cart.instance.add(
      phone,
      1,
      phone.colors.firstOrNull ?? '',
      phone.storageOptions.firstOrNull?.storage ?? '',
    );
    showMessage(
      context,
      ok
          ? trf(
              'បានបន្ថែម ${phone.name} ទៅ Cart',
              'Added ${phone.name} to cart',
            )
          : tr('ស្តុកមិនគ្រប់គ្រាន់'),
      error: !ok,
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _item(Phone phone) {
    final soldOut = phone.stock <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(phone),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // The picture, with the sale badge like on the store cards
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 84,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE0F2FE), Color(0xFFEDE9FE)],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: PhoneImage(url: phone.imageUrl, size: 76),
                    ),
                    if (phone.hasDiscount)
                      Positioned(
                        top: -4,
                        left: -4,
                        child: DiscountBadge(
                          percent: phone.discountPercent,
                          fontSize: 10,
                        ),
                      ),
                  ],
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
                              phone.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _navy,
                              ),
                            ),
                          ),
                          SizedBox.square(
                            dimension: 30,
                            child: IconButton(
                              tooltip: tr('ដកចេញពីចំណូលចិត្ត'),
                              padding: EdgeInsets.zero,
                              iconSize: 22,
                              icon: const Icon(Icons.favorite, color: _red),
                              onPressed: () =>
                                  Favorites.instance.toggle(phone.id),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(
                            money(phone.price),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: phone.hasDiscount ? _red : _navy,
                            ),
                          ),
                          if (phone.hasDiscount)
                            Text(
                              money(phone.oldPrice!),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (soldOut)
                                  _pill(tr('អស់ស្តុក'), _red)
                                else
                                  _pill(
                                    trf(
                                      'នៅសល់ ${phone.stock}',
                                      '${phone.stock} in stock',
                                    ),
                                    const Color(0xFF2563EB),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 34,
                            child: FilledButton(
                              onPressed: soldOut
                                  ? null
                                  : () => _addToCart(phone),
                              style: FilledButton.styleFrom(
                                backgroundColor: _orange,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart,
                                size: 18,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Favorites.instance,
      builder: (context, _) {
        if (Favorites.instance.count == 0) return _empty();
        return FutureBuilder<List<Phone>>(
          future: _phones,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            // Phones the shop has since removed are simply left out
            final liked = [
              for (final phone in snapshot.data!)
                if (Favorites.instance.contains(phone.id)) phone,
            ];
            if (liked.isEmpty) return _empty();
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      trf(
                        '${liked.length} ទូរស័ព្ទដែលអ្នកចូលចិត្ត',
                        '${liked.length} liked phones',
                      ),
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final phone in liked) _item(phone),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
