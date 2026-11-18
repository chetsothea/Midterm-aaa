import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/save_file.dart';
import '../data/models/order.dart';
import '../components/common.dart';
import '../hooks/language.dart';
import '../components/brand_wordmark.dart';
import '../theme/app_theme.dart';

Color get _navy => AppColors.text;
Color get _muted => AppColors.muted;

// "INV-7K3Q9A" from the order's random code, so a bill doesn't show how many orders
// the shop has had. "INV-000018" only for an order without a code.
String invoiceNumber(Order order) => order.code.isNotEmpty
    ? 'INV-${order.code.replaceFirst('PS-', '')}'
    : 'INV-${order.id.toString().padLeft(6, '0')}';

// One A4 page holding the invoice picture, centred with a margin
Future<Uint8List> invoicePdf(Uint8List png) async {
  final doc = pw.Document(title: 'PS168 invoice', creator: 'PS168');
  final picture = pw.MemoryImage(png);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Center(child: pw.Image(picture, fit: pw.BoxFit.contain)),
    ),
  );
  return doc.save();
}

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

  // The bill as a sharp picture, drawn by Flutter so Khmer reads right
  Future<Uint8List> _png() async {
    final boundary =
        _paper.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return png!.buffer.asUint8List();
  }

  // On the web it downloads; on a phone it opens the share sheet (Telegram,
  // Files, a printer app ...). PDF puts the same picture on an A4 page, so it
  // prints at the right size and Khmer stays correct.
  Future<void> _save({required bool pdf}) async {
    setState(() => _isSaving = true);
    try {
      final png = await _png();
      final base = invoiceNumber(_order);
      if (pdf) {
        await saveOrShareFile(
          await invoicePdf(png),
          '$base.pdf',
          'application/pdf',
        );
      } else {
        await saveOrShareFile(png, '$base.png', 'image/png');
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600),
  );

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: _muted)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: value),
      ],
    ),
  );

  Widget _item(OrderItem item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
                style: TextStyle(fontSize: 13, color: _muted),
              ),
              for (final imei in item.imeis)
                Text(
                  'IMEI $imei',
                  style: TextStyle(
                    fontSize: 12,
                    color: _muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (item.warrantyMonths > 0) _warranty(item),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          money(item.price * item.qty),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  // "Under warranty until 18/05/2027 (181 days left)", or how long it will be
  Widget _warranty(OrderItem item) {
    final until = item.warrantyUntil;
    final left = item.warrantyDaysLeft;
    final active = left != null && left > 0;
    final color = until == null
        ? _muted
        : active
        ? const Color(0xFF1E9E4A)
        : AppColors.red;
    String day(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final text = until == null
        ? trf(
            'ធានា ${item.warrantyMonths} ខែ ចាប់ពីថ្ងៃទទួលឥវ៉ាន់',
            '${item.warrantyMonths}-month warranty from delivery',
          )
        : active
        ? trf(
            'ធានាដល់ ${day(until)} (នៅសល់ $left ថ្ងៃ)',
            'Warranty until ${day(until)} ($left days left)',
          )
        : trf('ផុតធានា ${day(until)}', 'Warranty ended ${day(until)}');
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 05/11/2026 10:30, in the reader's own time
  static String _when(DateTime time) {
    final t = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  // A soft grey box with a small heading, for the order and buyer details
  Widget _box(String title, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_label(title), const SizedBox(height: 6), ...children],
    ),
  );

  // Navy band with the logo, the word "invoice" and its number
  Widget _header(Order order) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_navy, Color(0xFF3D7BFF)],
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
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Image.asset('assets/images/logo.png'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandWordmark(height: 20),
              const SizedBox(height: AppSpacing.xxs),
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
            Container(width: 5, height: 1.5, color: AppColors.outline),
        ],
      );
    },
  );

  Widget _invoice() {
    final order = _order;
    final paid = order.paymentStatus == 'paid';
    final pieces = order.items.fold<int>(0, (sum, item) => sum + item.qty);
    return Container(
      color: AppColors.glass,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: AppColors.text2, fontSize: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(order),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Order and buyer side by side when there's room, else one under the other
                  LayoutBuilder(
                    builder: (context, box) {
                      final details = _box('Order', [
                        Text(
                          order.ref,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _when(order.createdAt),
                          style: TextStyle(fontSize: 12, color: _muted),
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
                            style: TextStyle(fontSize: 12, color: _muted),
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
                  const SizedBox(height: AppSpacing.md),
                  // The items, under a navy heading row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            trf('ទំនិញ ($pieces)', 'Items ($pieces)'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                        ),
                        Text(
                          trf('តម្លៃ', 'Amount'),
                          style: TextStyle(
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
                          if (i > 0) Divider(height: 1, color: AppColors.page),
                          _item(order.items[i]),
                        ],
                      ],
                    ),
                  ),
                  // Delivery and discount (orders from before fees have neither)
                  if (order.subtotal != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                      child: Column(
                        children: [
                          Divider(height: 1, color: AppColors.line),
                          const SizedBox(height: 6),
                          _charge(
                            trf('ទំនិញ', 'Phones'),
                            money(order.subtotal!),
                          ),
                          _charge(
                            trf('ថ្លៃដឹកជញ្ជូន', 'Delivery'),
                            order.shippingFee == 0
                                ? trf('ឥតគិតថ្លៃ', 'Free')
                                : money(order.shippingFee),
                          ),
                          if (order.discount > 0)
                            _charge(
                              trf(
                                'បញ្ចុះតម្លៃ (${order.voucherCode})',
                                'Discount (${order.voucherCode})',
                              ),
                              '-${money(order.discount)}',
                              color: const Color(0xFF1E9E4A),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  // The total, highlighted, with a "paid" stamp once the money is in
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: paid ? const Color(0xFFF0FDF4) : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: paid ? const Color(0xFFBBF7D0) : AppColors.line,
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _muted,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  money(order.total),
                                  style: TextStyle(
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
                                vertical: AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF30D158),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              child: const Text(
                                'PAID',
                                style: TextStyle(
                                  color: Color(0xFF30D158),
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
                  const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.md),
                  _dashes(),
                  const SizedBox(height: 14),
                  Text(
                    tr('សូមអរគុណដែលបានទិញពី PS168'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _charge(String label, String value, {Color? color}) {
    final style = TextStyle(
      color: color ?? _muted,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(title: Text(tr('វិក្កយបត្រ'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.sm),
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
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _save(pdf: false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(trf('រូបភាព', 'Picture')),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : () => _save(pdf: true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(trf('PDF / បោះពុម្ព', 'PDF / Print')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
