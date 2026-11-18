import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// "Are you sure?" box that pops in: a coloured icon, the question, the order code
// on its own line so it never breaks in the middle, and two clear answers.
// Returns true only when the customer taps the coloured button.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  String? code,
  String? message,
  required String cancelLabel,
  required String confirmLabel,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: AppColors.muted,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, _, _) => _ConfirmDialog(
      icon: icon,
      color: color,
      title: title,
      code: code,
      message: message,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
    ),
    // Grows in from a little smaller with a slight overshoot, and fades
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result == true;
}

class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? code;
  final String? message;
  final String cancelLabel;
  final String confirmLabel;

  const _ConfirmDialog({
    required this.icon,
    required this.color,
    required this.title,
    this.code,
    this.message,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The icon pops a moment after the box
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 34),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  if (code != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.page,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Text(
                        code!,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppColors.text3,
                        ),
                      ),
                    ),
                  ],
                  if (message != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: Text(cancelLabel, textAlign: TextAlign.center),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: Text(
                            confirmLabel,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
