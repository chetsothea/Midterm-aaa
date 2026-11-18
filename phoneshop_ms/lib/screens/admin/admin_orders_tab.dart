import 'warranty_screens.dart';
import 'package:flutter/material.dart';
import '../../data/models/order.dart';
import '../../data/api_service.dart';
import '../../components/common.dart';
import '../../components/courier_logo.dart';
import '../../components/order_tracking.dart';
import '../invoice_screen.dart';
import '../../components/ux.dart';
import '../../components/shop_refresh.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

class AdminOrdersTab extends StatefulWidget {
  final bool Function(Order)?
  only; // a list opened from the dashboard: delivered orders matching this

  // Which status to load before [only] filters it; '' loads every order
  final String onlyStatus;

  const AdminOrdersTab({super.key, this.only, this.onlyStatus = 'delivered'});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  // Status chip and search box: both work on the list already loaded, so they're instant
  String _filter = '';
  String _search = '';
  late Future<List<Order>> _orders = _fetch();

  Future<List<Order>> _fetch() async {
    final only = widget.only;
    if (only != null) {
      return (await ApiService.fetchAllOrders(
        status: widget.onlyStatus,
      )).where(only).toList();
    }
    return ApiService.fetchAllOrders();
  }

  List<Order> _shown(List<Order> orders) {
    final query = _search.trim().toLowerCase().replaceFirst('#', '');
    return orders.where((o) {
      if (_filter.isNotEmpty && o.status != _filter) return false;
      if (query.isEmpty) return true;
      return '${o.id}' == query ||
          o.code.toLowerCase().replaceFirst('ps-', '') ==
              query.replaceFirst('ps-', '') ||
          o.customerName.toLowerCase().contains(query) ||
          o.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
    }).toList();
  }

  Future<void> _refresh() async {
    // Block body: an arrow would return the Future, which setState() rejects
    setState(() {
      _orders = _fetch();
    });
    await _orders;
  }

