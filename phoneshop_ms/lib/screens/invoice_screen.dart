import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order.dart';
import '../widgets/common.dart';
import '../services/language.dart';
import '../widgets/brand_wordmark.dart';

const _navy = Color(0xFF0F2A5F);
const _muted = Color(0xFF64748B);

// "INV-7K3Q9A" from the order's random code, so a bill doesn't show how many orders
// the shop has had. "INV-000018" only for an order without a code.
String invoiceNumber(Order order) => order.code.isNotEmpty
    ? 'INV-${order.code.replaceFirst('PS-', '')}'
    : 'INV-${order.id.toString().padLeft(6, '0')}';

// The bill for one order. It can be saved as a picture, so it reads the same anywhere.
class InvoiceScreen extends StatefulWidget {
  final Order order;

  const InvoiceScreen({super.key, required this.order});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _paper = GlobalKey();
  bool _isSaving = false;

  Order get _order => widget.order;

  // On the web it downloads; on a phone it opens the share sheet (Telegram, Photos, ...)
  void _save() async {
    setState(() {
      _isSaving = true;
    });
    try {
      final boundary =
          _paper.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final name = '${invoiceNumber(_order)}.png';
      final file = XFile.fromData(
        png!.buffer.asUint8List(),
        name: name,
        mimeType: 'image/png',
      );
      if (kIsWeb) {
        await file.saveTo(name);
      } else {
        await SharePlus.instance.share(
          ShareParams(files: [file], fileNameOverrides: [name]),
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      color: _muted,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _muted)),
        const SizedBox(width: 12),
        Flexible(child: value),
      ],
    ),
  );

  Widget _item(OrderItem item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${money(item.price)} × ${item.qty}',
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          money(item.price * item.qty),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  // 05/11/2026 10:30, in the reader's own time
  static String _when(DateTime time) {
    final t = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  // A soft grey box with a small heading, for the order and buyer details
  Widget _box(String title, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_label(title), const SizedBox(height: 6), ...children],
    ),
  );

  // Navy band with the logo, the word "invoice" and its number
  Widget _header(Order order) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_navy, Color(0xFF0E7490)],
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(
            3,
          ), // a thin white edge, so the navy icon stands out on the navy band
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Image.asset('assets/images/logo.png'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandWordmark(height: 20),
              const SizedBox(height: 4),
              const Text(
                'Phone Shop',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              tr('វិក្កយបត្រ'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              invoiceNumber(order),
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // A dashed line, like the tear-off edge of a receipt
  Widget _dashes() => LayoutBuilder(
    builder: (context, box) {
      final count = (box.maxWidth / 9).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < count; i++)
            Container(width: 5, height: 1.5, color: const Color(0xFFCBD5E1)),
        ],
      );
    },
  );

  Widget _invoice() {
    final order = _order;
    final paid = order.paymentStatus == 'paid';
    final pieces = order.items.fold<int>(0, (sum, item) => sum + item.qty);
    return Container(
      color: Colors.white,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(order),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (order.status == 'cancelled') ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        tr('Order នេះត្រូវបានបោះបង់'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Order and buyer side by side when there's room, else one under the other
                  LayoutBuilder(
                    builder: (context, box) {
                      final details = _box('Order', [
                        Text(
                          order.ref,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _when(order.createdAt),
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ]);
                      final buyer = _box(tr('អ្នកទិញ'), [
                        Text(
                          order.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (order.phone.isNotEmpty) Text(order.phone),
                        if (order.customerEmail.isNotEmpty)
                          Text(order.customerEmail),
                        if (order.address.isNotEmpty)
                          Text(
                            order.address,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                      ]);
                      if (box.maxWidth < 380) {
                        return Column(
                          children: [
                            details,
                            const SizedBox(height: 10),
                            buyer,
                          ],
                        );
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 130, child: details),
                            const SizedBox(width: 10),
                            Expanded(child: buyer),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // The items, under a navy heading row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            trf('ទំនិញ ($pieces)', 'Items ($pieces)'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                        ),
                        Text(
                          trf('តម្លៃ', 'Amount'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        for (var i = 0; i < order.items.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _item(order.items[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // The total, highlighted, with a "paid" stamp once the money is in
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: paid
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: paid
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('សរុប'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _muted,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  money(order.total),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: _navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (paid)
                          Transform.rotate(
                            angle: -0.2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF16A34A),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'PAID',
                                style: TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _row(
                    tr('វិធីបង់ប្រាក់'),
                    Text(
                      paymentMethodLabels[order.paymentMethod] ??
                          order.paymentMethod,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  _row(
                    tr('ស្ថានភាពបង់ប្រាក់'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: StatusBadge(
                        status: order.paymentStatus,
                        label:
                            paymentStatusLabels[order.paymentStatus] ??
                            order.paymentStatus,
                      ),
                    ),
                  ),
                  if (order.transactionRef != null)
                    _row(
                      'Transaction ID',
                      Text(order.transactionRef!, textAlign: TextAlign.end),
                    ),
                  const SizedBox(height: 16),
                  _dashes(),
                  const SizedBox(height: 14),
                  Text(
                    tr('សូមអរគុណដែលបានទិញពី PS168'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: Text(tr('វិក្កយបត្រ'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: RepaintBoundary(key: _paper, child: _invoice()),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            icon: Icon(kIsWeb ? Icons.download : Icons.share),
            label: Text(
              kIsWeb ? tr('ទាញយកវិក្កយបត្រ') : tr('រក្សាទុក / ផ្ញើវិក្កយបត្រ'),
            ),
          ),
        ),
      ),
    );
  }
}
