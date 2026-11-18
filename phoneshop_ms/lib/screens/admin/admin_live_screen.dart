import 'package:flutter/material.dart';
import '../../data/models/live.dart';
import '../../data/models/phone.dart';
import '../../data/api_service.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';
import '../../components/common.dart';
import '../../components/effects.dart';
import '../../components/store_app_bar.dart';
import '../../components/ux.dart';
import '../live_shopping_screen.dart';

// Admin: run a live shopping session. Start a YouTube Live on the shop's
// channel, paste its link here, pick the phones to pin under the stream, and
// press Start. Customers then see "LIVE" on the store's home page.
class AdminLiveScreen extends StatefulWidget {
  const AdminLiveScreen({super.key});

  @override
  State<AdminLiveScreen> createState() => _AdminLiveScreenState();
}

class _AdminLiveScreenState extends State<AdminLiveScreen> {
  final _link = TextEditingController();
  final _title = TextEditingController();
  List<Phone> _phones = [];
  final List<int> _pinned = [];
  LiveSession _session = LiveSession.off;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _link.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.fetchLive(),
        ApiService.fetchPhones(),
      ]);
      if (!mounted) return;
      final session = results[0] as LiveSession;
      setState(() {
        _session = session;
        _phones = results[1] as List<Phone>;
        _link.text = session.youtubeId.isEmpty
            ? ''
            : 'https://youtu.be/${session.youtubeId}';
        _title.text = session.title;
        _pinned
          ..clear()
          ..addAll(session.products.map((p) => p.id));
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showMessage(context, '$e', error: true);
      }
    }
  }

  Future<void> _save({bool end = false}) async {
    if (!end && _link.text.trim().isEmpty) {
      showMessage(
        context,
        trf('សូមដាក់ Link YouTube Live', 'Paste the YouTube Live link'),
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final session = await ApiService.updateLive(
        youtube: end ? '' : _link.text.trim(),
        title: _title.text.trim(),
        productIds: _pinned,
      );
      if (!mounted) return;
      Haptics.success();
      setState(() {
        _session = session;
        if (end) _link.clear();
      });
      showMessage(
        context,
        end
            ? trf('បានបញ្ចប់ការផ្សាយ', 'Live ended')
            : trf('ការផ្សាយផ្ទាល់កំពុងដំណើរការ', 'You are live'),
      );
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: storeAppBar(
        title: Text(trf('ផ្សាយផ្ទាល់', 'Live shopping')),
        actions: [
          if (_session.isLive)
            const Center(
              child: LiveDot(color: Color(0xFFFF453A), textColor: Colors.white),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: _loading
          ? const ListSkeleton(rows: 3)
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  trf(
                    '1. ចាប់ផ្តើម Live នៅលើ YouTube\n2. ដាក់ Link នៅទីនេះ ហើយជ្រើសទូរស័ព្ទ\n3. ចុច ចាប់ផ្តើម',
                    '1. Start a live on YouTube\n2. Paste its link here and pick the phones\n3. Press Start',
                  ),
                  style: TextStyle(color: AppColors.textSoft, height: 1.6),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'YouTube Live link',
                    hintText: 'https://youtube.com/live/...',
                    prefixIcon: Icon(Icons.smart_display_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _title,
                  maxLength: 255,
                  decoration: InputDecoration(
                    labelText: trf('ចំណងជើង', 'Title'),
                    hintText: trf(
                      'ឧ. iPhone 17 មកដល់ហើយ',
                      'e.g. iPhone 17 is here',
                    ),
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  trf(
                    'ទូរស័ព្ទដែលបង្ហាញក្រោមវីដេអូ (${_pinned.length})',
                    'Phones pinned under the video (${_pinned.length})',
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final phone in _phones)
                  CheckboxListTile(
                    value: _pinned.contains(phone.id),
                    onChanged: (on) => setState(
                      () => on == true
                          ? _pinned.add(phone.id)
                          : _pinned.remove(phone.id),
                    ),
                    secondary: PhoneImage(url: phone.imageUrl, size: 40),
                    title: Text(phone.name),
                    subtitle: Text(money(phone.price)),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(),
                  icon: const Icon(Icons.podcasts_rounded),
                  label: Text(
                    _session.isLive
                        ? trf('រក្សាទុក', 'Update live')
                        : trf('ចាប់ផ្តើមផ្សាយ', 'Start live'),
                  ),
                ),
                if (_session.isLive) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveShoppingScreen(session: _session),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(trf('មើលដូចអតិថិជន', 'Watch as a customer')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _save(end: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(trf('បញ្ចប់ការផ្សាយ', 'End live')),
                  ),
                ],
              ],
            ),
    );
  }
}
