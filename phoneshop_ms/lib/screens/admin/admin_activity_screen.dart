import 'package:flutter/material.dart';
import '../../components/store_app_bar.dart';
import '../../components/ux.dart';
import '../../data/api_service.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

// Admin: every change the team made (orders, phones, codes, refunds ...),
// who made it and when. [userId] / [name] narrow it to one staff member.
class AdminActivityScreen extends StatefulWidget {
  final int? userId;
  final String? name;

  const AdminActivityScreen({super.key, this.userId, this.name});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      _items = await ApiService.fetchActivity(userId: widget.userId);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  static String _when(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  // "status: confirmed · courier: J&T" from the fields that were sent
  static String _details(Map? d) {
    if (d == null || d.isEmpty) return '';
    return d.entries
        .where((e) => e.value != null && '${e.value}'.isNotEmpty)
        .map(
          (e) =>
              '${e.key}: ${e.value is Map || e.value is List ? '…' : e.value}',
        )
        .join(' · ');
  }

  Widget _row(Map<String, dynamic> a) {
    final staff = a['role'] == 'staff';
    final time = DateTime.tryParse('${a['created_at']}')?.toLocal();
    final details = _details(a['details'] as Map?);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (staff ? AppColors.accent : AppColors.amber)
            .withValues(alpha: 0.15),
        child: Icon(
          staff ? Icons.badge_outlined : Icons.admin_panel_settings_outlined,
          color: staff ? AppColors.accent : AppColors.amber,
        ),
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${a['user_name']} ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: '${a['action']}'),
            if ('${a['subject'] ?? ''}'.isNotEmpty)
              TextSpan(
                text: ' · ${a['subject']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
          ],
        ),
        style: TextStyle(color: AppColors.text),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details.isNotEmpty)
            Text(
              details,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.text2, fontSize: 12),
            ),
          if (time != null)
            Text(
              _when(time),
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(
        title: Text(
          widget.name == null
              ? trf('កំណត់ត្រាសកម្មភាព', 'Activity log')
              : trf('សកម្មភាព · ${widget.name}', 'Activity · ${widget.name}'),
        ),
      ),
      body: _loading
          ? const ListSkeleton(rows: 5)
          : _error != null
          ? StatusView(
              icon: Icons.wifi_off_rounded,
              error: true,
              title: trf('មិនអាចភ្ជាប់ទៅហាងបានទេ', "Can't reach the shop"),
              message: _error!,
              actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
              onAction: _load,
            )
          : _items.isEmpty
          ? StatusView(
              icon: Icons.history,
              title: trf('មិនទាន់មានសកម្មភាព', 'Nothing yet'),
              message: trf(
                'ការកែប្រែរបស់ Admin និងបុគ្គលិកនឹងបង្ហាញនៅទីនេះ',
                'Changes by the admin and staff show up here',
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, indent: 72, color: AppColors.line),
                itemBuilder: (_, i) => _row(_items[i]),
              ),
            ),
    );
  }
}
