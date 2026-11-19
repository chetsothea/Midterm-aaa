import 'package:flutter/material.dart';
import '../components/store_app_bar.dart';
import '../components/ux.dart';
import '../data/models/notice.dart';
import '../hooks/language.dart';
import '../hooks/notices.dart';
import '../theme/app_theme.dart';
import '../components/common.dart';
import '../data/api_service.dart';
import 'my_orders_screen.dart';
import 'product_detail_screen.dart';
import 'trade_in_screen.dart';

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return trf('ឥឡូវនេះ', 'just now');
  if (d.inHours < 1) {
    return trf('${d.inMinutes} នាទីមុន', '${d.inMinutes} min ago');
  }
  if (d.inDays < 1) return trf('${d.inHours} ម៉ោងមុន', '${d.inHours} h ago');
  if (d.inDays < 7) return trf('${d.inDays} ថ្ងៃមុន', '${d.inDays} days ago');
  return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
}

// The 🔔 badge for the store's top bar
class NoticesButton extends StatelessWidget {
  const NoticesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Notices.instance,
      builder: (context, _) {
        final n = Notices.instance.unread;
        return IconButton(
          tooltip: trf('ការជូនដំណឹង', 'Notifications'),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(n > 9 ? '9+' : '$n'),
            child: Icon(
              n > 0
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none,
            ),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoticesScreen()),
          ),
        );
      },
    );
  }
}

// What happened to the customer's orders, payments and trade-ins
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Notices.instance.refresh();
    if (!mounted) return;
    setState(() => _loading = false);
    // Seen now; the ones that were new stay highlighted while the page is open
    Notices.instance.markAllRead();
  }

  void _open(Notice n) async {
    // About a phone: open it as it is now
    if (n.productId != null) {
      try {
        final phone = await ApiService.fetchPhone(n.productId!);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(phone: phone)),
        );
      } catch (e) {
        if (mounted) showMessage(context, e.toString(), error: true);
      }
      return;
    }
    final page = n.tradeInId != null
        ? const TradeInScreen()
        : n.orderId != null
        ? const MyOrdersScreen()
        : null;
    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }
  }

  (IconData, Color) _look(Notice n) => switch (n.kind) {
    'payment' => (Icons.payments_outlined, AppColors.green),
    'trade_in' => (Icons.swap_horiz_rounded, AppColors.accent),
    'stock' => (Icons.inventory_2_outlined, AppColors.green),
    'price' => (Icons.trending_down_rounded, AppColors.red),
    _ when n.body.contains('បោះបង់') => (Icons.cancel_outlined, AppColors.red),
    _ => (Icons.local_shipping_outlined, AppColors.accent),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: Text(trf('ការជូនដំណឹង', 'Notifications'))),
      body: _loading
          ? const ListSkeleton(rows: 4)
          : ListenableBuilder(
              listenable: Notices.instance,
              builder: (context, _) {
                final items = Notices.instance.items;
                if (items.isEmpty) {
                  return StatusView(
                    icon: Icons.notifications_none,
                    title: trf('មិនទាន់មានការជូនដំណឹង', 'No notifications yet'),
                    message: trf(
                      'ពេល Order ប្តូរស្ថានភាព ឬហាងទទួលប្រាក់ អ្នកនឹងឃើញនៅទីនេះ',
                      'Order updates and payments will show up here',
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: Notices.instance.refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, indent: 72, color: AppColors.line),
                    itemBuilder: (_, i) {
                      final n = items[i];
                      final (icon, color) = _look(n);
                      return ListTile(
                        tileColor: n.read
                            ? null
                            : AppColors.accent.withValues(alpha: 0.07),
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(
                          n.title,
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: n.read
                                ? FontWeight.w600
                                : FontWeight.w800,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (n.body.isNotEmpty)
                              Text(
                                n.body,
                                style: TextStyle(color: AppColors.text2),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              _ago(n.time),
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _open(n),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
