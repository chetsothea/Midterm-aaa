import 'trade_in_screen.dart';
import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../hooks/cart.dart';
import '../data/models/order.dart';
import '../data/models/user.dart';
import '../hooks/favorites.dart';
import '../components/common.dart';
import '../components/confirm_dialog.dart';
import '../components/language_switch.dart';
import '../components/store_app_bar.dart';
import 'favorites_view.dart';
import 'edit_profile_screen.dart';
import 'my_orders_screen.dart';
import '../components/motion.dart';
import '../hooks/language.dart';
import '../components/theme_toggle.dart';
import '../theme/app_theme.dart';

// "Account" in the store menu: the customer's details, their orders, and logout.
// Only for logged-in customers; guests go to Login instead.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  void _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (mounted) setState(() {});
  }

  void _openOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
    );
  }

  void _favorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  // Asks first, so a stray tap doesn't sign the customer out
  void _logout() async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.logout,
      color: Colors.red,
      title: trf('ចាកចេញពីគណនី?', 'Log out?'),
      message: trf(
        'Cart របស់អ្នកនឹងត្រូវសម្អាត។',
        'Your cart will be emptied.',
      ),
      cancelLabel: trf('ទេ', 'No'),
      confirmLabel: 'Logout',
    );
    if (!ok) return;
    await ApiService.logout();
    Cart.instance.clear();
    if (!mounted) return;
    showMessage(context, tr('បាន Logout'));
    Navigator.pop(context); // back to the store
  }

  static Color get _navy => AppColors.text;

  // White card with a soft shadow, the same as the other pages
  static BoxDecoration get _card => BoxDecoration(
    color: AppColors.glass,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  Widget _iconCircle(IconData icon, Color color) => CircleAvatar(
    radius: 19,
    backgroundColor: color.withValues(alpha: 0.12),
    child: Icon(icon, color: color, size: 20),
  );

  Widget _info(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        _iconCircle(icon, const Color(0xFF3D7BFF)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(fontSize: 15, color: AppColors.text2),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _menuItem(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    leading: _iconCircle(icon, color),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );

  // One number in the header: orders so far, on their way, and liked phones.
  // Tapping it opens that list.
  Widget _stat(String value, String label, VoidCallback onTap) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );

  // A small title above a card, with an optional action on the right
  Widget _cardTitle(String title, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _navy,
                fontSize: 15,
              ),
            ),
          ),
          if (action != null)
            TextButton.icon(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3D7BFF),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(action),
            ),
        ],
      ),
    );
  }

  // ខ្មែរ | English, with flags; the whole app switches at once
  Widget _languageSwitch() {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        // Title on one line, the two choices across the full width under it,
        // so it fits a narrow phone
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _iconCircle(Icons.language, const Color(0xFF3D7BFF)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    trf('ភាសា', 'Language'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _navy,
                selectedForegroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('ខ្មែរ'),
                  icon: Flag(svg: cambodiaFlagSvg),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('EN'),
                  icon: Flag(svg: ukFlagSvg),
                ),
              ],
              selected: {AppLanguage.instance.isEnglish},
              onSelectionChanged: (s) =>
                  AppLanguage.instance.setEnglish(s.first),
            ),
          ],
        ),
      ),
    );
  }

  late final Future<List<Order>> _orders = ApiService.fetchMyOrders();

  Widget _header(User user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, Color(0xFF3D7BFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // The picture in a white ring, with a pencil to change it
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  shape: BoxShape.circle,
                ),
                child: UserAvatar(user: user, radius: 42),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: const Color(0xFF3D7BFF),
                  shape: const CircleBorder(
                    side: BorderSide(color: Colors.white, width: 2),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _edit,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: FutureBuilder<List<Order>>(
              future: _orders,
              builder: (context, snapshot) {
                // Still loading, or couldn't load: a dash rather than a wrong 0
                final orders = snapshot.hasData ? snapshot.data! : null;
                final active = orders
                    ?.where(
                      (o) => o.status != 'delivered' && o.status != 'cancelled',
                    )
                    .length;
                return ListenableBuilder(
                  listenable: Favorites.instance,
                  builder: (context, _) => Row(
                    children: [
                      _stat(
                        '${orders?.length ?? '—'}',
                        trf('Order', 'Orders'),
                        _openOrders,
                      ),
                      _stat(
                        '${active ?? '—'}',
                        trf('កំពុងដំណើរការ', 'On the way'),
                        _openOrders,
                      ),
                      _stat(
                        '${Favorites.instance.count}',
                        tr('ចូលចិត្ត'),
                        _favorites,
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

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    if (user == null) return const Scaffold(); // while closing after logout
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: Text(tr('Account'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: Entrance.stagger([
          _header(user),
          const SizedBox(height: AppSpacing.md),
          _cardTitle(
            trf('ព័ត៌មានផ្ទាល់ខ្លួន', 'Your details'),
            action: trf('កែ', 'Edit'),
            onAction: _edit,
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: _card,
            child: Column(
              children: [
                _info(Icons.email_outlined, 'Email', user.email),
                _info(Icons.phone_outlined, tr('លេខទូរស័ព្ទ'), user.phone),
                _info(
                  Icons.location_on_outlined,
                  tr('អាសយដ្ឋាន'),
                  user.address,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: _card,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  _menuItem(
                    Icons.edit_outlined,
                    const Color(0xFF2563EB),
                    tr('កែព័ត៌មាន'),
                    tr('ឈ្មោះ លេខទូរស័ព្ទ អាសយដ្ឋាន និងរូបភាព'),
                    _edit,
                  ),
                  const Divider(height: 1, indent: 66),
                  _menuItem(
                    Icons.receipt_long_outlined,
                    const Color(0xFF3D7BFF),
                    tr('Order របស់ខ្ញុំ'),
                    tr('មើលស្ថានភាព និងតាមដានឥវ៉ាន់'),
                    _openOrders,
                  ),
                  const Divider(height: 1, indent: 66),
                  _menuItem(
                    Icons.favorite_border,
                    const Color(0xFFFF453A),
                    tr('ចូលចិត្ត'),
                    trf('ទូរស័ព្ទដែលអ្នករក្សាទុក', 'Phones you saved'),
                    _favorites,
                  ),
                  const Divider(height: 1, indent: 66),
                  _menuItem(
                    Icons.swap_horiz_rounded,
                    const Color(0xFF30D158),
                    trf(
                      'ប្តូរទូរស័ព្ទចាស់ (Trade-in)',
                      'Trade in your old phone',
                    ),
                    trf(
                      'លក់ទូរស័ព្ទចាស់ ជាកូដបញ្ចុះទិញថ្មី',
                      'Turn it into credit for a new one',
                    ),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TradeInScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _cardTitle(trf('ការកំណត់', 'Settings')),
          // Settings: language, then dark / light mode
          Container(
            decoration: _card,
            child: Column(
              children: [
                _languageSwitch(),
                const Divider(height: 1),
                const ThemeSwitchTile(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              backgroundColor: AppColors.surface,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'PS168 • v1.0.0',
              style: TextStyle(color: Colors.black38, fontSize: 12),
            ),
          ),
        ]),
      ),
    );
  }
}
