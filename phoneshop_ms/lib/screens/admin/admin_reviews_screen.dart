import 'package:flutter/material.dart';
import '../../components/common.dart';
import '../../components/store_app_bar.dart';
import '../../components/ux.dart';
import '../../data/api_service.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

// Admin: every review, newest first. A rude or fake one can be hidden: it is
// kept (the writer still sees it) but no longer shown or counted in the stars.
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _reviews = await ApiService.fetchAllReviews();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(Map<String, dynamic> r) async {
    final id = r['id'] as int;
    setState(() => _busy.add(id));
    try {
      final hidden = await ApiService.setReviewHidden(id, r['hidden'] != true);
      if (!mounted) return;
      setState(() => r['hidden'] = hidden);
      showMessage(
        context,
        hidden ? trf('បានលាក់', 'Hidden') : trf('បានបង្ហាញវិញ', 'Shown again'),
      );
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Widget _card(Map<String, dynamic> r) {
    final hidden = r['hidden'] == true;
    final rating = (r['rating'] as num).toInt();
    final date = DateTime.tryParse('${r['created_at']}')?.toLocal();
    return Opacity(
      opacity: hidden ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: glassDecoration(radius: AppRadius.lg, shadow: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r['product']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Text(
                  '★' * rating + '☆' * (5 - rating),
                  style: const TextStyle(
                    color: AppColors.amber,
                    letterSpacing: 1,
                  ),
                  semanticsLabel: trf('$rating ផ្កាយ', '$rating stars'),
                ),
              ],
            ),
            Text(
              '${r['name']}${date == null ? '' : ' · ${date.day}/${date.month}/${date.year}'}',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if ('${r['comment']}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${r['comment']}',
                  style: TextStyle(color: AppColors.text),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: _busy.contains(r['id'])
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: () => _toggle(r),
                      style: TextButton.styleFrom(
                        foregroundColor: hidden
                            ? AppColors.accent
                            : AppColors.red,
                      ),
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      label: Text(
                        hidden
                            ? trf('បង្ហាញវិញ', 'Show again')
                            : trf('លាក់', 'Hide'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: Text(trf('ការវាយតម្លៃ', 'Reviews'))),
      body: _loading
          ? const ListSkeleton(rows: 3)
          : _error != null
          ? StatusView(
              icon: Icons.wifi_off_rounded,
              error: true,
              title: trf('មិនអាចភ្ជាប់ទៅហាងបានទេ', "Can't reach the shop"),
              message: _error!,
              actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
              onAction: _load,
            )
          : _reviews.isEmpty
          ? StatusView(
              icon: Icons.star_outline_rounded,
              title: trf('មិនទាន់មានការវាយតម្លៃ', 'No reviews yet'),
              message: trf(
                'អតិថិជនវាយតម្លៃបាន ក្រោយទទួលទូរស័ព្ទ',
                'Customers can review once their phone arrives',
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                children: [for (final r in _reviews) _card(r)],
              ),
            ),
    );
  }
}
