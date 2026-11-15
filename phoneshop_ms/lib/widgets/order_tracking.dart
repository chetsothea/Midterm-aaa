import 'package:flutter/material.dart';
import '../models/order.dart';
import 'common.dart';
import '../services/language.dart';
import 'courier_logo.dart';

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
        color: Colors.red.shade50,
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
    final done = Theme.of(context).colorScheme.primary;
    final todo = Colors.grey.shade300;
    // Half a joining line on each side of a circle (none outside the first and last)
    Widget line(bool on, bool show) => Expanded(
      child: Container(
        height: 3,
        color: show ? (on ? done : todo) : Colors.transparent,
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
                    line(i <= current, i > 0),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: i <= current ? done : todo,
                      child: Icon(
                        _stages[i].$3,
                        size: 20,
                        color: i <= current ? Colors.white : Colors.grey,
                      ),
                    ),
                    line(i < current, i < _stages.length - 1),
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
                      color: i <= current ? null : Colors.grey,
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

// Every recorded step, newest at the top: time, status, where, and the note
class TrackingTimeline extends StatelessWidget {
  final List<TrackingStep> steps;
  final ValueChanged<TrackingStep>?
  onEdit; // admin only: shows a pencil on each step

  const TrackingTimeline({super.key, required this.steps, this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          tr('មិនទាន់មានព័ត៌មានតាមដាននៅឡើយ'),
          style: TextStyle(color: Colors.black54),
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
                      const SizedBox(height: 4),
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
                const SizedBox(width: 8),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _time(steps[i].time),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
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
                          const SizedBox(height: 4),
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
