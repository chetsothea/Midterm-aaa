import 'package:flutter/material.dart';
import '../hooks/cart.dart';
import '../hooks/language.dart';
import '../theme/theme.dart';
import 'motion.dart';
import 'ux.dart';

// After a phone is taken out of the cart (swipe or bin): a bar slides up
// with "Removed …  Undo" and a ring that runs down for 4 seconds. Undo puts
// the line back where it was; when the ring runs out the bar slides away.
class CartUndoBar extends StatefulWidget {
  const CartUndoBar({super.key});

  static const duration = Duration(seconds: 4);

  @override
  State<CartUndoBar> createState() => _CartUndoBarState();
}

class _CartUndoBarState extends State<CartUndoBar>
    with SingleTickerProviderStateMixin {
  // Made in initState (not lazily), so dispose never creates it late
  late final AnimationController _countdown;

  @override
  void initState() {
    super.initState();
    _countdown =
        AnimationController(vsync: this, duration: CartUndoBar.duration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              Cart.instance.lastRemoved.value = null; // too late to undo
            }
          });
    Cart.instance.lastRemoved.addListener(_changed);
  }

  @override
  void dispose() {
    Cart.instance.lastRemoved.removeListener(_changed);
    // Leaving the cart ends the chance to undo
    Cart.instance.lastRemoved.value = null;
    _countdown.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (Cart.instance.lastRemoved.value != null) {
      _countdown.forward(from: 0); // a new removal restarts the 4 seconds
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final removed = Cart.instance.lastRemoved.value;
    return AnimatedSlide(
      offset: removed == null ? const Offset(0, 1.5) : Offset.zero,
      duration: Motion.off(context) ? Duration.zero : AppDuration.medium,
      curve: removed == null ? Curves.easeIn : Motion.spring,
      child: removed == null
          ? const SizedBox(height: 56)
          : Container(
              margin: const EdgeInsets.all(AppSpacing.sm),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xxs,
                AppSpacing.xxs,
                AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.glassEdge),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowStrong, blurRadius: 20),
                ],
              ),
              child: Row(
                children: [
                  // The time left to undo, running down
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: AnimatedBuilder(
                      animation: _countdown,
                      builder: (context, _) => CircularProgressIndicator(
                        value: 1 - _countdown.value,
                        strokeWidth: 2.5,
                        color: AppColors.accent,
                        backgroundColor: AppColors.line,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      trf(
                        'បានដក ${removed.$1.phone.name}',
                        'Removed ${removed.$1.phone.name}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.text),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Haptics.tap();
                      _countdown.stop();
                      Cart.instance.undoRemove();
                    },
                    icon: const Icon(Icons.undo_rounded),
                    label: Text(trf('មិនធ្វើវិញ', 'Undo')),
                  ),
                ],
              ),
            ),
    );
  }
}
