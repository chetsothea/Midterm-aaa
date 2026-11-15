import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/store_app_bar.dart';
import 'invoice_screen.dart';
import 'order_tracking_screen.dart';
import 'payment_screen.dart';
import '../services/language.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<List<Order>> _orders = ApiService.fetchMyOrders();

  Future<void> _refresh() async {
    // Block body: an arrow would return the Future, which setState() rejects
    setState(() {
      _orders = ApiService.fetchMyOrders();
    });
    await _orders;
  }

  void _pay(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(order: order)),
    );
    _refresh();
  }

  // A cancelled or received order the customer no longer wants to see. Only off
  // their list: the shop keeps its record.
  void _hide(Order order) async {
    final received = order.status == 'delivered';
    final ok = await showConfirmDialog(
      context,
      icon: Icons.delete_outline,
      color: Colors.red,
      title: trf(
        'លុប Order នេះចេញពីបញ្ជី?',
        'Remove this order from your list?',
      ),
      code: order.ref,
      message: received
          ? trf(
              'អ្នកបានទទួលឥវ៉ាន់រួចហើយ។ Order នេះនឹងលែងបង្ហាញក្នុងបញ្ជីរបស់អ្នកទៀតហើយ។',
              "You've received this order. It won't show in your list any more.",
            )
          : trf(
              'Order ដែលបានបោះបង់នេះ នឹងលែងបង្ហាញក្នុងបញ្ជីរបស់អ្នកទៀតហើយ។',
              "This cancelled order won't show in your list any more.",
            ),
      cancelLabel: trf('ទេ', 'No'),
      confirmLabel: trf('លុបចេញ', 'Remove'),
    );
    if (!ok) return;
    try {
      await ApiService.hideOrder(order.id);
      if (mounted) {
        showMessage(
          context,
          trf('បានលុប Order ${order.ref} ចេញ', 'Order ${order.ref} removed'),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  void _cancel(Order order) async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.remove_shopping_cart_outlined,
      color: Colors.red,
      title: trf('បោះបង់ Order នេះ?', 'Cancel this order?'),
      code: order.ref,
      message: trf(
        'Order នឹងត្រូវបានបោះបង់ ហើយមិនអាចយកមកវិញបានទេ។',
        "The order will be cancelled and can't be brought back.",
      ),
      cancelLabel: trf('ទេ, រក្សាទុក', 'No, keep it'),
      confirmLabel: trf('បោះបង់', 'Yes, cancel'),
    );
    if (!ok) return;
    try {
      await ApiService.cancelOrder(order.id);
      if (mounted) {
        showMessage(
          context,
          trf('បានបោះបង់ Order ${order.ref}', 'Order ${order.ref} cancelled'),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  // Which orders the chips at the top show
  String _filter = 'all';

  static bool _isActive(Order o) =>
      o.status != 'delivered' && o.status != 'cancelled';

  List<Order> _filtered(List<Order> all) => switch (_filter) {
    'active' => all.where(_isActive).toList(),
    'delivered' => all.where((o) => o.status == 'delivered').toList(),
    'cancelled' => all.where((o) => o.status == 'cancelled').toList(),
    _ => all,
  };

  // ទាំងអស់ 5 · កំពុងដំណើរការ 2 · បានទទួល 2 · បានបោះបង់ 1
  Widget _filters(List<Order> all) {
    final counts = {
      'all': all.length,
      'active': all.where(_isActive).length,
      'delivered': all.where((o) => o.status == 'delivered').length,
      'cancelled': all.where((o) => o.status == 'cancelled').length,
    };
    final labels = {
      'all': trf('ទាំងអស់', 'All'),
      'active': trf('កំពុងដំណើរការ', 'In progress'),
      'delivered': trf('បានទទួល', 'Received'),
      'cancelled': trf('បានបោះបង់', 'Cancelled'),
    };
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        children: [
          for (final key in labels.keys)
            if (key == 'all' || counts[key]! > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  selected: _filter == key,
                  selectedColor: _navy,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _filter == key ? _navy : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  label: Text(
                    '${labels[key]}  ${counts[key]}',
                    style: TextStyle(
                      color: _filter == key ? Colors.white : _navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  onSelected: (_) => setState(() => _filter = key),
                ),
              ),
        ],
      ),
    );
  }

  // No orders yet: a friendly picture and a way back to the phones
  Widget _empty() {
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
              Icons.receipt_long_outlined,
              size: 52,
              color: _navy,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr('មិនទាន់មាន Order នៅឡើយ'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.maybePop(context),
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.storefront_outlined),
            label: Text(trf('ទៅមើលទូរស័ព្ទ', 'Browse phones')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: storeAppBar(title: Text(tr('Order របស់ខ្ញុំ'))),
      body: FutureBuilder<List<Order>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.data!.isEmpty) {
            return _empty();
          }
          final all = snapshot.data!;
          final shown = _filtered(all);
          return Column(
            children: [
              _filters(all),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                    children: [
                      for (final order in shown) _orderCard(order),
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Center(
                            child: Text(
                              trf(
                                'មិនមាន Order ក្នុងផ្នែកនេះ',
                                'No orders here',
                              ),
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static const _navy = Color(0xFF0F2A5F);
  static const _orange = Color(0xFFF97316);
  // The same rounded corners as the store's other buttons
  static final _rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  // 05/11/2026, in the customer's own time
  static String _date(DateTime time) {
    final t = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year}';
  }

  Widget _orderCard(Order order) {
    final canPay =
        order.paymentMethod == 'khqr' &&
        order.paymentStatus == 'unpaid' &&
        order.status != 'cancelled';
    final canCancel =
        order.status == 'pending' && order.paymentStatus == 'unpaid';
    final color = statusColor(order.status);
    final first = order.items.isEmpty ? null : order.items.first;
    final more = order.items.length - 1;
    final location = order.trackings.isNotEmpty
        ? order.trackings.first.location
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        // The order's status colour down the left edge
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order number and date, then the total
            Row(
              children: [
                // The code, with the date under it; shrinks on a narrow phone
                // instead of running past the edge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Order ${order.ref}',
                          maxLines: 1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _navy,
                          ),
                        ),
                      ),
                      Text(
                        _date(order.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  status: order.status,
                  label: orderStatusLabels[order.status]!,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // What was bought: the first phone's picture and name
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE0F2FE), Color(0xFFEDE9FE)],
                    ),
                  ),
                  child: PhoneImage(url: first?.imageUrl ?? '', size: 52),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first?.productName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (first != null)
                        Text(
                          [
                            if (first.color.isNotEmpty) first.color,
                            if (first.storage.isNotEmpty) first.storage,
                            '× ${first.qty}',
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      if (more > 0)
                        Text(
                          trf('+ $more ទៀត', '+ $more more'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(order.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusBadge(
                      status: order.paymentStatus,
                      label: paymentStatusLabels[order.paymentStatus]!,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _progress(order.status),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 22),
            // The main thing to do next across the width, the rest as small buttons
            Row(
              children: [
                Expanded(
                  child: order.status == 'cancelled'
                      // Nothing left to track: offer to clear it off the list
                      ? OutlinedButton.icon(
                          onPressed: () => _hide(order),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: _rounded,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(trf('លុបចេញពីបញ្ជី', 'Remove from list')),
                        )
                      : canPay
                      ? FilledButton.icon(
                          onPressed: () => _pay(order),
                          style: FilledButton.styleFrom(
                            backgroundColor: _orange,
                            shape: _rounded,
                          ),
                          icon: const Icon(Icons.qr_code_2, size: 18),
                          label: Text(tr('បង់ប្រាក់')),
                        )
                      : FilledButton.tonalIcon(
                          onPressed: () => _track(order),
                          style: FilledButton.styleFrom(shape: _rounded),
                          icon: const Icon(
                            Icons.local_shipping_outlined,
                            size: 18,
                          ),
                          label: Text(tr('តាមដានឥវ៉ាន់')),
                        ),
                ),
                const SizedBox(width: 6),
                if (canPay)
                  IconButton.outlined(
                    tooltip: tr('តាមដានឥវ៉ាន់'),
                    onPressed: () => _track(order),
                    icon: const Icon(Icons.local_shipping_outlined, size: 20),
                  ),
                IconButton.outlined(
                  tooltip: tr('វិក្កយបត្រ'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceScreen(order: order),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 20),
                ),
                // Received: done with it, so it can be cleared off the list too
                if (order.status == 'delivered')
                  IconButton(
                    tooltip: trf('លុបចេញពីបញ្ជី', 'Remove from list'),
                    onPressed: () => _hide(order),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                if (canCancel)
                  IconButton(
                    tooltip: tr('បោះបង់'),
                    onPressed: () => _cancel(order),
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Four dots joined by a line: how far the order has come
  Widget _progress(String status) {
    if (status == 'cancelled') {
      return Row(
        children: [
          const Icon(Icons.cancel, size: 18, color: Colors.red),
          const SizedBox(width: 6),
          Text(
            orderStatusLabels['cancelled']!,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    const steps = ['pending', 'confirmed', 'shipping', 'delivered'];
    final reached = steps.indexOf(status);
    const done = Color(0xFF16A34A);
    const todo = Color(0xFFE2E8F0);
    // Each step takes a quarter of the width, so long labels can't push past the edge
    Widget line(bool on, bool show) => Expanded(
      child: Container(
        height: 3,
        color: show ? (on ? done : todo) : Colors.transparent,
      ),
    );
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    line(i <= reached, i > 0),
                    Icon(
                      i <= reached
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: i <= reached ? done : Colors.black26,
                    ),
                    line(i + 1 <= reached, i < steps.length - 1),
                  ],
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    orderStatusLabels[steps[i]]!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      color: i == reached ? done : Colors.black45,
                      fontWeight: i == reached
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _track(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order)),
    );
    _refresh(); // status may have moved on while they were looking
  }
}
