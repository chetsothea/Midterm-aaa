import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../components/common.dart';
import '../components/confirm_dialog.dart';
import '../components/store_app_bar.dart';
import '../components/ux.dart';
import '../data/api_service.dart';
import '../data/models/phone.dart';
import '../data/models/trade_in.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';

Color tradeInStatusColor(String status) => switch (status) {
  'offered' => AppColors.accent,
  'accepted' => AppColors.amber,
  'completed' => AppColors.green,
  'declined' || 'rejected' || 'cancelled' => AppColors.muted,
  _ => AppColors.amber,
};

class TradeInStatusChip extends StatelessWidget {
  final String status;

  const TradeInStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = tradeInStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        tradeInStatuses[status] ?? status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// One trade-in photo, square
class TradeInPhoto extends StatelessWidget {
  final String url;
  final double size;

  const TradeInPhoto(this.url, {super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: Image.network(
      sizedImageUrl(url, size * MediaQuery.devicePixelRatioOf(context)),
      width: size,
      height: size,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: AppColors.surface,
        child: const Icon(Icons.broken_image_outlined),
      ),
    ),
  );
}

// A row of them, scrolling sideways when there are many
class TradeInPhotos extends StatelessWidget {
  final List<String> urls;
  final double size;

  const TradeInPhotos(this.urls, {super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) => TradeInPhoto(urls[i], size: size),
      ),
    );
  }
}

// Customer: offer an old phone to the shop and follow the deal. When the shop
// has the phone, the agreed amount becomes a discount code for checkout.
class TradeInScreen extends StatefulWidget {
  const TradeInScreen({super.key});

  @override
  State<TradeInScreen> createState() => _TradeInScreenState();
}

