import 'package:flutter/material.dart';
import '../data/models/order.dart';
import '../data/api_service.dart';
import '../components/common.dart';
import '../components/order_tracking.dart';
import '../hooks/language.dart';
import '../components/shop_refresh.dart';
import '../components/motion.dart';
import '../theme/app_theme.dart';

// Where is my package? Progress, courier, delivery address and every step so far.
// Opens with the order the customer tapped, then reloads it for the latest steps.
class OrderTrackingScreen extends StatefulWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Order _order = widget.order;
  bool _loading = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
    });
    try {
      final fresh = await ApiService.fetchOrder(_order.id);
      if (mounted) {
        setState(() {
          _order = fresh;
        });
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          trf(
            'មិនអាចផ្ទុកព័ត៌មានថ្មីបានទេ: $e',
            'Could not load the latest: $e',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _confirmReceived() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('បានទទួលឥវ៉ាន់ហើយមែនទេ?')),
        content: Text(
          tr(
            'សូមបញ្ជាក់ តែពេលឥវ៉ាន់នៅក្នុងដៃអ្នករួចហើយ។ Admin នឹងឃើញថា Order នេះបានដល់ហើយ។',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('មិនទាន់')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('បានទទួលហើយ')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _confirming = true;
    });
    try {
      final updated = await ApiService.confirmReceived(_order.id);
      if (!mounted) return;
      setState(() {
        _order = updated;
      });
      showMessage(context, tr('សូមអរគុណ! បានបញ្ជាក់ថាទទួលឥវ៉ាន់ហើយ'));
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
      // The admin may have already changed it: show the latest
      if (mounted) _reload();
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Once it's on its way (before that nothing has been sent), until the customer confirms.
      // Also after the admin marked it delivered: only the customer knows it arrived.
      bottomNavigationBar:
          _order.receivedAt != null ||
              (_order.status != 'shipping' && _order.status != 'delivered')
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: FilledButton.icon(
                  onPressed: _confirming ? null : _confirmReceived,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: const Color(0xFF30D158),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(tr('ខ្ញុំបានទទួលឥវ៉ាន់ហើយ')),
                ),
              ),
            ),
      appBar: AppBar(
        title: Text(tr('តាមដានឥវ៉ាន់')),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            // While it reloads, the icon breathes instead of a spinner
            icon: _loading
                ? const Pulse(child: Icon(Icons.sync_rounded))
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _reload,
          ),
        ],
      ),
      backgroundColor: AppColors.page,
      body: ShopRefresh(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            _hero(),
            const SizedBox(height: AppSpacing.sm),
            if (_order.receivedAt != null) ...[
              _receivedNotice(),
              const SizedBox(height: AppSpacing.sm),
            ],
            _card(
              icon: Icons.timeline,
              title: tr('ស្ថានភាព'),
              child: DeliveryProgress(status: _order.status),
            ),
            CourierInfo(order: _order),
            _card(
              icon: Icons.location_on_outlined,
              title: tr('ដឹកទៅ'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_order.customerName} · ${_order.phone}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _order.address,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            _card(
              icon: Icons.shopping_bag_outlined,
              title: tr('ទំនិញ'),
              child: Column(
                children: [for (final item in _order.items) _itemRow(item)],
              ),
            ),
            _card(
              icon: Icons.route_outlined,
              title: tr('ដំណើរឥវ៉ាន់'),
              child: TrackingTimeline(steps: _order.trackings),
            ),
          ],
        ),
      ),
    );
  }

  static Color get _navy => AppColors.text;

  static const _statusIcons = {
    'pending': Icons.receipt_long,
    'confirmed': Icons.inventory_2,
    'shipping': Icons.local_shipping,
    'delivered': Icons.home,
    'cancelled': Icons.cancel,
  };

  // 06/11 10:30, in the customer's own time
  static String _when(DateTime time) {
    final t = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  // The order number, where things stand now in big letters, and the latest step
  Widget _hero() {
    final latest = _order.trackings.isEmpty ? null : _order.trackings.first;
    final cancelled = _order.status == 'cancelled';
    final where = [
      if (latest != null && latest.location.isNotEmpty) '📍 ${latest.location}',
      if (latest != null) _when(latest.time),
    ].join(' • ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cancelled
              ? const [Color(0xFF7F1D1D), Color(0xFFFF453A)]
              : [_navy, Color(0xFF3D7BFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _statusIcons[_order.status] ?? Icons.local_shipping,
              color: const Color(0xFFFBBF24),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ${_order.ref} • ${money(_order.total)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  orderStatusLabels[_order.status] ?? _order.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (where.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    where,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receivedNotice() {
    const green = Color(0xFF30D158);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: const Border(left: BorderSide(color: green, width: 5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trf(
                'អ្នកបានបញ្ជាក់ថាទទួលឥវ៉ាន់ ${_when(_order.receivedAt!)}',
                'You confirmed you got it on ${_when(_order.receivedAt!)}',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // White card with a small coloured heading, like the rest of the app
  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _navy),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, color: _navy),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _itemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(AppSpacing.xxs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [AppColors.surfaceHigh, AppColors.tileLow],
              ),
            ),
            child: PhoneImage(url: item.imageUrl, size: 40),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${item.label} × ${item.qty}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            money(item.price * item.qty),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
