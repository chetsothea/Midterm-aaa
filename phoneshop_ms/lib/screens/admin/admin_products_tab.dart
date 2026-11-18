import 'package:flutter/material.dart';
import '../../data/models/phone.dart';
import '../../data/api_service.dart';
import '../../components/brand_row.dart';
import '../../components/common.dart';
import '../../components/product_card.dart';
import 'product_form_screen.dart';
import '../../components/ux.dart';
import '../../components/shop_refresh.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

// Chip that shows only phones running out (or out) of stock
const _lowStockFilter = '__low__';

class AdminProductsTab extends StatefulWidget {
  const AdminProductsTab({super.key});

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  late Future<List<Phone>> _phones = ApiService.fetchPhones();

  // Brand chip and search box: both work on the list already loaded, so they're instant
  String _filter = '';
  String _search = '';

  Future<void> _refresh() async {
    // Block body: an arrow would return the Future, which setState() rejects
    setState(() {
      _phones = ApiService.fetchPhones();
    });
    await _phones;
  }

  void _openForm([Phone? phone]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(phone: phone)),
    );
    if (saved == true) _refresh();
  }

  void _delete(Phone phone) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('លុប ${phone.name}?'),
        content: const Text('មិនអាចត្រឡប់វិញបានទេ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ទេ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('លុប'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteProduct(phone.id);
      if (mounted) showMessage(context, 'បានលុប ${phone.name}');
      _refresh();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  bool _isLow(Phone phone) => phone.stock <= ApiService.lowStockThreshold;

  List<Phone> _shown(List<Phone> phones) {
    final query = _search.trim().toLowerCase();
    return phones.where((p) {
      if (_filter == _lowStockFilter && !_isLow(p)) return false;
      final brandChip = _filter.isNotEmpty && _filter != _lowStockFilter;
      if (brandChip && p.brand != _filter) return false;
      return query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.brand.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF3D7BFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('បន្ថែមទូរស័ព្ទ'),
      ),
      body: FutureBuilder<List<Phone>>(
        future: _phones,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          } else if (snapshot.hasError) {
            return StatusView(
              icon: Icons.wifi_off_rounded,
              error: true,
              title: trf('មិនអាចភ្ជាប់ទៅហាងបានទេ', "Can't reach the shop"),
              message: '${snapshot.error}',
              actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
              onAction: _refresh,
            );
          } else if (snapshot.data!.isEmpty) {
            return const Center(child: Text('មិនទាន់មានទូរស័ព្ទ'));
          }
          final all = snapshot.data!;
          final shown = _shown(all);
          return Column(
            children: [
              _toolbar(all),
              Expanded(
                child: ShopRefresh(
                  onRefresh: _refresh,
                  child: shown.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(
                              Icons.search_off,
                              size: 56,
                              color: Colors.black26,
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Center(child: Text('រកមិនឃើញទូរស័ព្ទ')),
                          ],
                        )
                      : ListView(
                          // Room for the add button at the bottom
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                          children: [
                            for (final phone in shown) _phoneCard(phone),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Search box, then "all", one chip per brand, and the phones running out
  Widget _toolbar(List<Phone> all) {
    final brands = <String, int>{};
    for (final phone in all) {
      brands[phone.brand] = (brands[phone.brand] ?? 0) + 1;
    }
    final low = all.where(_isLow).length;
    return Container(
      color: AppColors.glass,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'ស្វែងរកឈ្មោះទូរស័ព្ទ ឬម៉ាក',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.page,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('', 'ទាំងអស់', all.length, AppColors.text),
                if (low > 0)
                  _chip(
                    _lowStockFilter,
                    'ស្តុកជិតអស់',
                    low,
                    const Color(0xFFFF453A),
                  ),
                for (final entry in brands.entries)
                  _chip(
                    entry.key,
                    entry.key,
                    entry.value,
                    brandColor(entry.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, String label, int count, Color color) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selected: selected,
        selectedColor: color,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: selected ? color : Colors.black12),
        label: Text(
          '$label  $count',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text2,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _phoneCard(Phone phone) {
    final out = phone.stock <= 0;
    final low = _isLow(phone);
    final stockColor = out
        ? const Color(0xFFFF453A)
        : low
        ? const Color(0xFF2F62D9)
        : const Color(0xFF30D158);
    final brand = brandColor(phone.brand);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
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
        // Stock at a glance: green plenty, orange running out, red none left
        border: Border(left: BorderSide(color: stockColor, width: 5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openForm(phone),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // The picture on the same soft colours as the store cards
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.surfaceHigh, AppColors.tileLow],
                        ),
                      ),
                      child: PhoneImage(url: phone.imageUrl, size: 64),
                    ),
                    if (phone.hasDiscount)
                      Positioned(
                        top: -4,
                        left: -4,
                        child: DiscountBadge(
                          percent: phone.discountPercent,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phone.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(phone.price).replaceFirst('.00', ''),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: phone.hasDiscount
                                  ? const Color(0xFFFF453A)
                                  : AppColors.text,
                            ),
                          ),
                          if (phone.hasDiscount) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                money(phone.oldPrice!).replaceFirst('.00', ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _pill(phone.brand, brand),
                          _pill(phone.condition, AppColors.textSoft),
                          _pill(
                            out ? 'អស់ស្តុក' : 'ស្តុក: ${phone.stock}',
                            stockColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'កែ',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF2563EB),
                      ),
                      onPressed: () => _openForm(phone),
                    ),
                    IconButton(
                      tooltip: 'លុប',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _delete(phone),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
