import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/order.dart';
import '../data/models/payment_account.dart';
import '../data/api_service.dart';
import '../components/bakong_pay_card.dart';
import '../components/buying_steps.dart';
import '../components/common.dart';
import '../components/store_app_bar.dart';
import 'invoice_screen.dart';
import '../hooks/language.dart';
import '../components/ux.dart';
import '../theme/app_theme.dart';

// The shop's own QR and bank account: the customer pays, taps "I have paid",
// and the admin checks the shop's bank app and confirms the order.
class PaymentScreen extends StatefulWidget {
  final Order order;

  const PaymentScreen({super.key, required this.order});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _ref = TextEditingController();
  bool _isLoading = false;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _info;
  List<PaymentAccount> _accounts = const [];
  int _bank = 0; // which bank's QR is showing

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _info = await ApiService.fetchPaymentInfo();
      _accounts = PaymentAccount.listFromInfo(_info!);
      _bank = 0;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  // Show the bill right away; whoever opened this page still gets its result
  void _openInvoice(Order order) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => InvoiceScreen(order: order)),
      result: true,
    );
  }

  void _submit() async {
    setState(() => _isLoading = true);
    try {
      final paid = await ApiService.submitPayment(widget.order.id, _ref.text);
      if (!mounted) return;
      showMessage(
        context,
        tr('បានផ្ញើ! សូមរង់ចាំ Admin ផ្ទៀងផ្ទាត់ការបង់ប្រាក់'),
      );
      _openInvoice(paid);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  static Color get _navy => AppColors.text;
  static const _orange = Color(0xFF3D7BFF);

  static BoxDecoration get _card => BoxDecoration(
    color: AppColors.glass,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  // Which order, and how much to pay, on the shop's colours
  Widget _amount() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, Color(0xFF3D7BFF)],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Which order this is for, now that the title no longer says it
                Text(
                  'Order ${widget.order.ref}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  tr('ចំនួនទឹកប្រាក់ត្រូវបង់'),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(widget.order.total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFFFBBF24),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  // One numbered step of paying
  Widget _step(int n, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_navy, Color(0xFF3D7BFF)],
              ),
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  // Bakong confirmed the money arrived
  void _paidByBakong(Order paid) {
    showMessage(
      context,
      trf('បានទទួលការបង់ប្រាក់ហើយ! អរគុណ', 'Payment received, thank you!'),
    );
    _openInvoice(paid);
  }

  // Bakong on: the order's own KHQR, checked with the bank automatically
  Widget _bakongView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        const BuyingSteps(current: 2),
        const SizedBox(height: AppSpacing.sm),
        if (widget.order.payBefore != null) ...[
          PayBeforeBanner(deadline: widget.order.payBefore!),
          const SizedBox(height: AppSpacing.sm),
        ],
        BakongPayCard(order: widget.order, onPaid: _paidByBakong),
        const SizedBox(height: AppSpacing.md),
        // Paid but it doesn't show (e.g. paid from another account)? The admin checks
        Center(
          child: _isLoading
              ? BusyBar(label: trf('កំពុងផ្ញើ...', 'Sending...'))
              : TextButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.help_outline_rounded),
                  label: Text(
                    trf(
                      'បានបង់ហើយ តែមិនឃើញបញ្ជាក់? ផ្ញើឱ្យ Admin ពិនិត្យ',
                      'Paid but not confirmed? Ask the admin to check',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _payView(Map<String, dynamic> info) {
    if (widget.order.bakongQr.isNotEmpty) return _bakongView();
    final bank = _accounts[_bank.clamp(0, _accounts.length - 1)];
    final qr = bank.qrImageUrl;
    final account = bank.accountNumber;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        const BuyingSteps(current: 2),
        const SizedBox(height: AppSpacing.sm),
        _amount(),
        if (widget.order.payBefore != null) ...[
          const SizedBox(height: AppSpacing.sm),
          PayBeforeBanner(deadline: widget.order.payBefore!),
        ],
        const SizedBox(height: AppSpacing.sm),
        // The shop's QR and bank account
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: _card,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 20,
                    color: Color(0xFF3D7BFF),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      trf('Scan ដើម្បីបង់ប្រាក់', 'Scan to pay'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                    ),
                  ),
                ],
              ),
              if (_accounts.length > 1) ...[
                const SizedBox(height: AppSpacing.sm),
                BankSwitcher(
                  accounts: _accounts,
                  selected: _bank,
                  onSelected: (i) => setState(() => _bank = i),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              // The QR in a framed tile with scan corners, so it reads as "point here"
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F0F2A5F),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: CustomPaint(
                  foregroundPainter: _ScanCorners(),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    // Cross-fades to the other bank's QR when switched
                    child: AnimatedSwitcher(
                      duration: AppDuration.medium,
                      child: qr.isNotEmpty
                          ? Image.network(
                              qr,
                              key: ValueKey(qr),
                              height: 210,
                              webHtmlElementStrategy:
                                  WebHtmlElementStrategy.fallback,
                              errorBuilder: (_, _, _) => const SizedBox(
                                height: 210,
                                child: Icon(Icons.qr_code_2, size: 160),
                              ),
                            )
                          : Column(
                              key: ValueKey('noqr$_bank'),
                              children: [
                                const Icon(Icons.qr_code_2, size: 160),
                                Text(
                                  trf(
                                    'សូមផ្ទេរប្រាក់ទៅលេខគណនីខាងក្រោម',
                                    'Transfer to the account below',
                                  ),
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 28),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(
                      0xFF3D7BFF,
                    ).withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.account_balance,
                      color: Color(0xFF3D7BFF),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank.bankName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                        ),
                        Text(
                          bank.accountName,
                          style: TextStyle(color: AppColors.muted),
                        ),
                        SelectableText(
                          account,
                          style: const TextStyle(
                            fontSize: 18,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Copy the account number to paste into the bank app
                  if (account.isNotEmpty)
                    IconButton(
                      tooltip: trf('ចម្លងលេខគណនី', 'Copy account number'),
                      icon: const Icon(Icons.copy, color: Color(0xFF3D7BFF)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: account));
                        showMessage(context, trf('បានចម្លង', 'Copied'));
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // How to pay, step by step, then the button
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _step(1, tr('Scan KHQR ឬផ្ទេរប្រាក់ទៅគណនីខាងលើ')),
              _step(2, tr('បង់រួច ចុចប៊ូតុង «ខ្ញុំបានបង់ប្រាក់រួចហើយ»')),
              _step(3, tr('Admin នឹងផ្ទៀងផ្ទាត់ ហើយបញ្ជាក់ Order របស់អ្នក')),
              const SizedBox(height: AppSpacing.sm),
              // Optional: only helps the admin find the payment
              TextField(
                controller: _ref,
                decoration: InputDecoration(
                  labelText: tr('លេខប្រតិបត្តិការ (មិនចាំបាច់)'),
                  prefixIcon: const Icon(Icons.tag),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _isLoading
                  ? BusyBar(label: trf('កំពុងបញ្ជាក់...', 'Confirming...'))
                  : FilledButton.icon(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _orange,
                        minimumSize: const Size.fromHeight(50),
                        elevation: 2,
                        shadowColor: const Color(0x663D7BFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(tr('ខ្ញុំបានបង់ប្រាក់រួចហើយ')),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return StatusView(
      icon: Icons.wifi_off_rounded,
      error: true,
      title: trf('មិនអាចភ្ជាប់ទៅហាងបានទេ', "Can't reach the shop"),
      message: '$_error',
      actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
      onAction: _start,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: Text(trf('បង់ប្រាក់', 'Payment'))),
      body: _loading
          ? const ListSkeleton(rows: 2)
          : _error != null
          ? _errorView()
          : _payView(_info!),
    );
  }
}

// Four teal corner marks around the QR, like a camera's scan frame
class _ScanCorners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 22.0;
    final paint = Paint()
      ..color = const Color(0xFF3D7BFF)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + len * dx, y), paint);
      canvas.drawLine(Offset(x, y), Offset(x, y + len * dy), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanCorners oldDelegate) => false;
}

// "Pay within 29:41" — the time left before an unpaid KHQR order is
// cancelled and its phones go back on the shelf. Turns red in the last
// 5 minutes, and says so plainly once the time is up.
class PayBeforeBanner extends StatefulWidget {
  final DateTime deadline;

  const PayBeforeBanner({super.key, required this.deadline});

  @override
  State<PayBeforeBanner> createState() => _PayBeforeBannerState();
}

class _PayBeforeBannerState extends State<PayBeforeBanner> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!widget.deadline.isAfter(DateTime.now())) _tick?.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.deadline.difference(DateTime.now());
    final over = left <= Duration.zero;
    final urgent = left < const Duration(minutes: 5);
    final color = urgent ? AppColors.red : AppColors.amber;
    final mm = left.inMinutes.clamp(0, 999).toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              over ? Icons.timer_off_rounded : Icons.timer_outlined,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                over
                    ? trf(
                        'ហួសពេលបង់ប្រាក់ហើយ Order នេះនឹងត្រូវបោះបង់',
                        'Time is up: this order will be cancelled',
                      )
                    : trf(
                        'សូមបង់ប្រាក់ក្នុងរយៈពេល ទើប Order មិនត្រូវបោះបង់',
                        'Pay in time, or the order is cancelled',
                      ),
                style: TextStyle(color: AppColors.text, fontSize: 13),
              ),
            ),
            if (!over) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$mm:$ss',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ABA | ACLEDA | ... : picks whose QR and account number are shown
class BankSwitcher extends StatelessWidget {
  final List<PaymentAccount> accounts;
  final int selected;
  final ValueChanged<int> onSelected;

  const BankSwitcher({
    super.key,
    required this.accounts,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < accounts.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: () {
                    if (i == selected) return;
                    Haptics.tap();
                    onSelected(i);
                  },
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    curve: Curves.easeOut,
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? AppColors.accent : null,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      accounts[i].shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: i == selected ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
