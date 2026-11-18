import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/common.dart';
import '../../components/confirm_dialog.dart';
import '../../components/store_app_bar.dart';
import '../../components/ux.dart';
import '../../data/api_service.dart';
import '../../data/models/trade_in.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';
import '../trade_in_screen.dart';

// Admin: old phones customers offer. Look at the photos, make an offer, and
// once the phone is in the shop, issue the credit code.
class AdminTradeInsScreen extends StatefulWidget {
  const AdminTradeInsScreen({super.key});

  @override
  State<AdminTradeInsScreen> createState() => _AdminTradeInsScreenState();
}

class _AdminTradeInsScreenState extends State<AdminTradeInsScreen> {
  static const _filters = ['', 'pending', 'offered', 'accepted', 'completed'];

  String _filter = '';
  List<TradeIn> _items = [];
  bool _loading = true;
  String? _error;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await ApiService.fetchAllTradeIns(_filter);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _run(
    TradeIn t,
    Future<TradeIn> Function() action,
    String done,
  ) async {
    setState(() => _busyId = t.id);
    try {
      await action();
      if (mounted) showMessage(context, done);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  // Amount and a note for the customer, e.g. "Battery 84%, small dent"
  Future<void> _offer(TradeIn t) async {
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (_) => _OfferDialog(tradeIn: t),
    );
    if (result == null) return;
    await _run(
      t,
      () => ApiService.offerTradeIn(t.id, result.$1, result.$2),
      trf('បានផ្ញើតម្លៃ', 'Offer sent'),
    );
  }

  Future<void> _reject(TradeIn t) async {
    final yes = await showConfirmDialog(
      context,
      icon: Icons.block,
      color: AppColors.red,
      title: trf('មិនទទួលទូរស័ព្ទនេះ?', 'Decline this phone?'),
      code: t.title,
      cancelLabel: trf('ទេ', 'No'),
      confirmLabel: trf('មិនទទួល', 'Decline'),
    );
    if (!yes) return;
    await _run(
      t,
      () => ApiService.rejectTradeIn(t.id, ''),
      trf('បានបដិសេធ', 'Declined'),
    );
  }

  Future<void> _complete(TradeIn t) async {
    final yes = await showConfirmDialog(
      context,
      icon: Icons.inventory_2_outlined,
      color: AppColors.green,
      title: trf('ហាងទទួលទូរស័ព្ទហើយ?', 'Phone received in the shop?'),
      code: '${t.title} · ${money(t.offerAmount ?? 0)}',
      message: trf(
        'អតិថិជននឹងទទួលកូដបញ្ចុះ ${money(t.offerAmount ?? 0)} ប្រើបានម្តង ក្នុង 90 ថ្ងៃ',
        'The customer gets a one-time ${money(t.offerAmount ?? 0)} code, valid 90 days',
      ),
      cancelLabel: trf('មិនទាន់', 'Not yet'),
      confirmLabel: trf('ចេញកូដ', 'Issue code'),
    );
    if (!yes) return;
    await _run(
      t,
      () => ApiService.completeTradeIn(t.id),
      trf('បានចេញកូដ', 'Code issued'),
    );
  }

  void _viewPhoto(String url) => showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: InteractiveViewer(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        ),
      ),
    ),
  );

  Widget _card(TradeIn t) {
    final busy = _busyId == t.id;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: glassDecoration(radius: AppRadius.lg, shadow: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              TradeInStatusChip(t.status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${t.customerName}${t.customerPhone.isEmpty ? '' : ' · ${t.customerPhone}'}',
            style: TextStyle(color: AppColors.text2, fontSize: 13),
          ),
          Text(
            [
              tradeInConditions[t.condition] ?? t.condition,
              if (t.batteryHealth != null)
                trf('ថ្ម ${t.batteryHealth}%', 'battery ${t.batteryHealth}%'),
              if (t.wantedProduct.isNotEmpty)
                trf('ចង់បាន ${t.wantedProduct}', 'wants ${t.wantedProduct}'),
            ].join(' · '),
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (t.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '“${t.notes}”',
                style: TextStyle(color: AppColors.text, fontSize: 13),
              ),
            ),
          if (t.photoUrls.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final url in t.photoUrls)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: InkWell(
                        onTap: () => _viewPhoto(url),
                        child: TradeInPhoto(url, size: 72),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (t.offerAmount != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                trf(
                  'តម្លៃផ្តល់: ${money(t.offerAmount!)}',
                  'Offer: ${money(t.offerAmount!)}',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
          if (t.voucherCode.isNotEmpty)
            Text(
              trf('កូដ: ${t.voucherCode}', 'Code: ${t.voucherCode}'),
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (t.isOpen)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                children: [
                  TextButton(
                    onPressed: () => _reject(t),
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                    child: Text(trf('មិនទទួល', 'Decline')),
                  ),
                  if (t.status != 'accepted')
                    OutlinedButton.icon(
                      onPressed: () => _offer(t),
                      icon: const Icon(Icons.price_change_outlined, size: 18),
                      label: Text(
                        t.status == 'offered'
                            ? trf('កែតម្លៃ', 'Change offer')
                            : trf('ផ្តល់តម្លៃ', 'Make offer'),
                      ),
                    ),
                  if (t.status == 'accepted')
                    FilledButton.icon(
                      onPressed: () => _complete(t),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                      ),
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: Text(
                        trf('ទទួលទូរស័ព្ទ · ចេញកូដ', 'Received · issue code'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _filterLabel(String f) => f.isEmpty
      ? trf('ទាំងអស់', 'All')
      : (tradeInStatuses[f] ?? f).split(' · ').first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: const Text('Trade-in')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      label: Text(_filterLabel(f)),
                      selected: _filter == f,
                      onSelected: (_) {
                        setState(() => _filter = f);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const ListSkeleton(rows: 3)
                : _error != null
                ? StatusView(
                    icon: Icons.wifi_off_rounded,
                    error: true,
                    title: trf(
                      'មិនអាចភ្ជាប់ទៅហាងបានទេ',
                      "Can't reach the shop",
                    ),
                    message: _error!,
                    actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
                    onAction: _load,
                  )
                : _items.isEmpty
                ? StatusView(
                    icon: Icons.swap_horiz_rounded,
                    title: trf('មិនទាន់មានសំណើ', 'No requests'),
                    message: trf(
                      'អតិថិជនស្នើពីទំព័រគណនី › ប្តូរទូរស័ព្ទចាស់',
                      'Customers send them from Account › Trade in',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                      children: [for (final t in _items) _card(t)],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// The offer form; owns its fields so they live as long as the dialog does
class _OfferDialog extends StatefulWidget {
  final TradeIn tradeIn;

  const _OfferDialog({required this.tradeIn});

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  late final _amount = TextEditingController(
    text: widget.tradeIn.offerAmount?.toStringAsFixed(0) ?? '',
  );
  late final _note = TextEditingController(text: widget.tradeIn.adminNote);
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _send() {
    final value = double.tryParse(_amount.text);
    if (value == null || value <= 0) {
      setState(() => _error = trf('សូមបញ្ចូលតម្លៃ', 'Enter an amount'));
      return;
    }
    Navigator.pop(context, (value, _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        trf(
          'ផ្តល់តម្លៃ · ${widget.tradeIn.title}',
          'Offer · ${widget.tradeIn.title}',
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                labelText: trf('តម្លៃ (\$) *', 'Amount (\$) *'),
                prefixIcon: const Icon(Icons.attach_money),
                errorText: _error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _note,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: trf('សារទៅអតិថិជន', 'Note to the customer'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(trf('បោះបង់', 'Cancel')),
        ),
        FilledButton(
          onPressed: _send,
          child: Text(trf('ផ្ញើតម្លៃ', 'Send offer')),
        ),
      ],
    );
  }
}
