import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../widgets/buying_steps.dart';
import '../widgets/common.dart';
import '../widgets/store_app_bar.dart';
import 'invoice_screen.dart';
import '../services/language.dart';

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

  static const _navy = Color(0xFF0F2A5F);
  static const _orange = Color(0xFFF97316);

  static final _card = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  // Which order, and how much to pay, on the shop's colours
  Widget _amount() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, Color(0xFF0E7490)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F2A5F),
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
                const SizedBox(height: 4),
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_navy, Color(0xFF0E7490)],
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

  Widget _payView(Map<String, dynamic> info) {
    final qr = (info['qr_image_url'] ?? '') as String;
    final account = (info['account_number'] ?? '') as String;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        const BuyingSteps(current: 2),
        const SizedBox(height: 12),
        _amount(),
        const SizedBox(height: 12),
        // The shop's QR and bank account
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _card,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 20,
                    color: Color(0xFF0E7490),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      trf('Scan ដើម្បីបង់ប្រាក់', 'Scan to pay'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // The QR in a framed tile with scan corners, so it reads as "point here"
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    child: qr.isNotEmpty
                        ? Image.network(
                            qr,
                            height: 210,
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.fallback,
                          )
                        : const Icon(Icons.qr_code_2, size: 160),
                  ),
                ),
              ),
              const Divider(height: 28),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(
                      0xFF0E7490,
                    ).withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.account_balance,
                      color: Color(0xFF0E7490),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info['bank_name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                        ),
                        Text(
                          info['account_name'] ?? '',
                          style: const TextStyle(color: Colors.black54),
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
                      icon: const Icon(Icons.copy, color: Color(0xFF0E7490)),
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
        const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              // Optional: only helps the admin find the payment
              TextField(
                controller: _ref,
                decoration: InputDecoration(
                  labelText: tr('លេខប្រតិបត្តិការ (មិនចាំបាច់)'),
                  prefixIcon: const Icon(Icons.tag),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton.icon(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _orange,
                        minimumSize: const Size.fromHeight(50),
                        elevation: 2,
                        shadowColor: const Color(0x66F97316),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _start, child: Text(tr('Try again'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: storeAppBar(title: Text(trf('បង់ប្រាក់', 'Payment'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
      ..color = const Color(0xFF0E7490)
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
