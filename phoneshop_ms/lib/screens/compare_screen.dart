import 'package:flutter/material.dart';
import '../data/models/phone.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';
import '../components/common.dart';
import '../components/motion.dart';
import '../components/store_app_bar.dart';
import '../components/ux.dart';

// Two phones side by side: pick each one, then every spec gets a row. Numbers
// (price, RAM, storage, stock) also get a pair of bars that grow from zero, the
// longer bar showing which phone has more.
class CompareScreen extends StatefulWidget {
  final List<Phone> phones;
  final Phone? first; // e.g. the phone whose detail page opened this

  const CompareScreen({super.key, required this.phones, this.first});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late Phone? _left = widget.first ?? widget.phones.firstOrNull;
  late Phone? _right = widget.phones
      .where((p) => p.id != _left?.id)
      .firstOrNull;

  // "8GB" -> 8, "1TB" -> 1024
  static double _gb(String text) {
    final n = double.tryParse(
      RegExp(r'[\d.]+').firstMatch(text)?.group(0) ?? '',
    );
    if (n == null) return 0;
    return text.toUpperCase().contains('TB') ? n * 1024 : n;
  }

  static String _biggestStorage(Phone p) {
    final sizes = [
      for (final o in p.storageOptions) o.storage,
      if (p.storage.isNotEmpty) p.storage,
    ];
    if (sizes.isEmpty) return '';
    sizes.sort((a, b) => _gb(b).compareTo(_gb(a)));
    return sizes.first;
  }

  Future<void> _pick(bool left) async {
    final picked = await showModalBottomSheet<Phone>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  trf('ជ្រើសទូរស័ព្ទ', 'Pick a phone'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              for (final phone in widget.phones)
                ListTile(
                  leading: PhoneImage(url: phone.imageUrl, size: 44),
                  title: Text(phone.name),
                  subtitle: Text('${phone.brand} · ${money(phone.price)}'),
                  selected: phone.id == (left ? _left : _right)?.id,
                  selectedColor: AppColors.accent,
                  onTap: () => Navigator.pop(context, phone),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    Haptics.tap();
    setState(() => left ? _left = picked : _right = picked);
  }

  Widget _slot(Phone? phone, bool left) {
    return Expanded(
      child: PressScale(
        child: GestureDetector(
          onTap: () => _pick(left),
          child: AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: a, child: child),
            ),
            child: Container(
              key: ValueKey(phone?.id),
              height: 200,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: glassDecoration(),
              child: Column(
                children: [
                  Expanded(
                    child: phone == null
                        ? Icon(
                            Icons.add_circle_outline_rounded,
                            size: 48,
                            color: AppColors.muted,
                          )
                        : Floating(
                            height: 5,
                            child: PhoneImage(url: phone.imageUrl, size: 110),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    phone?.name ?? trf('ជ្រើសទូរស័ព្ទ', 'Pick a phone'),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.swap_horiz_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        trf('ប្តូរ', 'Change'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
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

  // One spec: the label, both values, and (for numbers) two growing bars.
  // [lowerIsBetter] for the price, where the cheaper phone gets the blue bar.
  Widget _row(
    String label,
    String a,
    String b, {
    double? numA,
    double? numB,
    bool lowerIsBetter = false,
  }) {
    final hasBars = numA != null && numB != null && (numA > 0 || numB > 0);
    final most = hasBars ? (numA > numB ? numA : numB) : 1.0;
    bool wins(double mine, double other) =>
        lowerIsBetter ? mine < other : mine > other;

    Widget bar(double value, double other, Alignment from) {
      final win = wins(value, other);
      return TweenAnimationBuilder<double>(
        key: ValueKey('$label-$value-$other'),
        tween: Tween(begin: 0, end: value / most),
        duration: Motion.off(context) ? Duration.zero : Motion.slow * 1.6,
        curve: Curves.easeOutCubic,
        builder: (context, f, _) => Container(
          height: 8,
          alignment: from,
          decoration: BoxDecoration(
            color: AppColors.line,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: f.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: win ? AppColors.accent : AppColors.muted,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
    }

    TextStyle value(bool win) => TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: win ? AppColors.accent : AppColors.text,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: glassDecoration(radius: 18, shadow: false),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  a.isEmpty ? '—' : a,
                  style: value(hasBars && wins(numA, numB)),
                ),
              ),
              Expanded(
                child: Text(
                  b.isEmpty ? '—' : b,
                  textAlign: TextAlign.right,
                  style: value(hasBars && wins(numB, numA)),
                ),
              ),
            ],
          ),
          if (hasBars) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                // Left phone's bar grows to the left, right phone's to the right
                Expanded(child: bar(numA, numB, Alignment.centerRight)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: bar(numB, numA, Alignment.centerLeft)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _left, b = _right;
    return Scaffold(
      appBar: storeAppBar(title: Text(trf('ប្រៀបធៀប', 'Compare'))),
      body: widget.phones.length < 2
          ? StatusView(
              icon: Icons.compare_arrows_rounded,
              title: trf(
                'ត្រូវការទូរស័ព្ទយ៉ាងតិច 2',
                'Needs at least 2 phones',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: Entrance.stagger([
                Row(
                  children: [
                    _slot(a, true),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accent,
                        child: const Text(
                          'VS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    _slot(b, false),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (a != null && b != null) ...[
                  _row(
                    trf('តម្លៃ', 'PRICE'),
                    money(a.price),
                    money(b.price),
                    numA: a.price,
                    numB: b.price,
                    lowerIsBetter: true,
                  ),
                  _row('RAM', a.ram, b.ram, numA: _gb(a.ram), numB: _gb(b.ram)),
                  _row(
                    trf('ទំហំផ្ទុក (ធំបំផុត)', 'STORAGE (MAX)'),
                    _biggestStorage(a),
                    _biggestStorage(b),
                    numA: _gb(_biggestStorage(a)),
                    numB: _gb(_biggestStorage(b)),
                  ),
                  _row(
                    trf('ស្តុក', 'IN STOCK'),
                    '${a.stock}',
                    '${b.stock}',
                    numA: a.stock.toDouble(),
                    numB: b.stock.toDouble(),
                  ),
                  _row(trf('ម៉ាក', 'BRAND'), a.brand, b.brand),
                  _row(
                    trf('ស្ថានភាព', 'CONDITION'),
                    tr(a.condition),
                    tr(b.condition),
                  ),
                  _row(
                    trf('ពណ៌', 'COLOURS'),
                    a.colors.join(', '),
                    b.colors.join(', '),
                  ),
                ],
              ]),
            ),
    );
  }
}
