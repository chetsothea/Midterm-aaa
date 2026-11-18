import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/phone.dart';
import '../data/api_service.dart';
import '../hooks/cart.dart';
import '../components/banner_carousel.dart';
import '../components/motion.dart';
import '../components/brand_row.dart';
import '../components/common.dart';
import '../components/language_switch.dart';
import '../components/product_card.dart';
import '../components/store_menu.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'favorites_view.dart';
import 'login_screen.dart';
import 'my_orders_screen.dart';
import 'product_detail_screen.dart';
import '../hooks/language.dart';
import '../components/brand_wordmark.dart';
import '../components/ux.dart';
import '../components/live_banner.dart';
import '../data/models/live.dart';
import 'live_shopping_screen.dart';
import '../components/hero_phone.dart';
import '../components/product_filter.dart';
import 'compare_screen.dart';
import '../components/theme_toggle.dart';
import '../hooks/live.dart';
import '../components/effects.dart';
import '../components/category_tiles.dart';
import '../components/shop_refresh.dart';
import '../theme/app_theme.dart';

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
  final _scroll = ScrollController(); // for the back-to-top button and parallax
  Timer? _refreshTimer; // quietly re-reads prices and stock every few seconds
  StoreFilter _filter = StoreFilter.home;
  ProductFilter _productFilter = ProductFilter.none; // brand / price / storage
  LiveSession _live = LiveSession.off; // the seller's live stream, when on
  List<(Phone, int)> _bestSellers = []; // the carousel at the top

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Live.poll(() => context, _refreshQuietly);
  }

  @override
  void dispose() {
    _searchField.dispose();
    _scroll.dispose();
    _refreshTimer?.cancel();
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
    _loadLive();
    _loadBestSellers();
    // Reload the menu too, so brands/categories the admin just added show up
    ApiService.fetchMenu()
        .then((menu) {
          if (mounted) setState(() => _menu = menu);
        })
        .catchError((_) {});
  }

  // The best-selling phones for the carousel at the top
  void _loadBestSellers() {
    ApiService.fetchBestSellers()
        .then((list) {
          if (mounted) setState(() => _bestSellers = list);
        })
        .catchError((_) {});
  }

  // Whether the seller is live right now (shows the LIVE card on top)
  void _loadLive() {
    ApiService.fetchLive()
        .then((live) {
          if (mounted) setState(() => _live = live);
        })
        .catchError((_) {});
  }

  void _openLive() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveShoppingScreen(session: _live)),
    );
    _loadLive();
    _refresh(); // stock may have changed after buying in the live
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

  // A background refresh: the page stays as it is (no skeleton, no jump) and
  // only the numbers that changed roll to their new value
  Future<void> _refreshQuietly() async {
    try {
      final phones = await ApiService.fetchPhones(
        search: _search,
        brand: _filter.brand,
        categoryId: _filter.categoryId,
      );
      if (mounted) setState(() => _phones = Future.value(phones));
      _loadLive();
    } catch (_) {
      // Offline for a moment: keep what is on screen
    }
  }

  Future<void> _refresh() async {
    setState(_load);
    await _phones;
  }

  // From an empty search / filter back to the whole store
  void _showEverything() {
    _searchField.clear();
    _searching = false;
    _search = '';
    _select(StoreFilter.home);
  }

  void _select(StoreFilter filter) {
    Haptics.tap();
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
      backgroundColor: AppColors.page,
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
        // Navy, teal and indigo light drifting behind the logo (GPU blur)
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                color: AppColors.shadow,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AuroraBackground(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
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
          // ☀️ / 🌙: dark or light mode, first, so 🔍 ♥ 🌐 stay side by side
          if (!_searching) const ThemeToggleButton(),
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          FavoritesButton(onPressed: _openFavorites),

          // Last, at the right edge
          if (!_searching) const LanguageButton(),
          const SizedBox(width: AppSpacing.xs),
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76), // clear of the bottom menu
        child: BackToTop(controller: _scroll),
      ),
      body: Column(
        children: [
          if (_filter.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
                // Skeleton cards where the real ones will land
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const StoreSkeleton();
                } else if (snapshot.hasError) {
                  return StatusView(
                    icon: Icons.wifi_off_rounded,
                    error: true,
                    title: trf(
                      'មិនអាចភ្ជាប់ទៅហាងបានទេ',
                      "Can't reach the shop",
                    ),
                    message: trf(
                      'សូមពិនិត្យអ៊ីនធឺណិត ហើយព្យាយាមម្តងទៀត',
                      'Check your internet and try again',
                    ),
                    actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
                    onAction: _refresh,
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  final filtered =
                      _search.isNotEmpty || _filter != StoreFilter.home;
                  return StatusView(
                    icon: filtered
                        ? Icons.search_off_rounded
                        : Icons.phone_iphone_rounded,
                    title: tr('មិនមានទិន្នន័យទូរស័ព្ទទេ'),
                    message: filtered
                        ? trf(
                            'សាកស្វែងរកពាក្យផ្សេង ឬមើលទូរស័ព្ទទាំងអស់',
                            'Try another word, or see every phone',
                          )
                        : null,
                    actionLabel: filtered
                        ? trf('មើលទាំងអស់', 'See all phones')
                        : trf('ផ្ទុកឡើងវិញ', 'Reload'),
                    actionIcon: filtered
                        ? Icons.apps_rounded
                        : Icons.refresh_rounded,
                    onAction: filtered ? _showEverything : _refresh,
                  );
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
                // Newest first (the highest id was added last), in stock only.
                // Only for a bigger shop: with a handful of phones the row would
                // just repeat the grid below it.
                final newArrivals = all.length < 8
                    ? <Phone>[]
                    : (all.where((p) => p.stock > 0).toList()
                            ..sort((a, b) => b.id.compareTo(a.id)))
                          .take(8)
                          .toList();
                // Best sellers from the API; until they arrive (or if that
                // fails) the priciest phone in stock on its own
                final flagship = HeroPhoneCard.pickFlagship(all);
                final heroPhones = _bestSellers.isNotEmpty
                    ? _bestSellers
                    : [if (flagship != null) (flagship, 0)];
                // The grid after the brand / price / storage filter
                final shown = _productFilter.apply(phones);
                return ShopRefresh(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      // The seller is live: the first thing on the page
                      if (onMainPage && _live.isLive)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: PopIn(
                              child: LiveNowCard(
                                session: _live,
                                onJoin: _openLive,
                              ),
                            ),
                          ),
                        ),
                      // The best sellers, sliding by, each turning in 3D
                      if (onMainPage && heroPhones.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Entrance(
                              child: HeroCarousel(
                                phones: heroPhones,
                                onOpen: (phone) => _openDetail(phone, 'hero'),
                              ),
                            ),
                          ),
                        ),
                      // Only on the main page: filtered results stay at the top
                      if (onMainPage)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: _Parallax(
                              controller: _scroll,
                              child: const BannerCarousel(images: _banners),
                            ),
                          ),
                        ),
                      // Rounded category shortcuts, like the side menu's list
                      if (onMainPage)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: CategoryTiles(
                              categories: List<Map<String, dynamic>>.from(
                                _menu?['categories'] ?? [],
                              ),
                              hasDeals: deals.isNotEmpty,
                              onSelected: _select,
                            ),
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
                      if (onMainPage && newArrivals.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _sectionTitle(
                                trf('ទើបមកដល់', 'New arrivals'),
                                icon: Icons.auto_awesome_rounded,
                              ),
                              _cardRow(newArrivals, 'new'),
                            ],
                          ),
                        ),
                      if (onMainPage && deals.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                            padding: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppRadius.xxl,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.surface,
                                  AppColors.tileLower,
                                ],
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
                                        const SizedBox(width: AppSpacing.sm),
                                    itemBuilder: (context, index) => SizedBox(
                                      width: 170,
                                      child: PopIn(
                                        index: index,
                                        child: Tilt3D(
                                          child: _cardFor(
                                            deals[index],
                                            'deals',
                                          ),
                                        ),
                                      ),
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
                          count: shown.length,
                          live: true, // prices and stock refresh by themselves
                          trailing: [
                            IconButton(
                              tooltip: trf('ប្រៀបធៀប', 'Compare'),
                              icon: const Icon(Icons.compare_arrows_rounded),
                              color: AppColors.textSoft,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CompareScreen(phones: all),
                                ),
                              ),
                            ),
                            FilterButton(
                              filter: _productFilter,
                              onPressed: () async {
                                final picked = await showProductFilter(
                                  context,
                                  phones: phones,
                                  current: _productFilter,
                                );
                                if (picked != null && mounted) {
                                  setState(() => _productFilter = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      if (shown.isEmpty && _productFilter.isActive)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 320,
                            child: StatusView(
                              icon: Icons.tune_rounded,
                              title: trf(
                                'គ្មានទូរស័ព្ទត្រូវនឹងតម្រង',
                                'No phones match the filter',
                              ),
                              actionLabel: trf('សម្អាតតម្រង', 'Clear filter'),
                              actionIcon: Icons.close_rounded,
                              onAction: () => setState(
                                () => _productFilter = ProductFilter.none,
                              ),
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 230,
                                mainAxisExtent:
                                    340, // fixed height so text and buttons never overflow
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: shown.length,
                          itemBuilder: (context, index) => Entrance(
                            index: index,
                            child: Tilt3D(
                              child: _cardFor(shown[index], 'list'),
                            ),
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
    bool live = false, // a pulsing "LIVE" on the right
    List<Widget> trailing = const [], // buttons at the right end
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
                colors: [Color(0xFF3D7BFF), Color(0xFFFF453A)],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (icon != null) ...[
            PopIn(child: Icon(icon, color: const Color(0xFFFF453A), size: 22)),
            const SizedBox(width: AppSpacing.xxs),
          ],
          // Always one line: shrinks a little on a narrow phone instead of
          // breaking a Khmer word across two lines
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              // Flips up into view, then a gleam runs across it now and then
              child: MotionTitle(
                title,
                key: ValueKey(title),
                // Big, bold, tight: the Apple Store way of heading a section
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.text.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: RollingText(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (live && onSeeAll == null) const LiveDot(),
          ...trailing,
          // A small tinted pill, so it reads as a button
          if (onSeeAll != null)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3D7BFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('មើលទាំងអស់'),
                    style: const TextStyle(
                      color: Color(0xFF3D7BFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFF3D7BFF),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return onSeeAll == null ? row : InkWell(onTap: onSeeAll, child: row);
  }

  // A sideways row of cards (New arrivals)
  Widget _cardRow(List<Phone> phones, String section) {
    return SizedBox(
      height: 352, // a card, plus room for its shadow
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        itemCount: phones.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => SizedBox(
          width: 170,
          child: PopIn(
            index: index,
            child: Tilt3D(child: _cardFor(phones[index], section)),
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(Phone phone, String section) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          phone: phone,
          heroTag: 'phone-$section-${phone.id}',
        ),
      ),
    );
    _refresh();
  }

  // [section] keeps the picture's Hero tag unique: a phone on sale is in both rows
  Widget _cardFor(Phone phone, String section) {
    final heroTag = 'phone-$section-${phone.id}';
    Future<void> openDetail() => _openDetail(phone, section);

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
        ok ? Haptics.success() : Haptics.warning();
      },
    );
  }
}

// The banner drifts down slower than the page and fades a little as it
// scrolls away, so it feels further back than the cards (parallax).
class _Parallax extends StatelessWidget {
  final ScrollController controller;
  final Widget child;

  const _Parallax({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Motion.off(context)) return child;
    return ListenableBuilder(
      listenable: controller,
      child: child,
      builder: (context, child) {
        final offset = controller.hasClients
            ? controller.offset.clamp(0.0, 300.0)
            : 0.0;
        return Transform.translate(
          offset: Offset(0, offset * 0.45),
          child: Transform.scale(
            scale: 1 - offset / 3000,
            child: Opacity(opacity: 1 - offset / 600, child: child),
          ),
        );
      },
    );
  }
}
