import 'package:flutter/material.dart';
import '../services/language.dart';

// Where the customer is in buying: Cart → Checkout → Payment.
// [current] is 1 on Checkout and 2 on Payment; steps before it show a ✓.
class BuyingSteps extends StatelessWidget {
  final int current;

  const BuyingSteps({super.key, required this.current});

  static const _navy = Color(0xFF0F2A5F);
  static const _orange = Color(0xFFF97316);
  static const _teal = Color(0xFF0E7490);
  static const _todo = Color(0xFFCBD5E1);

  Widget _step(String label, IconData icon, int index) {
    final done = index < current;
    final now = index == current;
    final color = done ? _teal : (now ? _orange : _todo);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: now ? color : color.withValues(alpha: 0.14),
            boxShadow: now
                ? const [
                    BoxShadow(
                      color: Color(0x55F97316),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            done ? Icons.check : icon,
            size: 18,
            color: now
                ? Colors.white
                : (done ? _teal : const Color(0xFF94A3B8)),
          ),
        ),
        const SizedBox(height: 4),
        // A fixed width that shrinks the word if needed, so three steps fit any phone
        SizedBox(
          width: 64,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: now ? FontWeight.w800 : FontWeight.w500,
                color: index > current ? const Color(0xFF94A3B8) : _navy,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(bool done) => Expanded(
    child: Container(
      height: 3,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: done ? _teal : _todo,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _step(trf('កន្ត្រក', 'Cart'), Icons.shopping_cart_outlined, 0),
          _line(current > 0),
          _step('Checkout', Icons.assignment_outlined, 1),
          _line(current > 1),
          _step(trf('បង់ប្រាក់', 'Payment'), Icons.payments_outlined, 2),
        ],
      ),
    );
  }
}
