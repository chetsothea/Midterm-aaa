import 'package:flutter/material.dart';
import '../data/policy_text.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';

// Privacy policy and terms of use, in the app's language
class PrivacyScreen extends StatelessWidget {
  final bool terms; // open on the Terms tab

  const PrivacyScreen({super.key, this.terms = false});

  Widget _page(List<PolicySection> sections) {
    final km = !AppLanguage.instance.isEnglish;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          km ? 'ធ្វើបច្ចុប្បន្នភាព: $policyUpdated' : 'Updated: $policyUpdated',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        for (final s in sections) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            km ? s.km : s.en,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          for (final p in s.points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: TextStyle(color: AppColors.accent, height: 1.5),
                  ),
                  Expanded(
                    child: Text(
                      km ? p.$1 : p.$2,
                      style: TextStyle(color: AppColors.text, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: terms ? 1 : 0,
      child: Scaffold(
        backgroundColor: AppColors.page,
        appBar: AppBar(
          title: Text(trf('ឯកជនភាព និងលក្ខខណ្ឌ', 'Privacy & terms')),
          bottom: TabBar(
            tabs: [
              Tab(text: trf('ឯកជនភាព', 'Privacy')),
              Tab(text: trf('លក្ខខណ្ឌ', 'Terms')),
            ],
          ),
        ),
        body: TabBarView(
          children: [_page(privacySections), _page(termsSections)],
        ),
      ),
    );
  }
}
