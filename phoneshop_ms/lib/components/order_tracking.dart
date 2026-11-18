import 'package:flutter/material.dart';
import '../data/models/order.dart';
import 'common.dart';
import '../hooks/language.dart';
import 'courier_logo.dart';
import 'motion.dart';
import '../theme/app_theme.dart';

String _time(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
}

// ① Order received → ② Confirmed → ③ Shipping → ④ Delivered, with the current stage lit up
class DeliveryProgress extends StatelessWidget {
  final String status;

  const DeliveryProgress({super.key, required this.status});

  // A getter, so the labels follow the chosen language
  static List<(String, String, IconData)> get _stages => [
    ('pending', tr('ទទួល Order'), Icons.receipt_long),
    ('confirmed', tr('រៀបចំឥវ៉ាន់'), Icons.inventory_2),
    ('shipping', tr('កំពុងដឹក'), Icons.local_shipping),
    ('delivered', tr('បានទទួល'), Icons.home),
  ];

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return Card(
        color: AppColors.red.withValues(alpha: 0.12),
        child: ListTile(
          leading: Icon(Icons.cancel, color: Colors.red),
          title: Text(
            tr('Order នេះត្រូវបានបោះបង់'),
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final current = _stages.indexWhere((s) => s.$1 == status);
    // The progress runs along the line once, lighting each stage as it arrives
    // (shown straight away in tests and when animations are off)
    if (!Motion.loops(context)) {
      return _stagesRow(context, current, current + 1.0);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(status),
      tween: Tween(begin: 0, end: current + 1.0),
      duration: Duration(milliseconds: 350 * (current + 1) + 300),
      curve: Curves.easeInOutCubic,
      builder: (context, progress, _) => _stagesRow(context, current, progress),
    );
  }

  // [progress] counts stages: 2.5 = the first two lit and the line halfway
  // to the third
  Widget _stagesRow(BuildContext context, int current, double progress) {
    final done = AppColors.accent;
    final todo = AppColors.line;
    // Half a joining line on each side of a circle (none outside the first
    // and last), filled as far as the progress has come
    Widget line(double fill, bool show) => Expanded(
      child: Container(
        height: 3,
        alignment: Alignment.centerLeft,
        color: show ? todo : Colors.transparent,
        child: show
            ? FractionallySizedBox(
                widthFactor: fill.clamp(0.0, 1.0),
                child: Container(color: done),
              )
            : null,
      ),
    );
    // Each stage gets a quarter of the width, so its name has room and never
    // breaks in the middle of a word ("Packin / g")
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _stages.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    // Left half fills on the way into stage i
                    line((progress - i) * 2, i > 0 && i <= current),
                    _stageDot(i, current, progress, done, todo),
                    // Right half fills on the way out towards stage i + 1
                    line((progress - i - 0.5) * 2, i < _stages.length - 1),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    _stages[i].$2,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: i == current
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: i <= current ? AppColors.text : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // A stage's circle: pops in blue when the progress reaches it; the current
  // stage keeps breathing to show "this is where it is now"
  Widget _stageDot(
    int i,
    int current,
    double progress,
    Color done,
    Color todo,
  ) {
    final lit = i <= current && progress >= i + 0.4;
    final pop = lit ? (progress - i - 0.4).clamp(0.0, 0.3) / 0.3 : 0.0;
    final dot = Transform.scale(
      scale: lit ? 0.85 + 0.15 * Curves.easeOutBack.transform(pop) : 1,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: lit ? done : todo,
        child: Icon(
          _stages[i].$3,
          size: 20,
          color: lit ? Colors.white : AppColors.muted,
        ),
      ),
    );
    return i == current && lit && progress >= current + 1
        ? Pulse(child: dot)
        : dot;
  }
}

class TrackingTimeline extends StatelessWidget {
  final List<TrackingStep> steps;
  final ValueChanged<TrackingStep>?
  onEdit; // admin only: shows a pencil on each step

  const TrackingTimeline({super.key, required this.steps, this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Text(
          tr('មិនទាន់មានព័ត៌មានតាមដាននៅឡើយ'),
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dot and the line joining it to the next (older) step
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xxs),
                      Icon(
                        i == 0 ? Icons.radio_button_checked : Icons.circle,
                        size: i == 0 ? 18 : 10,
                        color: i == 0
                            ? statusColor(steps[i].status)
                            : Colors.grey,
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusBadge(
                              status: steps[i].status,
                              label:
                                  orderStatusLabels[steps[i].status] ??
                                  steps[i].status,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                _time(steps[i].time),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                            if (onEdit != null)
                              IconButton(
                                tooltip: 'កែទីតាំង',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => onEdit!(steps[i]),
                              ),
                          ],
                        ),
                        if (steps[i].location.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  steps[i].location,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (steps[i].note.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(steps[i].note),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Delivery company and parcel number, when the admin has entered them
class CourierInfo extends StatelessWidget {
  final Order order;

  const CourierInfo({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.courier.isEmpty && order.trackingNumber.isEmpty) {
      return const SizedBox.shrink();
    }
    // White card with a soft shadow, the same as the other cards on the tracking page
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        leading: CourierLogo(name: order.courier),
        title: Text(
          order.courier.isEmpty ? tr('ក្រុមហ៊ុនដឹកជញ្ជូន') : order.courier,
        ),
        subtitle: order.trackingNumber.isEmpty
            ? null
            : SelectableText(
                trf(
                  'លេខតាមដាន: ${order.trackingNumber}',
                  'Tracking no.: ${order.trackingNumber}',
                ),
              ),
      ),
    );
  }
}
