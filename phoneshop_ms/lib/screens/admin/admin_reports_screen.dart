import 'package:flutter/material.dart';
import '../../components/common.dart';
import '../../components/store_app_bar.dart';
import '../../components/ux.dart';
import '../../data/api_service.dart';
import '../../data/save_file.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

double _n(dynamic v) => double.tryParse('$v') ?? 0;

String _short(String isoDay) {
  final p = isoDay.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}' : isoDay;
}

// Admin: sales for a period (paid orders only), with an Excel (CSV) export
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

enum _Range { today, week, month, lastMonth, custom }

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  _Range _range = _Range.week;
  late DateTimeRange _days = _rangeFor(_Range.week);
  Map<String, dynamic>? _report;
  String? _error;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTimeRange _rangeFor(_Range r) {
    final t = _today();
    return switch (r) {
      _Range.today => DateTimeRange(start: t, end: t),
      _Range.week => DateTimeRange(
        start: t.subtract(const Duration(days: 6)),
        end: t,
      ),
      _Range.month => DateTimeRange(start: DateTime(t.year, t.month), end: t),
      _Range.lastMonth => DateTimeRange(
        start: DateTime(t.year, t.month - 1),
        end: DateTime(t.year, t.month, 0),
      ),
      _Range.custom => DateTimeRange(start: t, end: t),
    };
  }

  String _label(_Range r) => switch (r) {
    _Range.today => trf('ថ្ងៃនេះ', 'Today'),
    _Range.week => trf('៧ ថ្ងៃ', '7 days'),
    _Range.month => trf('ខែនេះ', 'This month'),
    _Range.lastMonth => trf('ខែមុន', 'Last month'),
    _Range.custom => trf('ជ្រើសថ្ងៃ', 'Pick days'),
  };

  Future<void> _pick(_Range r) async {
    if (r == _Range.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2024),
        lastDate: _today(),
        initialDateRange: _days,
      );
      if (picked == null) return;
      setState(() {
        _range = r;
        _days = picked;
      });
    } else {
      setState(() {
        _range = r;
        _days = _rangeFor(r);
      });
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _report = await ApiService.fetchSalesReport(_days.start, _days.end);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final (name, bytes) = await ApiService.downloadSalesCsv(
        _days.start,
        _days.end,
      );
      await saveOrShareFile(bytes, name, 'text/csv');
      if (mounted) {
        showMessage(
          context,
          trf(
            'បាន Export ជា $name (បើកក្នុង Excel)',
            'Exported $name (opens in Excel)',
          ),
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: glassDecoration(radius: AppRadius.lg, shadow: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: AppColors.text,
      ),
    ),
  );

  // One bar per day, scaled to the best day
  Widget _days7(List days) {
    final best = days.fold<double>(
      0,
      (m, d) => _n(d['revenue']) > m ? _n(d['revenue']) : m,
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: glassDecoration(radius: AppRadius.lg, shadow: false),
      child: Column(
        children: [
          for (final d in days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      _short('${d['date']}'),
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: best == 0 ? 0 : _n(d['revenue']) / best,
                        minHeight: 10,
                        backgroundColor: AppColors.line,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: Text(
                      money(_n(d['revenue'])),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _table(List rows, List<Widget> Function(Map) cells) => Container(
    decoration: glassDecoration(radius: AppRadius.lg, shadow: false),
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 10,
            ),
            child: Row(children: cells(Map.from(rows[i]))),
          ),
        ],
      ],
    ),
  );

  Widget _body() {
    final r = _report!;
    final days = r['by_day'] as List;
    final products = r['top_products'] as List;
    final payments = r['by_payment'] as List;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio: 1.45,
          children: [
            _stat(
              trf('ចំណូល (បានបង់)', 'Revenue (paid)'),
              money(_n(r['revenue'])),
              Icons.payments_outlined,
              AppColors.green,
            ),
            _stat(
              trf('Order', 'Orders'),
              '${r['orders']}',
              Icons.receipt_long_outlined,
              AppColors.accent,
            ),
            _stat(
              trf('ទូរស័ព្ទលក់បាន', 'Phones sold'),
              '${r['phones_sold']}',
              Icons.phone_android,
              AppColors.accent,
            ),
            _stat(
              trf('មធ្យមក្នុងមួយ Order', 'Average order'),
              money(_n(r['average_order'])),
              Icons.functions,
              AppColors.accent,
            ),
            _stat(
              trf('មិនទាន់បង់', 'Not paid yet'),
              money(_n(r['unpaid_total'])),
              Icons.hourglass_bottom,
              AppColors.amber,
            ),
            _stat(
              trf('បានបោះបង់', 'Cancelled'),
              '${r['cancelled_orders']}',
              Icons.cancel_outlined,
              AppColors.red,
            ),
          ],
        ),
        if (_n(r['discounts']) > 0 || _n(r['shipping_fees']) > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              trf(
                'ក្នុងចំណូល: ថ្លៃដឹក ${money(_n(r['shipping_fees']))} · បញ្ចុះតម្លៃ -${money(_n(r['discounts']))}',
                'In revenue: delivery ${money(_n(r['shipping_fees']))} · discounts -${money(_n(r['discounts']))}',
              ),
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        if (days.length > 1) ...[
          _heading(trf('ចំណូលប្រចាំថ្ងៃ', 'Revenue by day')),
          _days7(days.length > 31 ? days.sublist(days.length - 31) : days),
        ],
        _heading(trf('ទូរស័ព្ទលក់ដាច់', 'Best sellers')),
        if (products.isEmpty)
          Text(
            trf('មិនទាន់មានការលក់ក្នុងរយៈពេលនេះ', 'No sales in this period'),
            style: TextStyle(color: AppColors.muted),
          )
        else
          _table(
            products,
            (p) => [
              Expanded(
                child: Text(
                  '${p['name']}',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text('× ${p['qty']}', style: TextStyle(color: AppColors.muted)),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 92,
                child: Text(
                  money(_n(p['revenue'])),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        if (payments.isNotEmpty) ...[
          _heading(trf('តាមវិធីបង់ប្រាក់', 'By payment method')),
          _table(
            payments,
            (p) => [
              Expanded(
                child: Text(
                  p['method'] == 'khqr'
                      ? 'KHQR'
                      : trf('បង់ពេលទទួល (COD)', 'Cash on delivery'),
                  style: TextStyle(color: AppColors.text),
                ),
              ),
              Text(
                trf('${p['orders']} Order', '${p['orders']} orders'),
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 92,
                child: Text(
                  money(_n(p['revenue'])),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(
        title: Text(trf('របាយការណ៍លក់', 'Sales report')),
        actions: [
          IconButton(
            tooltip: trf('Export ទៅ Excel', 'Export to Excel'),
            onPressed: _exporting || _loading ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              children: [
                for (final r in _Range.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      label: Text(_label(r)),
                      selected: _range == r,
                      onSelected: (_) => _pick(r),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_short(_days.start.toIso8601String().substring(0, 10))}/${_days.start.year} – '
                '${_short(_days.end.toIso8601String().substring(0, 10))}/${_days.end.year}',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const ListSkeleton(rows: 4)
                : _error != null
                ? StatusView(
                    icon: Icons.wifi_off_rounded,
                    error: true,
                    title: trf(
                      'មិនអាចទាញរបាយការណ៍បានទេ',
                      "Couldn't load the report",
                    ),
                    message: _error!,
                    actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
                    onAction: _load,
                  )
                : _body(),
          ),
        ],
      ),
    );
  }
}
