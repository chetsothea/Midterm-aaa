import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/common.dart';
import '../../components/confirm_dialog.dart';
import '../../components/store_app_bar.dart';
import '../../components/ux.dart';
import '../../data/api_service.dart';
import '../../data/models/voucher.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

String _amount(double n) =>
    n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

InputDecoration _input(String label, IconData icon, {String? helper}) =>
    InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 2,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );

final _money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

// Admin: delivery prices (Phnom Penh / provinces / free from) and the
// discount codes customers type at checkout
class AdminVouchersScreen extends StatefulWidget {
  const AdminVouchersScreen({super.key});

  @override
  State<AdminVouchersScreen> createState() => _AdminVouchersScreenState();
}

class _AdminVouchersScreenState extends State<AdminVouchersScreen> {
  List<Voucher> _vouchers = [];
  bool _loading = true;
  String? _error;

  final _pp = TextEditingController();
  final _province = TextEditingController();
  final _freeOver = TextEditingController();
  final _khr = TextEditingController(); // riel for one dollar
  bool _savingRates = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_pp, _province, _freeOver, _khr]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (vouchers, rates) = await ApiService.fetchVouchers();
      _vouchers = vouchers;
      _pp.text = _amount(rates.phnomPenh);
      _province.text = _amount(rates.province);
      _freeOver.text = _amount(rates.freeOver);
      _khr.text = '${await ApiService.fetchKhrRate()}';
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveRates() async {
    FocusScope.of(context).unfocus();
    setState(() => _savingRates = true);
    try {
      await ApiService.saveShipping(
        ShippingRates(
          phnomPenh: double.tryParse(_pp.text) ?? 0,
          province: double.tryParse(_province.text) ?? 0,
          freeOver: double.tryParse(_freeOver.text) ?? 0,
        ),
      );
      await ApiService.saveKhrRate(int.tryParse(_khr.text) ?? 0);
      if (mounted) {
        showMessage(
          context,
          trf('បានរក្សាទុកថ្លៃដឹក', 'Delivery prices saved'),
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _savingRates = false);
    }
  }

  Future<void> _edit([Voucher? voucher]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => VoucherForm(voucher: voucher),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Voucher v) async {
    final yes = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      color: AppColors.red,
      title: trf('លុបកូដនេះ?', 'Delete this code?'),
      code: v.code,
      message: trf(
        'អតិថិជននឹងប្រើកូដនេះមិនបានទៀតទេ។ Order ចាស់នៅដដែល',
        'Customers can no longer use it. Past orders keep their discount',
      ),
      cancelLabel: trf('ទេ', 'No'),
      confirmLabel: trf('លុប', 'Delete'),
    );
    if (!yes || v.id == null) return;
    try {
      await ApiService.deleteVoucher(v.id!);
      if (!mounted) return;
      showMessage(context, trf('បានលុប', 'Deleted'));
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Widget _ratesCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: glassDecoration(radius: AppRadius.lg, shadow: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                trf('ថ្លៃដឹកជញ្ជូន', 'Delivery prices'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            trf(
              'គិតតាមខេត្តក្នុងអាសយដ្ឋាន។ ដាក់ 0 = ឥតគិតថ្លៃ',
              'Worked out from the address province. 0 = free',
            ),
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pp,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _money,
                  decoration: _input(
                    trf('ភ្នំពេញ (\$)', 'Phnom Penh (\$)'),
                    Icons.location_city,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: TextField(
                  controller: _province,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _money,
                  decoration: _input(
                    trf('ខេត្ត (\$)', 'Provinces (\$)'),
                    Icons.landscape_outlined,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _freeOver,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _money,
            decoration: _input(
              trf('ដឹកឥតគិតថ្លៃ ចាប់ពី (\$)', 'Free delivery from (\$)'),
              Icons.card_giftcard,
              helper: trf('0 = មិនដែលឥតគិតថ្លៃ', '0 = never free'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Shown as "≈ ៛4,100,000" next to prices
          TextField(
            controller: _khr,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _input(
              trf(
                'អត្រាប្តូរប្រាក់ (៛ ក្នុង \$1)',
                'Exchange rate (៛ per \$1)',
              ),
              Icons.currency_exchange,
              helper: trf(
                'បង្ហាញតម្លៃជារៀលក្បែរ \$ · 0 = មិនបង្ហាញ',
                'Shows riel next to \$ · 0 = hide',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _savingRates ? null : _saveRates,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _savingRates
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(trf('រក្សាទុកថ្លៃដឹក', 'Save delivery prices')),
          ),
        ],
      ),
    );
  }

  Widget _status(Voucher v) {
    final (label, color) = !v.active
        ? (trf('បិទ', 'Off'), AppColors.muted)
        : v.expired
        ? (trf('ផុតកំណត់', 'Expired'), AppColors.red)
        : v.usedUp
        ? (trf('ប្រើអស់', 'Used up'), AppColors.amber)
        : (trf('កំពុងប្រើ', 'Active'), AppColors.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _tile(Voucher v) {
    final rules = [
      if (v.minTotal > 0)
        trf('ចាប់ពី \$${_amount(v.minTotal)}', 'from \$${_amount(v.minTotal)}'),
      if (v.maxDiscount != null)
        trf(
          'យ៉ាងច្រើន \$${_amount(v.maxDiscount!)}',
          'max \$${_amount(v.maxDiscount!)}',
        ),
      v.maxUses == null
          ? trf('ប្រើ ${v.usedCount} ដង', 'used ${v.usedCount}×')
          : trf(
              'ប្រើ ${v.usedCount}/${v.maxUses}',
              'used ${v.usedCount}/${v.maxUses}',
            ),
      if (v.expiresAt != null)
        trf('ដល់ ${_date(v.expiresAt!)}', 'until ${_date(v.expiresAt!)}'),
    ];
    return Opacity(
      opacity: v.usable ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          0,
          AppSpacing.sm,
        ),
        decoration: glassDecoration(radius: AppRadius.lg, shadow: false),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                v.label,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        v.code,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppColors.text,
                        ),
                      ),
                      _status(v),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rules.join(' · '),
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: trf('កែ', 'Edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(v),
            ),
            IconButton(
              tooltip: trf('លុប', 'Delete'),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.red,
              ),
              onPressed: () => _delete(v),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(
        title: Text(trf('កូដបញ្ចុះ និងថ្លៃដឹក', 'Codes & delivery')),
      ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _edit,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(trf('បង្កើតកូដ', 'New code')),
            ),
      body: _loading
          ? const ListSkeleton(rows: 3)
          : _error != null
          ? StatusView(
              icon: Icons.wifi_off_rounded,
              error: true,
              title: trf('មិនអាចភ្ជាប់ទៅហាងបានទេ', "Can't reach the shop"),
              message: _error!,
              actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                _ratesCard(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  trf('កូដបញ្ចុះតម្លៃ', 'Discount codes'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  trf(
                    'អតិថិជនម្នាក់ប្រើកូដមួយបានតែម្តង។ Order ដែលបោះបង់ ផ្តល់កូដត្រឡប់វិញ',
                    'Each customer can use a code once. A cancelled order gives it back',
                  ),
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_vouchers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 40,
                          color: AppColors.muted,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          trf(
                            'មិនទាន់មានកូដ។ ឧ. NEWYEAR10 បញ្ចុះ 10% សម្រាប់ចូលឆ្នាំ',
                            'No codes yet. e.g. NEWYEAR10 for 10% off at New Year',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                for (final v in _vouchers) _tile(v),
              ],
            ),
    );
  }
}

// Create or edit one code
class VoucherForm extends StatefulWidget {
  final Voucher? voucher;

  const VoucherForm({super.key, this.voucher});

  @override
  State<VoucherForm> createState() => _VoucherFormState();
}

class _VoucherFormState extends State<VoucherForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.voucher?.code);
  late final _value = TextEditingController(
    text: widget.voucher == null ? '' : _amount(widget.voucher!.value),
  );
  late final _minTotal = TextEditingController(
    text: (widget.voucher?.minTotal ?? 0) > 0
        ? _amount(widget.voucher!.minTotal)
        : '',
  );
  late final _maxDiscount = TextEditingController(
    text: widget.voucher?.maxDiscount == null
        ? ''
        : _amount(widget.voucher!.maxDiscount!),
  );
  late final _maxUses = TextEditingController(
    text: widget.voucher?.maxUses?.toString() ?? '',
  );
  late String _type = widget.voucher?.type ?? 'percent';
  late DateTime? _expiresAt = widget.voucher?.expiresAt;
  late bool _active = widget.voucher?.active ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_code, _value, _minTotal, _maxDiscount, _maxUses]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    // To the end of that day, so the code works all day long
    if (picked != null) {
      setState(
        () => _expiresAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService.saveVoucher(
        Voucher(
          id: widget.voucher?.id,
          code: _code.text.trim().toUpperCase(),
          type: _type,
          value: double.parse(_value.text),
          minTotal: double.tryParse(_minTotal.text) ?? 0,
          maxDiscount: _type == 'percent'
              ? double.tryParse(_maxDiscount.text)
              : null,
          maxUses: int.tryParse(_maxUses.text),
          expiresAt: _expiresAt,
          active: _active,
        ),
      );
      if (!mounted) return;
      showMessage(context, trf('បានរក្សាទុក', 'Saved'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = _type == 'percent';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.voucher == null
                    ? trf('បង្កើតកូដបញ្ចុះតម្លៃ', 'New discount code')
                    : trf('កែកូដ', 'Edit code'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                  LengthLimitingTextInputFormatter(30),
                ],
                decoration: _input(
                  trf('កូដ *', 'Code *'),
                  Icons.confirmation_number_outlined,
                  helper: trf(
                    'អក្សរ A-Z លេខ - _ ឧ. NEWYEAR10',
                    'A-Z, 0-9, - and _ e.g. NEWYEAR10',
                  ),
                ),
                validator: (v) => v!.trim().isEmpty
                    ? trf('សូមបញ្ចូលកូដ', 'Enter a code')
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'percent',
                    icon: const Icon(Icons.percent),
                    label: Text(trf('ភាគរយ', 'Percent')),
                  ),
                  ButtonSegment(
                    value: 'fixed',
                    icon: const Icon(Icons.attach_money),
                    label: Text(trf('ចំនួនថេរ', 'Fixed \$')),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: _money,
                decoration: _input(
                  percent
                      ? trf('បញ្ចុះ (%) *', 'Discount (%) *')
                      : trf('បញ្ចុះ (\$) *', 'Discount (\$) *'),
                  percent ? Icons.percent : Icons.attach_money,
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) {
                    return trf('ត្រូវធំជាង 0', 'Must be more than 0');
                  }
                  if (percent && n > 100) {
                    return trf('មិនអាចលើស 100%', 'Max 100%');
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minTotal,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: _money,
                      decoration: _input(
                        trf('ទិញចាប់ពី (\$)', 'Min order (\$)'),
                        Icons.shopping_bag_outlined,
                      ),
                    ),
                  ),
                  if (percent) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: TextFormField(
                        controller: _maxDiscount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _money,
                        decoration: _input(
                          trf('បញ្ចុះយ៉ាងច្រើន (\$)', 'Max off (\$)'),
                          Icons.vertical_align_top,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _maxUses,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _input(
                  trf('ចំនួនដងសរុប', 'Total uses'),
                  Icons.repeat,
                  helper: trf('ទុកទទេ = គ្មានកំណត់', 'Empty = no limit'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(trf('ផុតកំណត់', 'Expires')),
                subtitle: Text(
                  _expiresAt == null
                      ? trf('មិនផុតកំណត់', 'Never')
                      : _date(_expiresAt!),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_expiresAt != null)
                      IconButton(
                        tooltip: trf('លុបថ្ងៃ', 'Clear date'),
                        onPressed: () => setState(() => _expiresAt = null),
                        icon: const Icon(Icons.close),
                      ),
                    TextButton(
                      onPressed: _pickDate,
                      child: Text(trf('ជ្រើស', 'Pick')),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(trf('បើកឱ្យប្រើ', 'Active')),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(trf('រក្សាទុក', 'Save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
