import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/api_service.dart';
import '../data/models/order.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'ux.dart';

// The order's own KHQR (amount already inside). Any bank app scans it. While
// it is on screen the app asks the server every few seconds whether Bakong
// has the payment; the moment it does, [onPaid] gets the paid order. No
// "I have paid" button needed, and nobody can claim to have paid.
class BakongPayCard extends StatefulWidget {
  final Order order;
  final ValueChanged<Order> onPaid;

  // How often to ask; shorter in tests
  final Duration every;

  const BakongPayCard({
    super.key,
    required this.order,
    required this.onPaid,
    this.every = const Duration(seconds: 3),
  });

  @override
  State<BakongPayCard> createState() => _BakongPayCardState();
}

class _BakongPayCardState extends State<BakongPayCard> {
  Timer? _timer;
  bool _asking = false;
  bool _bakongDown = false;
  bool _done = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.every, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_asking || _done) return;
    _asking = true;
    try {
      final (order, down) = await ApiService.checkPayment(widget.order.id);
      if (!mounted) return;
      if (order.paymentStatus == 'paid') {
        _done = true;
        _timer?.cancel();
        Haptics.success();
        widget.onPaid(order);
        return;
      }
      if (order.status == 'cancelled') {
        // Time ran out: the QR must not be scanned any more
        _done = true;
        _timer?.cancel();
        setState(() => _cancelled = true);
        return;
      }
      if (down != _bakongDown) setState(() => _bakongDown = down);
    } catch (_) {
      // Offline for a moment: just ask again next time
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // The red KHQR header every Cambodian bank customer recognises
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            color: const Color(0xFFE21A1A),
            alignment: Alignment.center,
            child: const Text(
              'KHQR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                Text(
                  'PS168',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  money(widget.order.total),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Divider(height: AppSpacing.lg),
                // A cancelled order's QR is faded and crossed out, so nobody pays it
                ExcludeSemantics(
                  excluding: _cancelled,
                  child: Semantics(
                    label: trf('KHQR សម្រាប់បង់ប្រាក់', 'KHQR to pay'),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedOpacity(
                          opacity: _cancelled ? 0.12 : 1,
                          duration: const Duration(milliseconds: 250),
                          child: QrImageView(
                            data: widget.order.bakongQr,
                            size: 220,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                          ),
                        ),
                        if (_cancelled)
                          const Icon(
                            Icons.block_rounded,
                            size: 72,
                            color: Color(0xFFD32F2F),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  trf(
                    'Scan ជាមួយ App ធនាគារណាមួយ (ABA, ACLEDA, Wing ...)',
                    'Scan with any bank app (ABA, ACLEDA, Wing ...)',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
          // Live status: waiting, or Bakong slow to answer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color:
                (_cancelled
                        ? const Color(0xFFD32F2F)
                        : _bakongDown
                        ? AppColors.amber
                        : AppColors.accent)
                    .withValues(alpha: 0.12),
            child: Semantics(
              liveRegion: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_cancelled)
                    const Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: Color(0xFFD32F2F),
                    )
                  else
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _bakongDown ? AppColors.amber : AppColors.accent,
                      ),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      _cancelled
                          ? trf(
                              'Order ត្រូវបានបោះបង់ ព្រោះហួសម៉ោងបង់ប្រាក់។ សូមកុំ scan QR នេះ',
                              'Order cancelled: time to pay ran out. Do not scan this QR',
                            )
                          : _bakongDown
                          ? trf(
                              'Bakong យឺតបន្តិច កំពុងព្យាយាមម្តងទៀត...',
                              'Bakong is slow, still trying...',
                            )
                          : trf(
                              'កំពុងរង់ចាំការបង់ប្រាក់... បង់រួច Order បញ្ជាក់ដោយខ្លួនឯង',
                              'Waiting for payment... confirmed by itself once paid',
                            ),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
