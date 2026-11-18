import 'package:flutter/material.dart';
import '../data/models/phone.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'ux.dart';

// What the customer narrowed the phone grid to: some brands, a price range
// and some storage sizes. Empty sets / null bounds mean "any".
class ProductFilter {
  final Set<String> brands;
  final double? minPrice;
  final double? maxPrice;
  final Set<String> storages;

  const ProductFilter({
    this.brands = const {},
    this.minPrice,
    this.maxPrice,
    this.storages = const {},
  });

  static const none = ProductFilter();

  bool get isActive =>
      brands.isNotEmpty ||
      storages.isNotEmpty ||
      minPrice != null ||
      maxPrice != null;

  // How many kinds of limit are set, for the badge on the filter button
  int get count =>
      (brands.isNotEmpty ? 1 : 0) +
      (storages.isNotEmpty ? 1 : 0) +
      (minPrice != null || maxPrice != null ? 1 : 0);

  // Every size a phone comes in (its options, or its single size)
  static Set<String> storagesOf(Phone phone) => {
    for (final o in phone.storageOptions) o.storage,
    if (phone.storageOptions.isEmpty && phone.storage.isNotEmpty) phone.storage,
  };

  bool matches(Phone phone) {
    if (brands.isNotEmpty && !brands.contains(phone.brand)) return false;
    if (minPrice != null && phone.price < minPrice!) return false;
    if (maxPrice != null && phone.price > maxPrice!) return false;
    if (storages.isNotEmpty &&
        storagesOf(phone).intersection(storages).isEmpty) {
      return false;
    }
    return true;
  }

  List<Phone> apply(List<Phone> phones) =>
      isActive ? phones.where(matches).toList() : phones;
}

// The tune button with a small blue number when a filter is on
class FilterButton extends StatelessWidget {
  final ProductFilter filter;
  final VoidCallback onPressed;

  const FilterButton({
    super.key,
    required this.filter,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: trf('តម្រង', 'Filter'),
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: filter.isActive,
        label: Text('${filter.count}'),
        child: Icon(
          Icons.tune_rounded,
          color: filter.isActive ? AppColors.accent : AppColors.textSoft,
        ),
      ),
    );
  }
}

// Bottom sheet to pick brands, a price range and storage sizes, built from
// the phones on the page. Resolves to the new filter, or null when dismissed.
Future<ProductFilter?> showProductFilter(
  BuildContext context, {
  required List<Phone> phones,
  required ProductFilter current,
}) {
  return showModalBottomSheet<ProductFilter>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FilterSheet(phones: phones, current: current),
  );
}

class _FilterSheet extends StatefulWidget {
  final List<Phone> phones;
  final ProductFilter current;

  const _FilterSheet({required this.phones, required this.current});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Set<String> _brands = {...widget.current.brands};
  late final Set<String> _storages = {...widget.current.storages};
  late double _lowest = 0, _highest = 0;
  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    final prices = widget.phones.map((p) => p.price).toList();
    _lowest = prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b);
    _highest = prices.isEmpty ? 0 : prices.reduce((a, b) => a > b ? a : b);
    if (_highest <= _lowest) _highest = _lowest + 1;
    _range = RangeValues(
      (widget.current.minPrice ?? _lowest).clamp(_lowest, _highest),
      (widget.current.maxPrice ?? _highest).clamp(_lowest, _highest),
    );
  }

  List<String> get _allBrands =>
      widget.phones
          .map((p) => p.brand)
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  // Sizes in a sensible order: 64GB, 128GB, 256GB, 512GB, 1TB
  List<String> get _allStorages {
    int size(String s) {
      final n = int.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '') ?? 0;
      return s.toUpperCase().contains('TB') ? n * 1024 : n;
    }

    return {
      for (final p in widget.phones) ...ProductFilter.storagesOf(p),
    }.toList()..sort((a, b) => size(a).compareTo(size(b)));
  }

  ProductFilter get _result => ProductFilter(
    brands: _brands,
    storages: _storages,
    minPrice: _range.start > _lowest ? _range.start : null,
    maxPrice: _range.end < _highest ? _range.end : null,
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      ),
    ),
  );

  Widget _chips(List<String> options, Set<String> picked) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in options)
        FilterChip(
          label: Text(option),
          selected: picked.contains(option),
          showCheckmark: false,
          selectedColor: AppColors.accent,
          labelStyle: TextStyle(
            color: picked.contains(option) ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (on) {
            Haptics.tap();
            setState(() => on ? picked.add(option) : picked.remove(option));
          },
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final matches = _result.apply(widget.phones).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trf('តម្រង', 'Filter'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _brands.clear();
                    _storages.clear();
                    _range = RangeValues(_lowest, _highest);
                  }),
                  child: Text(trf('សម្អាត', 'Reset')),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_allBrands.isNotEmpty) ...[
                      _heading(trf('ម៉ាក', 'Brand')),
                      _chips(_allBrands, _brands),
                    ],
                    _heading(trf('តម្លៃ', 'Price')),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          money(_range.start),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        Text(
                          money(_range.end),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _range,
                      min: _lowest,
                      max: _highest,
                      activeColor: AppColors.accent,
                      inactiveColor: AppColors.line,
                      onChanged: (v) => setState(() => _range = v),
                    ),
                    if (_allStorages.isNotEmpty) ...[
                      _heading(trf('ទំហំផ្ទុក', 'Storage')),
                      _chips(_allStorages, _storages),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _result),
              child: Text(
                trf('បង្ហាញ $matches ទូរស័ព្ទ', 'Show $matches phones'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
