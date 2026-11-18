import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Each chart here is one series, so it has one colour and its title names it (no legend).
// Text stays in text colours; only the bars carry the chart colour.
const _barColor = Color(0xFF2A78D6);
const _mutedText = Color(0xFF52514E);
const _maxBarThickness = 24.0;

// $950, $1.5k: short enough to sit on top of a narrow column
String compactMoney(double value) {
  if (value < 1000) return '\$${value.toStringAsFixed(0)}';
  final thousands = (value / 1000).toStringAsFixed(1).replaceFirst('.0', '');
  return '\$${thousands}k';
}

class ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const ChartCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Text('មិនទាន់មានទិន្នន័យ', style: TextStyle(color: _mutedText)),
      ),
    );
  }
}

// Revenue per day. Only the best day is labelled; tap or hover any column for its amount.
class RevenueColumns extends StatelessWidget {
  final List<({DateTime date, double total})> days;

  const RevenueColumns({super.key, required this.days});

  static const _plotHeight = 130.0;

  @override
  Widget build(BuildContext context) {
    final highest = days.fold<double>(
      0,
      (best, day) => day.total > best ? day.total : best,
    );
    if (highest == 0) return const _NoData();

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final day in days)
              Expanded(
                child: Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  message:
                      '${_date(day.date)}: \$${day.total.toStringAsFixed(2)}',
                  child: SizedBox(
                    // The whole column slot is the tap target, not just the bar
                    height: _plotHeight + 28,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (day.total == highest)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              compactMoney(day.total),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Container(
                          width: _maxBarThickness,
                          // Very small days stay visible
                          height: day.total == 0
                              ? 0
                              : (day.total / highest * _plotHeight).clamp(
                                  3,
                                  _plotHeight,
                                ),
                          decoration: const BoxDecoration(
                            color: _barColor,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Divider(height: 1, color: Color(0xFFBDBDBD)),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _date(day.date),
                    maxLines: 1,
                    style: const TextStyle(fontSize: 11, color: _mutedText),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _date(DateTime date) => '${date.day}/${date.month}';
}

// Labelled bars with the value at each tip, e.g. orders per status or units per phone
class LabeledBars extends StatelessWidget {
  final List<({String label, int value})> items;

  const LabeledBars({super.key, required this.items});

  static const _thickness = 14.0;

  @override
  Widget build(BuildContext context) {
    final highest = items.fold<int>(
      0,
      (best, item) => item.value > best ? item.value : best,
    );
    if (highest == 0) return const _NoData();

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _mutedText),
                  ),
                ),
                // The bar shares the row with the empty part, in proportion to its value
                if (item.value > 0)
                  Expanded(
                    flex: item.value,
                    child: Container(
                      height: _thickness,
                      decoration: const BoxDecoration(
                        color: _barColor,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  '${item.value}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.value < highest) Spacer(flex: highest - item.value),
              ],
            ),
          ),
      ],
    );
  }
}
