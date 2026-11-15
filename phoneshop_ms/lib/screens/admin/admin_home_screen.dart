import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';
import '../home_screen.dart';
import 'admin_dashboard_tab.dart';
import 'admin_orders_tab.dart';
import 'admin_products_tab.dart';

// How often the admin app asks whether customers placed new orders
const newOrderCheckInterval = Duration(seconds: 10);

// Remembered between visits, so orders placed while the admin was away still show on the badge
const _seenOrderKey = 'admin_seen_order_id';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const _ordersTab = 2;

  int _tab = 0;
  Timer? _timer;
  bool _checking = false;
  int? _seenId; // newest order the admin has looked at on the Orders tab
  int? _knownId; // newest order this app has already announced
  int _unseen = 0;
  int _ordersVersion = 0; // bumped to reload the Orders tab

  static const _titles = ['Dashboard', 'គ្រប់គ្រងទូរស័ព្ទ', 'គ្រប់គ្រង Order'];

  @override
  void initState() {
    super.initState();
    _checkNewOrders();
    _timer = Timer.periodic(newOrderCheckInterval, (_) => _checkNewOrders());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkNewOrders() async {
    if (_checking) return;
    _checking = true;
    try {
      final firstLook = _knownId == null;
      if (firstLook) {
        final prefs = await SharedPreferences.getInstance();
        _seenId = prefs.getInt(_seenOrderKey);
      }
      if (_seenId == null) {
        // First time ever: start from now, the old orders are not news
        final start = await ApiService.fetchNewOrders();
        await _saveSeen(start['latest_id'] as int);
        _knownId = _seenId;
        return;
      }

      final data = await ApiService.fetchNewOrders(after: _seenId);
      final latest = data['latest_id'] as int;
      final orders = (data['orders'] as List).cast<Map<String, dynamic>>();
      // Placed since the last check (not on the first look: those are on the badge)
      final arrived = firstLook
          ? <Map<String, dynamic>>[]
          : orders.where((o) => (o['id'] as int) > _knownId!).toList();
      _knownId = latest;
      if (!mounted) return;
      setState(() {
        _unseen = data['count'] as int;
      });
      if (arrived.isNotEmpty) _announce(arrived);
    } catch (_) {
      // No connection for a moment: the next check tries again
    } finally {
      _checking = false;
    }
  }

  Future<void> _saveSeen(int id) async {
    _seenId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seenOrderKey, id);
  }

  // The pop-up: who ordered and how much, with a shortcut to the orders
  void _announce(List<Map<String, dynamic>> arrived) {
    final newest = arrived.first;
    final text = arrived.length == 1
        ? 'Order ថ្មី #${newest['id']} • ${newest['customer_name']} • ${money(double.parse('${newest['total']}'))}'
        : 'Order ថ្មី ${arrived.length} • ចុងក្រោយ #${newest['id']} ${newest['customer_name']}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0F2A5F),
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Color(0xFFFBBF24)),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
          action: SnackBarAction(
            label: 'មើល',
            textColor: const Color(0xFFFBBF24),
            onPressed: () => _openOrders(reload: true),
          ),
        ),
      );
  }

  void _openOrders({bool reload = false}) {
    setState(() {
      if (reload || _tab == _ordersTab) _ordersVersion++;
      _tab = _ordersTab;
      _unseen = 0;
    });
    if (_knownId != null) _saveSeen(_knownId!);
  }

  void _logout() async {
    _timer?.cancel();
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // The store's bar: navy to teal with rounded bottom corners
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
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
        titleSpacing: 12,
        title: Row(
          children: [
            // The shop's icon, then which part of admin this is
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/images/logo.png',
                width: 34,
                height: 34,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Admin • ${_titles[_tab]}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Order ថ្មី',
            onPressed: _openOrders,
            icon: Badge(
              isLabelVisible: _unseen > 0,
              label: Text('$_unseen'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      // Rebuilt on every tab switch so each tab shows fresh data
      body: switch (_tab) {
        0 => const AdminDashboardTab(),
        1 => const AdminProductsTab(),
        _ => AdminOrdersTab(key: ValueKey(_ordersVersion)),
      },
      // White with rounded top corners like the other bottom bars; the picked tab
      // gets the store menu's gold highlight
      bottomNavigationBar: Container(
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
        clipBehavior: Clip.antiAlias,
        child: NavigationBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          height: 68,
          indicatorColor: const Color(0xFFC08A2E).withValues(alpha: 0.16),
          selectedIndex: _tab,
          onDestinationSelected: (i) =>
              i == _ordersTab ? _openOrders() : setState(() => _tab = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: Color(0xFFC08A2E)),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Icons.phone_android_outlined),
              selectedIcon: Icon(Icons.phone_android, color: Color(0xFFC08A2E)),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _unseen > 0,
                label: Text('$_unseen'),
                child: const Icon(Icons.receipt_long_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: _unseen > 0,
                label: Text('$_unseen'),
                child: const Icon(Icons.receipt_long, color: Color(0xFFC08A2E)),
              ),
              label: 'Orders',
            ),
          ],
        ),
      ),
    );
  }
}
