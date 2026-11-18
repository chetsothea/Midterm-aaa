import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../components/common.dart';
import '../../components/confirm_dialog.dart';
import '../../components/store_app_bar.dart';
import '../../components/ux.dart';
import '../../data/api_service.dart';
import '../../data/models/payment_account.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

// Admin: the banks customers can pay a KHQR order into (ABA, ACLEDA, ...).
// Each one has its name, account number and its KHQR picture; customers pick
// between them with tabs on the payment page.
class AdminPaymentAccountsScreen extends StatefulWidget {
  const AdminPaymentAccountsScreen({super.key});

  @override
  State<AdminPaymentAccountsScreen> createState() =>
      _AdminPaymentAccountsScreenState();
}

class _AdminPaymentAccountsScreenState
    extends State<AdminPaymentAccountsScreen> {
  List<PaymentAccount> _accounts = [];
  bool _loading = true;
  String? _error;

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
      _accounts = await ApiService.fetchPaymentAccounts();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([PaymentAccount? account]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => PaymentAccountForm(account: account),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(PaymentAccount account) async {
    final yes = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      color: AppColors.red,
      title: trf('លុបធនាគារនេះ?', 'Remove this bank?'),
      code: account.bankName,
      message: trf(
        'អតិថិជននឹងមិនឃើញ QR របស់ធនាគារនេះទៀតទេ',
        'Customers will no longer see this QR',
      ),
      cancelLabel: trf('ទេ', 'No'),
      confirmLabel: trf('លុប', 'Remove'),
    );
    if (!yes || account.id == null) return;
    try {
      await ApiService.deletePaymentAccount(account.id!);
      if (!mounted) return;
      showMessage(context, trf('បានលុប', 'Removed'));
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Widget _tile(PaymentAccount a) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: glassDecoration(radius: AppRadius.lg, shadow: false),
      child: Row(
        children: [
          // The QR, small, so the admin sees at a glance which bank has one
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: 64,
              height: 64,
              color: Colors.white,
              child: a.qrImageUrl.isEmpty
                  ? const Icon(Icons.qr_code_2, color: Colors.black26, size: 40)
                  : Image.network(
                      a.qrImageUrl,
                      fit: BoxFit.contain,
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.bankName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(a.accountName, style: TextStyle(color: AppColors.muted)),
                Text(
                  a.accountNumber,
                  style: TextStyle(
                    color: AppColors.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (a.qrImageUrl.isEmpty)
                  Text(
                    trf('មិនទាន់មាន QR', 'No QR yet'),
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: trf('កែ', 'Edit'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(a),
          ),
          IconButton(
            tooltip: trf('លុប', 'Remove'),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.red,
            ),
            onPressed: () => _delete(a),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(
        title: Text(trf('គណនីបង់ប្រាក់ KHQR', 'KHQR bank accounts')),
      ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _edit,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(trf('បន្ថែមធនាគារ', 'Add bank')),
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
          : _accounts.isEmpty
          ? StatusView(
              icon: Icons.account_balance_outlined,
              title: trf('មិនទាន់មានធនាគារ', 'No banks yet'),
              message: trf(
                'បន្ថែម ABA, ACLEDA ... ជាមួយ QR របស់វា ដើម្បីឱ្យអតិថិជនបង់ប្រាក់',
                'Add ABA, ACLEDA ... with their QR so customers can pay',
              ),
              actionLabel: trf('បន្ថែមធនាគារ', 'Add bank'),
              onAction: _edit,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                Text(
                  trf(
                    'អតិថិជនជ្រើសធនាគារតាម tab នៅទំព័របង់ប្រាក់ (តាមលំដាប់នេះ)',
                    'Customers pick a bank with tabs on the payment page (in this order)',
                  ),
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final a in _accounts) _tile(a),
              ],
            ),
    );
  }
}

// Add or edit one bank: quick picks for the usual banks, the account details,
// and the KHQR picture (shown big, so the admin can check it is the right one)
class PaymentAccountForm extends StatefulWidget {
  final PaymentAccount? account;

  const PaymentAccountForm({super.key, this.account});

  @override
  State<PaymentAccountForm> createState() => _PaymentAccountFormState();
}

class _PaymentAccountFormState extends State<PaymentAccountForm> {
  static const _banks = [
    'ABA Bank',
    'ACLEDA Bank',
    'Wing Bank',
    'Canadia Bank',
  ];

  final _form = GlobalKey<FormState>();
  late final _bank = TextEditingController(text: widget.account?.bankName);
  late final _name = TextEditingController(text: widget.account?.accountName);
  late final _number = TextEditingController(
    text: widget.account?.accountNumber,
  );
  XFile? _qr;
  Uint8List? _qrPreview;
  bool _removeQr = false;
  bool _saving = false;

  @override
  void dispose() {
    _bank.dispose();
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  // Kept sharp (no shrinking or recompressing), so phones can still scan it
  Future<void> _pickQr() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _qr = file;
      _qrPreview = bytes;
      _removeQr = false;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService.savePaymentAccount(
        {
          'bank_name': _bank.text.trim(),
          'account_name': _name.text.trim(),
          'account_number': _number.text.trim(),
        },
        id: widget.account?.id,
        qr: _qr,
        removeQr: _removeQr,
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

  InputDecoration _input(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  Widget _qrBox() {
    final oldUrl = _removeQr ? '' : (widget.account?.qrImageUrl ?? '');
    final Widget picture;
    if (_qrPreview != null) {
      picture = Image.memory(_qrPreview!, fit: BoxFit.contain);
    } else if (oldUrl.isNotEmpty) {
      picture = Image.network(
        oldUrl,
        fit: BoxFit.contain,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      );
    } else {
      picture = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_photo_alternate_outlined, size: 40),
          const SizedBox(height: AppSpacing.xxs),
          Text(trf('ចុចដើម្បីដាក់រូប QR', 'Tap to add the QR picture')),
        ],
      );
    }
    final hasQr = _qrPreview != null || oldUrl.isNotEmpty;
    return Column(
      children: [
        Semantics(
          button: true,
          label: trf('ជ្រើសរូប QR', 'Choose QR picture'),
          child: InkWell(
            onTap: _pickQr,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: hasQr ? Colors.white : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.line),
              ),
              child: picture,
            ),
          ),
        ),
        if (hasQr)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _pickQr,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: Text(trf('ប្តូររូប', 'Change')),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _qr = null;
                  _qrPreview = null;
                  _removeQr = widget.account?.qrImageUrl.isNotEmpty ?? false;
                }),
                icon: const Icon(Icons.close_rounded),
                label: Text(trf('ដករូបចេញ', 'Remove')),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final required = trf('សូមបំពេញ', 'Required');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.account == null
                    ? trf('បន្ថែមធនាគារ', 'Add bank')
                    : trf('កែធនាគារ', 'Edit bank'),
                style: AppText.title.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: AppSpacing.sm),
              // The usual banks, one tap to fill the name
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final b in _banks)
                    ChoiceChip(
                      label: Text(b.replaceAll(' Bank', '')),
                      selected: _bank.text == b,
                      onSelected: (_) => setState(() => _bank.text = b),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _bank,
                decoration: _input(
                  trf('ឈ្មោះធនាគារ', 'Bank name'),
                  Icons.account_balance,
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => (v ?? '').trim().isEmpty ? required : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _name,
                decoration: _input(
                  trf('ឈ្មោះគណនី', 'Account name'),
                  Icons.person_outline,
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? required : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _number,
                keyboardType: TextInputType.number,
                decoration: _input(
                  trf('លេខគណនី', 'Account number'),
                  Icons.numbers,
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? required : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                trf('រូប KHQR', 'KHQR picture'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _qrBox(),
              const SizedBox(height: AppSpacing.md),
              _saving
                  ? BusyBar(label: trf('កំពុងរក្សាទុក...', 'Saving...'))
                  : FilledButton.icon(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(trf('រក្សាទុក', 'Save')),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