class _TradeInScreenState extends State<TradeInScreen> {
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
      _items = await ApiService.fetchMyTradeIns();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _new() async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TradeInFormScreen()),
    );
    if (sent == true) _load();
  }

  Future<void> _move(TradeIn t, String action) async {
    if (action != 'accept') {
      final yes = await showConfirmDialog(
        context,
        icon: Icons.close_rounded,
        color: AppColors.red,
        title: action == 'decline'
            ? trf('បដិសេធតម្លៃនេះ?', 'Decline this offer?')
            : trf('បោះបង់សំណើនេះ?', 'Cancel this request?'),
        code: t.title,
        cancelLabel: trf('ទេ', 'No'),
        confirmLabel: action == 'decline'
            ? trf('បដិសេធ', 'Decline')
            : trf('បោះបង់', 'Cancel it'),
      );
      if (!yes) return;
    }
    setState(() => _busyId = t.id);
    try {
      await ApiService.moveTradeIn(t.id, action);
      if (action == 'accept') Haptics.success();
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _how() {
    final steps = [
      (
        Icons.photo_camera_outlined,
        trf(
          'ផ្ញើព័ត៌មាន និងរូបទូរស័ព្ទចាស់',
          'Send your old phone\'s details and photos',
        ),
      ),
      (
        Icons.price_check,
        trf(
          'ហាងផ្តល់តម្លៃ (ជាធម្មតាក្នុង ១ ថ្ងៃ)',
          'The shop makes an offer (usually within a day)',
        ),
      ),
      (
        Icons.storefront_outlined,
        trf(
          'យល់ព្រម ហើយយកទូរស័ព្ទមកហាង',
          'Accept, then bring the phone to the shop',
        ),
      ),
      (
        Icons.local_offer_outlined,
        trf(
          'ទទួលកូដបញ្ចុះ ប្រើពេលទិញទូរស័ព្ទថ្មី',
          'Get a credit code for your new phone',
        ),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: glassDecoration(radius: AppRadius.lg, shadow: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trf('ប្តូរទូរស័ព្ទចាស់ យកថ្មី', 'Trade in your old phone'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(steps[i].$1, size: 18, color: AppColors.muted),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      steps[i].$2,
                      style: TextStyle(color: AppColors.text, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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
            [
              tradeInConditions[t.condition] ?? t.condition,
              if (t.batteryHealth != null)
                trf('ថ្ម ${t.batteryHealth}%', 'battery ${t.batteryHealth}%'),
              if (t.wantedProduct.isNotEmpty)
                trf('ចង់បាន ${t.wantedProduct}', 'wants ${t.wantedProduct}'),
            ].join(' · '),
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (t.photoUrls.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            TradeInPhotos(t.photoUrls, size: 56),
          ],
          if (t.offerAmount != null && t.status != 'rejected') ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Flexible(
                  child: Text(
                    trf('តម្លៃហាងផ្តល់: ', 'Shop offer: '),
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
                Text(
                  money(t.offerAmount!),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ],
          if (t.adminNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '“${t.adminNote}”',
                style: TextStyle(
                  color: AppColors.text2,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),
          if (t.status == 'accepted')
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                trf(
                  'សូមយកទូរស័ព្ទមកហាង។ ពេលហាងទទួលបាន អ្នកនឹងទទួលកូដបញ្ចុះ ${money(t.offerAmount ?? 0)}',
                  'Please bring the phone to the shop. Once received, you get a ${money(t.offerAmount ?? 0)} credit code',
                ),
                style: TextStyle(color: AppColors.text, fontSize: 13),
              ),
            ),
          if (t.status == 'completed' && t.voucherCode.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer,
                    color: AppColors.green,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          t.voucherCode,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          trf(
                            'វាយកូដនេះពេល Checkout · ប្រើបាន 90 ថ្ងៃ',
                            'Type it at checkout · valid 90 days',
                          ),
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: trf('ចម្លងកូដ', 'Copy code'),
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: t.voucherCode));
                      showMessage(context, trf('បានចម្លងកូដ', 'Code copied'));
                    },
                  ),
                ],
              ),
            ),
          ],
          if (t.status == 'offered' || t.isOpen) ...[
            const SizedBox(height: AppSpacing.sm),
            if (busy)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (t.status == 'offered')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _move(t, 'decline'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text(trf('បដិសេធ', 'Decline')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => _move(t, 'accept'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text(trf('យល់ព្រមតម្លៃនេះ', 'Accept offer')),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _move(t, 'cancel'),
                  child: Text(trf('បោះបង់សំណើ', 'Cancel request')),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: Text(trf('ប្តូរទូរស័ព្ទចាស់', 'Trade-in'))),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _new,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(trf('ស្នើ Trade-in', 'New trade-in')),
            ),
      body: _loading
          ? const ListSkeleton(rows: 2)
          : _error != null
          ? StatusView(
              icon: Icons.wifi_off_rounded,
              error: true,
              title: trf('មិនអាចភ្ជាប់ទៅហាងបានទេ', "Can't reach the shop"),
              message: _error!,
              actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
              onAction: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: [
                  _how(),
                  const SizedBox(height: AppSpacing.md),
                  for (final t in _items) _card(t),
                ],
              ),
            ),
    );
  }
}

// The request: which phone, its state, photos, and what they'd like instead
class TradeInFormScreen extends StatefulWidget {
  const TradeInFormScreen({super.key});

  @override
  State<TradeInFormScreen> createState() => _TradeInFormScreenState();
}

class _TradeInFormScreenState extends State<TradeInFormScreen> {
  static const _brands = [
    'Apple',
    'Samsung',
    'Xiaomi',
    'Oppo',
    'Vivo',
    'Honor',
  ];
  static const _sizes = ['64GB', '128GB', '256GB', '512GB', '1TB'];
  static const _maxPhotos = 4;

