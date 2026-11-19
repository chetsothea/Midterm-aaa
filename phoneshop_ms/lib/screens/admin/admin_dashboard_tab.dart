import 'package:flutter/material.dart';
import '../../data/models/order.dart';
import '../../data/api_service.dart';
import '../../components/common.dart';
import '../../components/dashboard_charts.dart';
import 'admin_customers_screen.dart';
import 'admin_orders_tab.dart';
import '../../components/ux.dart';
import '../../components/shop_refresh.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

// The shop at a glance, top to bottom in order of urgency:
// money in, what needs doing now, the totals, then the charts.
class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  late Future<Map<String, dynamic>> _stats = _load();
  DateTime _loadedAt = DateTime.now();

  static Color get _navy => AppColors.text;
  static const _teal = Color(0xFF3D7BFF);
  static const _gold = Color(0xFFFBBF24);
  static const _green = Color(0xFF30D158);
  static Color get _muted => AppColors.muted;

  Future<Map<String, dynamic>> _load() async {
    final stats = await ApiService.fetchDashboard();
    _loadedAt = DateTime.now();
    return stats;
  }

  Future<void> _refresh() async {
    // Block body: an arrow would return the Future, which setState() rejects
    setState(() {
      _stats = _load();
    });
    await _stats;
  }

  // White card with a soft shadow, the same as the order cards
  static BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.glass,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  static String _two(int n) => n.toString().padLeft(2, '0');

  // Section title with the store's orange bar, so admin and store read alike
  Widget _heading(String text, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3D7BFF), Color(0xFFFF453A)],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing, style: TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _openOrders(
    String title,
    bool Function(Order) only, {
    String status = '',
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: AdminOrdersTab(only: only, onlyStatus: status),
        ),
      ),
    );
    _refresh(); // the admin has probably dealt with some of them
  }

  // ---------- money in ----------

  // Paid revenue in big letters, a small 7-day trend, today against yesterday
  Widget _revenue(double revenue, List<({DateTime date, double total})> days) {
    final today = days.isEmpty ? 0.0 : days.last.total;
    final yesterday = days.length < 2 ? 0.0 : days[days.length - 2].total;
    final week = days.fold<double>(0, (sum, d) => sum + d.total);

    Widget small(String label, double value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(value),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _teal],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ចំណូល (បានបង់)',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money(revenue),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    _change(today, yesterday),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _Sparkline(values: [for (final d in days) d.total]),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              small('ថ្ងៃនេះ', today),
              const SizedBox(width: AppSpacing.xs),
              small('៧ ថ្ងៃចុងក្រោយ', week),
            ],
          ),
        ],
      ),
    );
  }

  // "▲ 12% ពីម្សិលមិញ": up in gold, down in a soft red, nothing to compare in grey
  Widget _change(double today, double yesterday) {
    final String text;
    final IconData icon;
    final Color color;
    if (yesterday <= 0) {
      text = today > 0 ? 'ថ្ងៃនេះមានការលក់' : 'ថ្ងៃនេះមិនទាន់មានការលក់';
      icon = today > 0 ? Icons.trending_up : Icons.remove;
      color = today > 0 ? _gold : Colors.white70;
    } else {
      final percent = ((today - yesterday) / yesterday * 100).round();
      final up = percent >= 0;
      text = '${up ? '+' : ''}$percent% ពីម្សិលមិញ';
      icon = up ? Icons.trending_up : Icons.trending_down;
      color = up ? _gold : const Color(0xFFFCA5A5);
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- what needs doing now ----------

  // One thing to act on: coloured edge, icon, count, and where to go
  Widget _task({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration.copyWith(
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w700, color: _navy),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }

  List<Widget> _tasks(Map<String, dynamic> s) {
    final pending = s['pending_orders'] as int? ?? 0;
    final verifying = s['verifying_payments'] as int? ?? 0;
    final received = s['new_received'] as int? ?? 0;
    final unpaid = s['unpaid_delivered'] as int? ?? 0;
    final refunds = s['refunds_due'] as int? ?? 0;
    return [
      // Cancelled after paying: the customer is waiting for their money
      if (refunds > 0)
        _task(
          color: const Color(0xFFFF9F0A),
          icon: Icons.currency_exchange,
          title: 'ត្រូវបង្វិលប្រាក់ឱ្យអតិថិជន',
          subtitle:
              '$refunds Order • ${money((s['refunds_due_total'] as num).toDouble())}',
          onTap: () => _openOrders(
            'ត្រូវបង្វិលប្រាក់',
            (o) => o.refundStatus == 'due',
            status: 'cancelled',
          ),
        ),
      if (pending > 0)
        _task(
          color: const Color(0xFF2F62D9),
          icon: Icons.hourglass_top,
          title: 'Order ថ្មីរង់ចាំបញ្ជាក់',
          subtitle: '$pending Order',
          onTap: () => _openOrders(
            'Order រង់ចាំបញ្ជាក់',
            (_) => true,
            status: 'pending',
          ),
        ),
      if (verifying > 0)
        _task(
          color: const Color(0xFF9333EA),
          icon: Icons.verified_outlined,
          title: 'ការបង់ប្រាក់រង់ចាំផ្ទៀងផ្ទាត់',
          subtitle: '$verifying Order • ពិនិត្យក្នុងកម្មវិធីធនាគារ',
          onTap: () => _openOrders(
            'ផ្ទៀងផ្ទាត់ការបង់ប្រាក់',
            (o) => o.paymentStatus == 'verifying',
          ),
        ),
      // A customer said they got their parcel. Opening the list counts as having seen it.
      if (received > 0)
        _task(
          color: _green,
          icon: Icons.notifications_active,
          title: 'អតិថិជនបានទទួលឥវ៉ាន់',
          subtitle: '$received Order ថ្មី',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('អតិថិជនបានទទួលឥវ៉ាន់')),
                  body: AdminOrdersTab(
                    only: (o) => o.receivedAt != null && !o.receivedSeen,
                  ),
                ),
              ),
            );
            try {
              await ApiService.markReceivedSeen();
            } catch (_) {
              // Not critical: the notice just stays until the next time
            }
            _refresh();
          },
        ),
      // Delivered but not paid: only shown while there is money to collect
      if (unpaid > 0)
        _task(
          color: const Color(0xFFFF453A),
          icon: Icons.warning_amber_rounded,
          title: 'បានទទួលហើយ តែមិនទាន់បង់',
          subtitle:
              '$unpaid Order • ${money((s['unpaid_delivered_total'] as num).toDouble())}',
          onTap: () => _openOrders(
            'មិនទាន់បង់',
            (o) => o.paymentStatus == 'unpaid',
            status: 'delivered',
          ),
        ),
    ];
  }

  // Nothing waiting: say so, so an empty space doesn't look like a loading error
  Widget _allDone() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _green.withValues(alpha: 0.12),
            child: const Icon(Icons.check_circle_outline, color: _green),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'គ្មានការងារត្រូវធ្វើទេ',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _navy),
                ),
                Text(
                  'Order និងការបង់ប្រាក់ទាំងអស់ត្រូវបានដោះស្រាយ',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- totals ----------

  // Icon square on the left, the number big, its name under it
  Widget _tile(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: _cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // One line each that shrinks to fit, so big numbers
                      // and long names can't overflow the tile
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _stats,
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
        final s = snapshot.data!;
        final threshold = s['low_stock_threshold'] as int;
        final lowStock = s['low_stock'] as int? ?? 0;
        final tiles = [
          _tile(
            'Order សរុប',
            '${s['total_orders']}',
            Icons.receipt_long,
            const Color(0xFF2563EB),
            onTap: () => _openOrders('Order ទាំងអស់', (_) => true),
          ),
          _tile(
            'ទូរស័ព្ទសរុប',
            '${s['total_products']}',
            Icons.phone_android,
            const Color(0xFF0D9488),
          ),
          _tile(
            'ស្តុកជិតអស់ (≤$threshold)',
            '$lowStock',
            Icons.inventory_2_outlined,
            lowStock > 0 ? const Color(0xFFFF453A) : _muted,
          ),
          _tile(
            'អតិថិជន',
            '${s['total_customers']}',
            Icons.people,
            const Color(0xFF4F46E5),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminCustomersScreen()),
              );
              _refresh(); // someone may have registered meanwhile
            },
          ),
        ];
        final revenueByDay = [
          for (final day in s['revenue_by_day'] as List)
            (
              date: DateTime.parse(day['date']),
              total: (day['total'] as num).toDouble(),
            ),
        ];
        final ordersByStatus = [
          for (final row in s['orders_by_status'] as List)
            (
              label:
                  orderStatusLabels[row['status']] ?? row['status'] as String,
              value: row['count'] as int,
            ),
        ];
        final topProducts = [
          for (final row in s['top_products'] as List)
            (label: row['name'] as String, value: row['qty'] as int),
        ];
        final tasks = _tasks(s);

        return ColoredBox(
          color: AppColors.page,
          child: ShopRefresh(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              children: [
                // When these numbers are from, so a stale screen isn't trusted
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 15, color: _muted),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          'ធ្វើបច្ចុប្បន្នភាព ${_two(_loadedAt.hour)}:${_two(_loadedAt.minute)} • ទាញចុះក្រោមដើម្បីផ្ទុកថ្មី',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                _revenue((s['revenue'] as num).toDouble(), revenueByDay),
                _heading(
                  'ត្រូវធ្វើឥឡូវ',
                  trailing: tasks.isEmpty ? null : '${tasks.length} ការងារ',
                ),
                if (tasks.isEmpty) _allDone() else ...tasks,
                _heading('សង្ខេប'),
                GridView.extent(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 80,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: tiles,
                ),
                _heading('ក្រាហ្វ'),
                ChartCard(
                  title: 'ចំណូល 7 ថ្ងៃចុងក្រោយ',
                  child: RevenueColumns(days: revenueByDay),
                ),
                const SizedBox(height: 10),
                ChartCard(
                  title: 'Order តាមស្ថានភាព',
                  child: LabeledBars(items: ordersByStatus),
                ),
                const SizedBox(height: 10),
                ChartCard(
                  title: 'ទូរស័ព្ទលក់ដាច់បំផុត',
                  child: LabeledBars(items: topProducts),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Seven small white bars for the last 7 days; the latest one in gold.
// Only a shape to glance at: the chart further down has the amounts.
class _Sparkline extends StatelessWidget {
  final List<double> values;

  const _Sparkline({required this.values});

  @override
  Widget build(BuildContext context) {
    final most = values.fold<double>(0, (m, v) => v > m ? v : m);
    return ExcludeSemantics(
      child: SizedBox(
        width: 92,
        height: 56,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Container(
                  height: most <= 0 ? 4 : 4 + 52 * values[i] / most,
                  decoration: BoxDecoration(
                    color: i == values.length - 1
                        ? const Color(0xFFFBBF24)
                        : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
