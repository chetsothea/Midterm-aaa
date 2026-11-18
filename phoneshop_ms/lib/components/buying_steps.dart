import 'package:flutter/material.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';

// Where the customer is in buying: Cart → Checkout → Payment.
// [current] is 1 on Checkout and 2 on Payment; steps before it show a ✓.
class BuyingSteps extends StatelessWidget {
  final int current;

  const BuyingSteps({super.key, required this.current});

  static Color get _navy => AppColors.text;
  static const _orange = Color(0xFF3D7BFF);
  static const _teal = Color(0xFF3D7BFF);
  static Color get _todo => AppColors.outline;

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
            color: now ? Colors.white : (done ? _teal : AppColors.muted),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
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
                color: index > current ? AppColors.muted : _navy,
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
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