  final _form = GlobalKey<FormState>();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _battery = TextEditingController();
  final _notes = TextEditingController();
  String _storage = '';
  String _condition = 'good';
  int? _wanted;
  List<Phone> _phones = [];
  final List<(XFile, Uint8List)> _photos = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    ApiService.fetchPhones()
        .then((p) {
          if (mounted) setState(() => _phones = p);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_brand, _model, _battery, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    for (final f in picked.take(_maxPhotos - _photos.length)) {
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() => _photos.add((f, bytes)));
    }
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ApiService.sendTradeIn(
        {
          'brand': _brand.text.trim(),
          'model': _model.text.trim(),
          if (_storage.isNotEmpty) 'storage': _storage,
          'condition': _condition,
          if (_battery.text.trim().isNotEmpty)
            'battery_health': _battery.text.trim(),
          if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
          if (_wanted != null) 'wanted_product_id': '$_wanted',
        },
        [for (final p in _photos) p.$1],
      );
      if (!mounted) return;
      Haptics.success();
      showMessage(
        context,
        trf(
          'បានផ្ញើ! ហាងនឹងផ្តល់តម្លៃឆាប់ៗ',
          'Sent! The shop will make an offer soon',
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _input(String label, IconData icon, {String? helper}) =>
      InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
    child: Text(
      text,
      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: Text(trf('ស្នើ Trade-in', 'New trade-in'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _label(trf('ទូរស័ព្ទចាស់របស់អ្នក', 'Your old phone')),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final b in _brands)
                  ChoiceChip(
                    label: Text(b),
                    selected: _brand.text == b,
                    onSelected: (_) => setState(() => _brand.text = b),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _brand,
              decoration: _input(
                trf('ម៉ាក *', 'Brand *'),
                Icons.business_outlined,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => v!.trim().isEmpty
                  ? trf('សូមបញ្ចូលម៉ាក', 'Enter the brand')
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _model,
              decoration: _input(
                trf('ម៉ូដែល *', 'Model *'),
                Icons.phone_iphone,
                helper: trf('ឧ. iPhone 13 Pro', 'e.g. iPhone 13 Pro'),
              ),
              validator: (v) => v!.trim().isEmpty
                  ? trf('សូមបញ្ចូលម៉ូដែល', 'Enter the model')
                  : null,
            ),
            _label('Storage'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final s in _sizes)
                  ChoiceChip(
                    label: Text(s),
                    selected: _storage == s,
                    onSelected: (on) => setState(() => _storage = on ? s : ''),
                  ),
              ],
            ),
            _label(trf('ស្ថានភាព *', 'Condition *')),
            RadioGroup<String>(
              groupValue: _condition,
              onChanged: (v) => setState(() => _condition = v!),
              child: Column(
                children: [
                  for (final e in tradeInConditions.entries)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: e.key,
                      title: Text(e.value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _battery,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: _input(
                trf('សុខភាពថ្ម (%)', 'Battery health (%)'),
                Icons.battery_charging_full,
                helper: trf(
                  'iPhone: Settings › Battery › Battery Health',
                  'iPhone: Settings › Battery › Battery Health',
                ),
              ),
              validator: (v) {
                if (v!.isEmpty) return null;
                final n = int.parse(v);
                return n < 1 || n > 100
                    ? trf('ពី 1 ដល់ 100', 'From 1 to 100')
                    : null;
              },
            ),
            _label(
              trf(
                'រូបភាព (យ៉ាងច្រើន $_maxPhotos)',
                'Photos (up to $_maxPhotos)',
              ),
            ),
            Text(
              trf(
                'មុខ ក្រោយ និងអេក្រង់ពេលបើក ជួយឱ្យហាងផ្តល់តម្លៃត្រឹមត្រូវ',
                'Front, back and the screen on help the shop price it right',
              ),
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.memory(
                          _photos[i].$2,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                                semanticLabel: trf('ដករូបចេញ', 'Remove photo'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_photos.length < _maxPhotos)
                  InkWell(
                    onTap: _addPhotos,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.line, width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: AppColors.muted,
                          ),
                          Text(
                            trf('បន្ថែម', 'Add'),
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            _label(
              trf(
                'ចង់ប្តូរយកទូរស័ព្ទណា? (បើមាន)',
                'Which phone do you want? (optional)',
              ),
            ),
            DropdownButtonFormField<int?>(
              initialValue: _wanted,
              isExpanded: true,
              decoration: _input(
                trf('ទូរស័ព្ទថ្មី', 'New phone'),
                Icons.phone_android,
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(trf('មិនទាន់សម្រេច', 'Not decided yet')),
                ),
                for (final p in _phones)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _wanted = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              maxLength: 1000,
              decoration: _input(
                trf('កំណត់សម្គាល់', 'Notes'),
                Icons.notes,
                helper: trf(
                  'ឧ. ធ្លាប់ប្តូរអេក្រង់ មានប្រអប់ដើម...',
                  'e.g. screen replaced once, has the box...',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(trf('ផ្ញើឱ្យហាងវាយតម្លៃ', 'Send for an offer')),
            ),
          ],
        ),
      ),
    );
  }
}
