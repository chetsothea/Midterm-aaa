import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/common.dart';
import '../../components/store_app_bar.dart';
import '../../data/api_service.dart';
import '../../data/models/order.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

// The check digit every real IMEI has (Luhn): catches a mistyped number
bool imeiLooksRight(String imei) {
  if (!RegExp(r'^\d{15}$').hasMatch(imei)) return false;
  var sum = 0;
  for (var i = 0; i < 15; i++) {
    var n = int.parse(imei[14 - i]) * (i.isOdd ? 2 : 1);
    sum += n > 9 ? n - 9 : n;
  }
  return sum % 10 == 0;
}

String _day(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// Admin: one field per phone of this order line, to type (or scan) its IMEI.
// Returns the saved IMEIs, or null when closed without saving.
Future<List<String>?> showImeiSheet(BuildContext context, OrderItem item) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _ImeiSheet(item: item),
  );
}

class _ImeiSheet extends StatefulWidget {
  final OrderItem item;

  const _ImeiSheet({required this.item});

  @override
  State<_ImeiSheet> createState() => _ImeiSheetState();
}

class _ImeiSheetState extends State<_ImeiSheet> {
  final _form = GlobalKey<FormState>();
  late final List<TextEditingController> _fields = [
    for (var i = 0; i < widget.item.qty; i++)
      TextEditingController(
        text: i < widget.item.imeis.length ? widget.item.imeis[i] : '',
      ),
  ];
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final saved = await ApiService.setImeis(widget.item.id!, [
        for (final c in _fields)
          if (c.text.trim().isNotEmpty) c.text.trim(),
      ]);
      if (!mounted) return;
      showMessage(context, trf('បានរក្សាទុក IMEI', 'IMEIs saved'));
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'IMEI · ${widget.item.label}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                trf(
                  'វាយ *#06# លើទូរស័ព្ទ ដើម្បីមើល IMEI (15 ខ្ទង់)',
                  'Dial *#06# on the phone to see its IMEI (15 digits)',
                ),
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < _fields.length; i++) ...[
                TextFormField(
                  controller: _fields[i],
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: 1,
                  ),
                  decoration: InputDecoration(
                    labelText: _fields.length == 1
                        ? 'IMEI'
                        : trf(
                            'IMEI គ្រឿងទី ${i + 1}',
                            'IMEI of phone ${i + 1}',
                          ),
                    prefixIcon: const Icon(Icons.qr_code_scanner),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  validator: (v) {
                    final imei = v!.trim();
                    if (imei.isEmpty) return null; // may be added later
                    if (imei.length != 15) {
                      return trf(
                        'IMEI ត្រូវមាន 15 ខ្ទង់',
                        'An IMEI has 15 digits',
                      );
                    }
                    if (!imeiLooksRight(imei)) {
                      return trf(
                        'លេខនេះមិនត្រឹមត្រូវ សូមពិនិត្យម្តងទៀត',
                        'This number is not valid, check it again',
                      );
                    }
                    final same = _fields.where((c) => c.text.trim() == imei);
                    if (same.length > 1) {
                      return trf('IMEI ដដែលពីរដង', 'Same IMEI twice');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
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

// Admin: a customer brings a phone back. Type its IMEI to see who bought it,
// when, and whether it is still under warranty.
class WarrantyLookupScreen extends StatefulWidget {
  const WarrantyLookupScreen({super.key});

  @override
  State<WarrantyLookupScreen> createState() => _WarrantyLookupScreenState();
}

class _WarrantyLookupScreenState extends State<WarrantyLookupScreen> {
  final _imei = TextEditingController();
  Map<String, dynamic>? _result;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _imei.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final imei = _imei.text.trim();
    if (imei.length != 15) {
      setState(() {
        _error = trf('IMEI ត្រូវមាន 15 ខ្ទង់', 'An IMEI has 15 digits');
        _result = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ApiService.lookupWarranty(imei);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = null;
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(color: AppColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _card(Map<String, dynamic> r) {
    final until = DateTime.tryParse('${r['warranty_until'] ?? ''}')?.toLocal();
    final delivered = DateTime.tryParse(
      '${r['delivered_at'] ?? ''}',
    )?.toLocal();
    final sold = DateTime.tryParse('${r['sold_at'] ?? ''}')?.toLocal();
    final covered = r['under_warranty'] == true;
    final months = r['warranty_months'] ?? 0;
    final (label, color, icon) = months == 0
        ? (
            trf('លក់ដោយគ្មានធានា', 'Sold without warranty'),
            AppColors.muted,
            Icons.remove_moderator_outlined,
          )
        : until == null
        ? (
            trf(
              'មិនទាន់ដឹកដល់ (ធានាមិនទាន់ចាប់ផ្តើម)',
              'Not delivered yet (warranty not started)',
            ),
            AppColors.amber,
            Icons.hourglass_empty,
          )
        : covered
        ? (
            trf('នៅក្នុងការធានា', 'Under warranty'),
            AppColors.green,
            Icons.verified_user,
          )
        : (
            trf('ផុតការធានាហើយ', 'Warranty ended'),
            AppColors.red,
            Icons.gpp_bad_outlined,
          );
    final options = [
      r['color'],
      r['storage'],
    ].where((s) => '${s ?? ''}'.isNotEmpty).join(', ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: glassDecoration(radius: AppRadius.lg, shadow: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(
            trf('ទូរស័ព្ទ', 'Phone'),
            options.isEmpty ? '${r['product']}' : '${r['product']} ($options)',
          ),
          _row('IMEI', '${r['imei']}'),
          _row(
            trf('អតិថិជន', 'Customer'),
            '${r['customer_name']} · ${r['phone']}',
          ),
          _row('Order', '${r['order_code'] ?? '#${r['order_id']}'}'),
          if (sold != null) _row(trf('ថ្ងៃទិញ', 'Bought'), _day(sold)),
          if (delivered != null)
            _row(trf('ថ្ងៃទទួល', 'Delivered'), _day(delivered)),
          if (months != 0)
            _row(trf('ធានា', 'Warranty'), trf('$months ខែ', '$months months')),
          if (until != null) _row(trf('ធានាដល់', 'Covered until'), _day(until)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: Text(trf('ពិនិត្យការធានា', 'Warranty check'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _imei,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'IMEI',
                    helperText: trf(
                      'វាយ *#06# លើទូរស័ព្ទ ដើម្បីមើល',
                      'Dial *#06# on the phone to see it',
                    ),
                    errorText: _error,
                    errorMaxLines: 2,
                    prefixIcon: const Icon(Icons.qr_code_scanner),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _busy ? null : _search,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(trf('ស្វែងរក', 'Search')),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_result != null) _card(_result!),
        ],
      ),
    );
  }
}
