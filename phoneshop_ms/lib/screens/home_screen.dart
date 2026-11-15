import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/phone.dart';
import '../services/api_service.dart';
import '../services/cart.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/motion.dart';
import '../widgets/brand_row.dart';
import '../widgets/common.dart';
import '../widgets/language_switch.dart';
import '../widgets/product_card.dart';
import '../widgets/store_menu.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'favorites_view.dart';
import 'login_screen.dart';
import 'my_orders_screen.dart';
import 'product_detail_screen.dart';
import '../services/language.dart';
import '../widgets/brand_wordmark.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _banners = [
    'assets/images/banner_1.jpg',
    'assets/images/banner_2.jpg',
    'assets/images/banner_3.jpg',
  ];

  late Future<List<Phone>> _phones;
  Map<String, dynamic>? _menu;
  int _activeOrders = 0; // shown on Order in the bottom menu
  String _search = '';
  bool _searching = false; // the search field replaces the logo in the top bar
  final _searchField = TextEditingController();
  StoreFilter _filter = StoreFilter.home;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchField.dispose();
    super.dispose();
  }

  // Closing the field also clears the search and shows every phone again
  void _toggleSearch() {
    if (!_searching) {
      setState(() => _searching = true);
      return;
    }
    _searchField.clear();
    _searching = false;
    _search = '';
    _refresh();
  }

  void _load() {
    _phones = ApiService.fetchPhones(
      search: _search,
      brand: _filter.brand,
      categoryId: _filter.categoryId,
    );
    _loadActiveOrders();
    // Reload the menu too, so brands/categories the admin just added show up
    ApiService.fetchMenu()
        .then((menu) {
          if (mounted) setState(() => _menu = menu);
        })
        .catchError((_) {});
  }

  // How many of the customer's orders are still on their way (0 for guests)
  void _loadActiveOrders() {
    if (!ApiService.isLoggedIn) {
      _activeOrders = 0;
      return;
    }
    ApiService.fetchMyOrders()
        .then((orders) {
          if (!mounted) return;
          setState(() {
            _activeOrders = orders
                .where(
                  (o) => o.status != 'delivered' && o.status != 'cancelled',
                )
                .length;
          });
        })
        .catchError((_) {});
  }

  Future<void> _refresh() async {
    setState(_load);
    await _phones;
  }

  void _select(StoreFilter filter) {
    _filter = filter;
    _refresh();
  }

  // A customer's orders; guests log in first
  void _openOrders() async {
    if (!await requireLogin(
          context,
          reason: tr('សូម Login ដើម្បីមើល Order របស់អ្នក'),
        ) ||
        !mounted) {
      return;
    }
    setState(() {}); // the greeting follows the login
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
    );
    _refresh(); // stock may have changed if an order was cancelled
  }

  void _openFavorites() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
    _refresh();
  }

  // Login, register, my orders and logout all live on the Account screen
  void _openAccount() async {
    // Guests go straight to Login; logged-in customers see their account page
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ApiService.isLoggedIn ? const AccountScreen() : const LoginScreen(),
      ),
    );
    if (!mounted) return;
    setState(() {}); // the greeting follows login / logout
    _loadActiveOrders(); // and so does the number on Order
  }

  void _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
    _refresh(); // stock may have changed after an order
  }

  // Chat with the shop in the Telegram app (or the browser if it isn't installed)
  void _openTelegram() async {
    final username = (_menu?['telegram'] ?? '') as String;
    if (username.isEmpty) {
      showMessage(
        context,
        tr('ហាងមិនទាន់បានកំណត់ Telegram នៅឡើយទេ'),
        error: true,
      );
      return;
    }
    final opened = await launchUrl(
      Uri.parse('https://t.me/$username'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showMessage(context, tr('មិនអាចបើក Telegram បានទេ'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      // The page runs on under the floating bottom menu, so its glass has something to blur
      extendBody: true,
      drawer: StoreDrawer(menu: _menu, current: _filter, onSelected: _select),
      appBar: AppBar(
        foregroundColor: Colors.white,
        // Rounded bottom corners, so the page seems to flow out from under the bar
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        backgroundColor: Colors.transparent,
        // Navy to teal, the colours of the shop's logo
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            gradient: LinearGradient(
              colors: [Color(0xFF0F2A5F), Color(0xFF0E7490)],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                color: Color(0x330F2A5F),
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        // ☰ next to the shop name; gold while a category or brand is selected
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            icon: Icon(
              Icons.menu,
              color: _filter == StoreFilter.home
                  ? null
                  : StoreMenuBar.activeColor,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: _searching
            ? TextField(
                controller: _searchField,
                autofocus: true,
                textInputAction: TextInputAction.search,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: tr('ស្វែងរកទូរស័ព្ទ...'),
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (value) {
                  _search = value.trim();
                  _refresh();
                },
              )
            : user == null
            ? Align(
                alignment: Alignment.centerLeft,
                child: Shine(child: const BrandWordmark(height: 17)),
              )
            : Text(
                trf('សួស្តី ${user.name}', 'Hello ${user.name}'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          FavoritesButton(onPressed: _openFavorites),

          // Last, at the right edge
          if (!_searching) const LanguageButton(),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: StoreMenuBar(
        current: _filter,
        user: user,
        onSelected: _select,
        onTelegram: _openTelegram,
        onAccount: _openAccount,
        onOrders: _openOrders,
        onCart: _openCart,
        activeOrders: _activeOrders,
      ),
      body: Column(
        children: [
          if (_filter.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(_filter.label),
                  onDeleted: () => _select(StoreFilter.home),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Phone>>(
              future: _phones,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text(tr('មិនមានទិន្នន័យទូរស័ព្ទទេ')));
                }

                final all = snapshot.data!;
                // Biggest discount first; in stock only on the main page's row
                final onSale = all.where((p) => p.hasDiscount).toList()
                  ..sort(
                    (a, b) => b.discountPercent.compareTo(a.discountPercent),
                  );
                final phones = _filter == StoreFilter.sale ? onSale : all;
                final onMainPage =
                    _filter == StoreFilter.home && _search.isEmpty;
                final brands = List<String>.from(_menu?['brands'] ?? []);
                final deals = onSale.where((p) => p.stock > 0).toList();
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    slivers: [
                      // Only on the main page: filtered results stay at the top
                      if (onMainPage)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: BannerCarousel(images: _banners),
                          ),
                        ),
                      if (onMainPage && brands.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: BrandRow(
                              brands: brands,
                              onSelected: (brand) => _select(
                                StoreFilter(section: 'brands', brand: brand),
                              ),
                            ),
                          ),
                        ),
                      // The deals sit on a warm band of their own, so the sale
                      // stands out from the plain list further down
                      if (onMainPage && deals.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                            padding: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFF1E6), Color(0xFFFDE7EF)],
                              ),
                            ),
                            child: Column(
                              children: [
                                _sectionTitle(
                                  tr('កំពុងបញ្ចុះតម្លៃ'),
                                  icon: Icons.local_fire_department,
                                  onSeeAll: () => _select(StoreFilter.sale),
                                ),
                                SizedBox(
                                  height:
                                      352, // a card, plus room for its shadow
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      6,
                                      10,
                                      6,
                                    ),
                                    itemCount: deals.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) => SizedBox(
                                      width: 170,
                                      child: _cardFor(deals[index], 'deals'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: _sectionTitle(
                          _filter.label.isEmpty
                              ? tr('POPULAR PRODUCTS')
                              : _filter.label.toUpperCase(),
                          icon: Icons.grid_view_rounded,
                          count: phones.length,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 230,
                                mainAxisExtent:
                                    340, // fixed height so text and buttons never overflow
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: phones.length,
                          itemBuilder: (context, index) => Entrance(
                            index: index,
                            child: _cardFor(phones[index], 'list'),
                          ),
                        ),
                      ),
                      // Room to scroll the last phones up from behind the bottom menu
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.paddingOf(context).bottom,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // [onSeeAll] adds "See all ›" on the right, and makes the whole title tappable
  Widget _sectionTitle(
    String title, {
    IconData? icon,
    VoidCallback? onSeeAll,
    int? count, // how many phones the section holds, shown after the title
  }) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF97316), Color(0xFFE11D48)],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (icon != null) ...[
            Icon(icon, color: const Color(0xFFE11D48), size: 22),
            const SizedBox(width: 4),
          ],
          // Always one line: shrinks a little on a narrow phone instead of
          // breaking a Khmer word across two lines
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F2A5F),
                ),
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2A5F).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F2A5F),
                ),
              ),
            ),
          ],
          const Spacer(),
          // A small tinted pill, so it reads as a button
          if (onSeeAll != null)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0E7490).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('មើលទាំងអស់'),
                    style: const TextStyle(
                      color: Color(0xFF0E7490),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFF0E7490),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return onSeeAll == null ? row : InkWell(onTap: onSeeAll, child: row);
  }

  // [section] keeps the picture's Hero tag unique: a phone on sale is in both rows
  Widget _cardFor(Phone phone, String section) {
    final heroTag = 'phone-$section-${phone.id}';
    Future<void> openDetail() async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(phone: phone, heroTag: heroTag),
        ),
      );
      _refresh();
    }

    return ProductCard(
      phone: phone,
      heroTag: heroTag,
      onTap: openDetail,
      onAddToCart: () async {
        // Several colours or sizes: the customer has to pick on the detail screen
        if (phone.colors.length > 1 || phone.storageOptions.length > 1) {
          openDetail();
          showMessage(context, tr('សូមជ្រើសពណ៌ / Storage'), info: true);
          return;
        }
        if (!await requireLogin(context) || !mounted) return;
        setState(() {}); // the greeting follows the login
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
      },
    );
  }
}
