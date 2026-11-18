import 'package:flutter/material.dart';
import '../hooks/language.dart';
import 'motion.dart';
import 'store_menu.dart';
import 'ux.dart';
import '../theme/app_theme.dart';

Color get _navy => AppColors.text;
const _orange = Color(0xFF3D7BFF);
const _red = Color(0xFFFF453A);

// An icon and tint for a category name (the admin names categories freely,
// so match on words; anything else gets a generic grid)
(IconData, Color) _lookFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('2nd') || n.contains('used') || n.contains('ជជុះ')) {
    return (Icons.autorenew_rounded, const Color(0xFF30D158));
  }
  if (n.contains('access') || n.contains('ear') || n.contains('head')) {
    return (Icons.headphones_rounded, const Color(0xFF7C3AED));
  }
  if (n.contains('tablet') || n.contains('ipad')) {
    return (Icons.tablet_mac_rounded, const Color(0xFF0891B2));
  }
  if (n.contains('watch')) {
    return (Icons.watch_rounded, const Color(0xFFDB2777));
  }
  if (n.contains('phone')) {
    return (Icons.smartphone_rounded, const Color(0xFF2563EB));
  }
  return (Icons.grid_view_rounded, const Color(0xFF3D7BFF));
}

// Rounded-square shortcuts under the banner, one per category from
// GET /api/menu, plus "Deals" when something is on sale. One tap filters the
// store, like picking it in the side menu.
class CategoryTiles extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final bool hasDeals;
  final ValueChanged<StoreFilter> onSelected;

  const CategoryTiles({
    super.key,
    required this.categories,
    required this.hasDeals,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      for (final category in categories)
        _Tile(
          label: category['name'] ?? '',
          look: _lookFor(category['name'] ?? ''),
          onTap: () => onSelected(
            StoreFilter(section: category['name'], categoryId: category['id']),
          ),
        ),
      if (hasDeals)
        _Tile(
          label: trf('បញ្ចុះតម្លៃ', 'Deals'),
          look: (Icons.local_offer_rounded, _red),
          hot: true,
          onTap: () => onSelected(StoreFilter.sale),
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => PopIn(index: i, child: tiles[i]),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final (IconData, Color) look;
  final bool hot; // the Deals tile glows orange-red
  final VoidCallback onTap;

  const _Tile({
    required this.label,
    required this.look,
    required this.onTap,
    this.hot = false,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = look;
    return PressScale(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Haptics.tap();
            onTap();
          },
          child: SizedBox(
            width: 76,
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: hot
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_orange, _red],
                          )
                        : null,
                    color: hot ? null : AppColors.glass, // glass
                    border: hot ? null : Border.all(color: AppColors.glassEdge),
                    boxShadow: [
                      BoxShadow(
                        color: (hot ? _red : _navy).withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: hot ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