  Future<void> _update(
    Order order, {
    String? status,
    String? paymentStatus,
    String? courier,
    String? trackingNumber,
    String? location,
    String? note,
  }) async {
    try {
      await ApiService.updateOrder(
        order.id,
        status: status,
        paymentStatus: paymentStatus,
        courier: courier,
        trackingNumber: trackingNumber,
        location: location,
        note: note,
      );
      if (mounted) showMessage(context, 'បានកែប្រែ Order #${order.id}');
      _refresh();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  void _confirmDelete(Order order) async {
    final inProgress =
        order.status != 'delivered' && order.status != 'cancelled';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('លុប Order #${order.id}?'),
        content: Text(
          'លុបហើយមិនអាចយកមកវិញបានទេ។ អតិថិជននឹងមិនឃើញ Order នេះទៀតទេ'
          '${order.status == 'delivered' || order.paymentStatus == 'paid' ? ' ហើយចំណូលក្នុង Dashboard អាចថយចុះ' : ''}។'
          '${inProgress ? ' ស្តុកនឹងត្រូវបញ្ចូលវិញ។' : ''}'
          '${inProgress && order.paymentStatus == 'paid' ? ' Order នេះបានបង់ប្រាក់រួចហើយ។' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ទេ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('លុប'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.deleteOrder(order.id);
      if (mounted) showMessage(context, 'បានលុប Order #${order.id}');
      _refresh();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  // Hand the parcel to a courier: who delivers it, its number, and where it leaves from
  void _startShipping(Order order) async {
    final info = await showDialog<_TrackingInput>(
      context: context,
      builder: (_) => _TrackingDialog(
        title: 'ចាប់ផ្តើមដឹក Order #${order.id}',
        askCourier: true,
        initialCourier: order.courier,
        initialNumber: order.trackingNumber,
      ),
    );
    if (info == null) return;
    _update(
      order,
      status: 'shipping',
      courier: info.courier,
      trackingNumber: info.number,
      location: info.location,
      note: info.note,
    );
  }

  // Where the package is now, without changing the order status
  void _addLocation(Order order) async {
    final info = await showDialog<_TrackingInput>(
      context: context,
      builder: (_) => _TrackingDialog(
        title: 'បន្ថែមទីតាំង Order #${order.id}',
        requireLocationOrNote: true,
      ),
    );
    if (info == null) return;
    try {
      await ApiService.addTracking(
        order.id,
        location: info.location,
        note: info.note,
      );
      if (mounted) showMessage(context, 'បានបន្ថែមទីតាំង Order #${order.id}');
      _refresh();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  // Fix a step typed wrongly; the customer's timeline shows the corrected text
  void _editStep(Order order, TrackingStep step) async {
    final info = await showDialog<_TrackingInput>(
      context: context,
      builder: (_) => _TrackingDialog(
        title: 'កែទីតាំង Order #${order.id}',
        initialLocation: step.location,
        initialNote: step.note,
      ),
    );
    if (info == null) return;
    try {
      await ApiService.updateTracking(
        order.id,
        step.id!,
        location: info.location,
        note: info.note,
      );
      if (mounted) showMessage(context, 'បានកែទីតាំង Order #${order.id}');
      _refresh();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  void _confirmCancel(Order order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('បោះបង់ Order #${order.id}?'),
        content: const Text('ស្តុកនឹងត្រូវបានបញ្ចូលវិញ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ទេ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('បោះបង់'),
          ),
        ],
      ),
    );
    if (ok == true) _update(order, status: 'cancelled');
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.page,
      child: FutureBuilder<List<Order>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          } else if (snapshot.hasError) {
            return StatusView(
              icon: Icons.wifi_off_rounded,
              error: true,
              title: trf('មិនអាចភ្ជាប់ទៅហាងបានទេ', "Can't reach the shop"),
              message: '${snapshot.error}',
              actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
              onAction: _refresh,
            );
          }
          final all = snapshot.data!;
          final shown = _shown(all);
          return Column(
            children: [
              if (widget.only == null) _toolbar(all),
              Expanded(
                child: ShopRefresh(
                  onRefresh: _refresh,
                  child: shown.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(
                              Icons.inbox_outlined,
                              size: 56,
                              color: Colors.black26,
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Center(child: Text('មិនមាន Order')),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                          children: [
                            for (final order in shown) _orderCard(order),
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

  // Search box, then one chip per status with how many orders are in it
  Widget _toolbar(List<Order> all) {
    final filters = {'': 'ទាំងអស់', ...orderStatusLabels};
    return Container(
      color: AppColors.glass,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'ស្វែងរក ឈ្មោះ លេខទូរស័ព្ទ ឬកូដ Order',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.page,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final entry in filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _filterChip(
                      entry.key,
                      entry.value,
                      entry.key.isEmpty
                          ? all.length
                          : all.where((o) => o.status == entry.key).length,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String status, String label, int count) {
    final selected = _filter == status;
    final color = status.isEmpty ? AppColors.text : statusColor(status);
    return ChoiceChip(
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selected: selected,
      selectedColor: color,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? color : Colors.black12),
      label: Text(
        '$label  $count',
        style: TextStyle(
          color: selected ? Colors.white : AppColors.text2,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      onSelected: (_) => setState(() => _filter = status),
    );
  }

  static const _statusIcons = {
    'pending': Icons.hourglass_top_rounded,
    'confirmed': Icons.check_circle_outline,
    'shipping': Icons.local_shipping_outlined,
    'delivered': Icons.done_all_rounded,
    'cancelled': Icons.cancel_outlined,
  };

  // 05/11 14:20, in the admin's own time
  static String _when(DateTime time) {
    final t = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  Widget _infoRow(IconData icon, String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  // The next step in the delivery flow, or null when there is none
  static const _nextStatus = {
    'pending': ('confirmed', 'បញ្ជាក់ Order'),
    'confirmed': ('shipping', 'ចាប់ផ្តើមដឹក'),
    'shipping': ('delivered', 'បានដឹកដល់'),
  };

  Widget _thumb(String url, double size) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [AppColors.surfaceHigh, AppColors.tileLow],
        ),
      ),
      child: PhoneImage(url: url, size: size - 6),
    );
  }

  Widget _orderCard(Order order) {
    final cancelled = order.status == 'cancelled';
    final next = _nextStatus[order.status];

    final color = statusColor(order.status);
    final pieces = order.items.fold<int>(0, (sum, item) => sum + item.qty);
    final checkPayment = order.paymentStatus == 'verifying';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
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
        // The status colour down the left edge, so the list reads at a glance
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: ExpansionTile(
        initiallyExpanded: checkPayment,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
        leading: _thumb(
          order.items.isEmpty ? '' : order.items.first.imageUrl,
          48,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '#${order.id} ',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              money(order.total),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.items.isNotEmpty)
                Text(
                  order.items.length > 1
                      ? '${order.items.first.productName} +${order.items.length - 1}'
                      : order.items.first.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.text3),
                ),
              Text(
                // The code the customer quotes, so the admin can find this order
                '$pieces គ្រឿង • ${_when(order.createdAt)}${order.code.isEmpty ? '' : ' • ${order.code}'}',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(
                    status: order.status,
                    label: orderStatusLabels[order.status]!,
                  ),
                  StatusBadge(
                    status: order.paymentStatus,
                    label: paymentStatusLabels[order.paymentStatus]!,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        order.paymentMethod == 'cod'
                            ? Icons.payments_outlined
                            : Icons.qr_code_2,
                        size: 15,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 3),
                      // Shrinks with "…" on a narrow phone instead of overflowing
                      Flexible(
                        child: Text(
                          paymentMethodLabels[order.paymentMethod]!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (checkPayment)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '⚠ សូមពិនិត្យការបង់ប្រាក់',
                    style: TextStyle(
                      color: Color(0xFF2F62D9),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!cancelled)
            _section('ស្ថានភាព', [DeliveryProgress(status: order.status)]),
          _section('ទំនិញ', [
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    _thumb(item.imageUrl, 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.label} × ${item.qty}'),
                          for (final imei in item.imeis)
                            Text(
                              'IMEI $imei',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          // The IMEI of each phone handed over (warranty desk)
                          if (!cancelled && item.id != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                final saved = await showImeiSheet(
                                  context,
                                  item,
                                );
                                if (saved != null) _refresh();
                              },
                              icon: Icon(
                                item.imeis.length >= item.qty
                                    ? Icons.check_circle
                                    : Icons.qr_code_scanner,
                                size: 16,
                                color: item.imeis.length >= item.qty
                                    ? AppColors.green
                                    : AppColors.amber,
                              ),
                              label: Text(
                                'IMEI ${item.imeis.length}/${item.qty}',
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      money(item.price * item.qty),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const Divider(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'សរុប',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  money(order.total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ]),
          _section('អតិថិជន', [
            _infoRow(Icons.phone_outlined, order.phone),
            if (order.customerEmail.isNotEmpty)
              _infoRow(Icons.email_outlined, order.customerEmail),
            _infoRow(Icons.location_on_outlined, order.address),
            _infoRow(Icons.schedule, _when(order.createdAt)),
            if (order.transactionRef != null)
              _infoRow(
                Icons.tag,
                'Transaction ID: ${order.transactionRef}',
                bold: true,
              ),
            if (order.isGuest)
              Text(
                'ទិញជា Guest (គ្មានគណនី)',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
          ]),
          if (order.receivedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'អតិថិជនបានបញ្ជាក់ថាទទួលឥវ៉ាន់ ${order.receivedAt.toString().substring(0, 16)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          CourierInfo(order: order),
          // The same timeline the customer sees, folded in a card of its own
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.line),
            ),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              leading: CircleAvatar(
                radius: 15,
                backgroundColor: const Color(
                  0xFF3D7BFF,
                ).withValues(alpha: 0.12),
                child: const Icon(
                  Icons.route_outlined,
                  size: 17,
                  color: Color(0xFF3D7BFF),
                ),
              ),
              title: Text(
                'ការតាមដានឥវ៉ាន់ (${order.trackings.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              subtitle: order.trackings.isEmpty
                  ? null
                  : Text(
                      // The latest step at a glance, without opening the list
                      [
                        if (order.trackings.first.location.isNotEmpty)
                          '📍 ${order.trackings.first.location}',
                        _when(order.trackings.first.time),
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
              children: [
                TrackingTimeline(
                  steps: order.trackings,
                  onEdit: (step) => _editStep(order, step),
                ),
              ],
            ),
          ),
          if (!cancelled) ...[
            const SizedBox(height: 10),
            // A payment to check comes first; otherwise the next delivery step
            if (order.paymentStatus == 'verifying') ...[
              FilledButton.icon(
                onPressed: () => _update(
                  order,
                  paymentStatus: 'paid',
                  status: order.status == 'pending' ? 'confirmed' : null,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF30D158),
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: const Icon(Icons.check),
                label: const Text('បញ្ជាក់បានទទួលប្រាក់'),
              ),
              const SizedBox(height: AppSpacing.xs),
            ] else if (next != null) ...[
              FilledButton.icon(
                onPressed: () => next.$1 == 'shipping'
                    ? _startShipping(order)
                    : _update(order, status: next.$1),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF101318),
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: Icon(_statusIcons[next.$1] ?? Icons.arrow_forward),
                label: Text(next.$2),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (order.paymentStatus == 'verifying') ...[
                  OutlinedButton(
                    onPressed: () => _update(order, paymentStatus: 'unpaid'),
                    child: const Text('បដិសេធការបង់ប្រាក់'),
                  ),
                  // The delivery step is still reachable while a payment waits
                  if (next != null)
                    OutlinedButton(
                      onPressed: () => next.$1 == 'shipping'
                          ? _startShipping(order)
                          : _update(order, status: next.$1),
                      child: Text(next.$2),
                    ),
                ],
                // Cash on delivery is collected by hand, so the admin marks it paid
                if (order.paymentMethod == 'cod' &&
                    order.paymentStatus == 'unpaid')
                  OutlinedButton.icon(
                    onPressed: () => _update(order, paymentStatus: 'paid'),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('បានទទួលសាច់ប្រាក់'),
                  ),
                if (order.status == 'confirmed' || order.status == 'shipping')
                  OutlinedButton.icon(
                    onPressed: () => _addLocation(order),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text('បន្ថែមទីតាំង'),
                  ),
              ],
            ),
          ],
          const Divider(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              if (!cancelled && order.status != 'delivered')
                TextButton.icon(
                  onPressed: () => _confirmCancel(order),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('បោះបង់'),
                ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceScreen(order: order),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('វិក្កយបត្រ'),
              ),
              // Deleting an order is the admin's call, not staff's
              if (ApiService.currentUser?.isAdmin ?? false)
                TextButton.icon(
                  onPressed: () => _confirmDelete(order),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('លុប Order'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// What the admin typed in the tracking dialog
typedef _TrackingInput = ({
  String courier,
  String number,
  String location,
  String note,
});

// Courier / parcel number (when shipping starts), plus where the package is and a note
class _TrackingDialog extends StatefulWidget {
  final String title;
  final bool askCourier;
  final bool requireLocationOrNote;
  final String initialCourier;
  final String initialNumber;
  final String initialLocation;
  final String initialNote;

  const _TrackingDialog({
    required this.title,
    this.askCourier = false,
    this.requireLocationOrNote = false,
    this.initialCourier = '',
    this.initialNumber = '',
    this.initialLocation = '',
    this.initialNote = '',
  });

  @override
  State<_TrackingDialog> createState() => _TrackingDialogState();
}

class _TrackingDialogState extends State<_TrackingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _courier = TextEditingController(text: widget.initialCourier);
  late final _number = TextEditingController(text: widget.initialNumber);
  late final _location = TextEditingController(text: widget.initialLocation);
  late final _note = TextEditingController(text: widget.initialNote);

  @override
  void dispose() {
    for (final c in [_courier, _number, _location, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  OutlineInputBorder _border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  // Soft filled fields with light borders, like the rest of the app's forms
  InputDecoration _decor(String label, IconData icon, [String? hint]) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSoft),
        filled: true,
        fillColor: AppColors.surface,
        border: _border(AppColors.line),
        enabledBorder: _border(AppColors.line),
        focusedBorder: _border(const Color(0xFF3D7BFF), 1.8),
        errorBorder: _border(Colors.red),
        focusedErrorBorder: _border(Colors.red, 1.8),
      );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop<_TrackingInput>(context, (
      courier: _courier.text.trim(),
      number: _number.text.trim(),
      location: _location.text.trim(),
      note: _note.text.trim(),
    ));
  }

  String? _needOne(String? _) =>
      widget.requireLocationOrNote &&
          _location.text.trim().isEmpty &&
          _note.text.trim().isEmpty
      ? 'សូមបញ្ចូលទីតាំង ឬកំណត់សម្គាល់'
      : null;

  Widget _courierTile(String name) {
    final selected = _courier.text.trim() == name;
    final color = courierColor(name);
    return Material(
      color: selected ? color.withValues(alpha: 0.1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? color : AppColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() {
          _courier.text = name;
        }),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CourierLogo(name: name, size: 36),
                    const SizedBox(height: AppSpacing.xxs),
                    // Takes what height is left and ends in "…", never overflowing
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.check_circle, size: 18, color: color),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.surfaceHigh,
        child: Icon(
          widget.askCourier ? Icons.local_shipping : Icons.add_location_alt,
          color: AppColors.text,
          size: 28,
        ),
      ),
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.askCourier) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ជ្រើសក្រុមហ៊ុនដឹកជញ្ជូន',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Common delivery companies in Cambodia, three to a row
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      // A fixed height, so a narrow phone makes the tiles thinner, not shorter
                      mainAxisExtent: 96,
                    ),
                    children: [
                      for (final name in couriers.keys) _courierTile(name),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Or any other company, typed by hand
                  TextFormField(
                    controller: _courier,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'ក្រុមហ៊ុនដឹកជញ្ជូន (ឬវាយឈ្មោះផ្សេង)',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: CourierLogo(
                          name: _courier.text.trim(),
                          size: 28,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _number,
                    decoration: _decor(
                      'លេខតាមដាន (Tracking No.)',
                      Icons.qr_code,
                      'ឧ. JT0123456789',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                TextFormField(
                  controller: _location,
                  decoration: _decor(
                    'ទីតាំងបច្ចុប្បន្ន',
                    Icons.location_on_outlined,
                    'ឧ. សាខា បាត់ដំបង',
                  ),
                  validator: _needOne,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: _decor(
                    'កំណត់សម្គាល់ (មិនបង្ខំ)',
                    Icons.notes,
                    'ឧ. អ្នកដឹកនឹងទាក់ទងមុនដល់',
                  ),
                  validator: _needOne,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('បោះបង់'),
        ),
        FilledButton.icon(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3D7BFF),
          ),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('រក្សាទុក'),
        ),
      ],
    );
  }
}
