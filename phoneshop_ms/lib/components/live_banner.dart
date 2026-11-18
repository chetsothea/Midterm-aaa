import 'package:flutter/material.dart';
import '../data/models/live.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';
import 'effects.dart';
import 'motion.dart';
import 'ux.dart';

// The card at the very top of the store while the seller is live: the
// stream's thumbnail with a red LIVE badge and a play button that breathes,
// the title, and how many phones are pinned. Tap to join.
class LiveNowCard extends StatelessWidget {
  final LiveSession session;
  final VoidCallback onJoin;

  const LiveNowCard({super.key, required this.session, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.97,
      child: GestureDetector(
        onTap: () {
          Haptics.tap();
          onJoin();
        },
        child: Container(
          height: 112,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            color: AppColors.surface,
            border: Border.all(
              color: const Color(0xFFFF453A).withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF453A).withValues(alpha: 0.25),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // The stream's picture from YouTube, with a play button
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://img.youtube.com/vi/${session.youtubeId}/hqdefault.jpg',
                      fit: BoxFit.cover,
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Colors.black),
                    ),
                    const ColoredBox(color: Color(0x33000000)),
                    Center(
                      child: Pulse(
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF453A),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LiveDot(
                        color: Color(0xFFFF453A),
                        textColor: Color(0xFFFF453A),
                      ),
                      const SizedBox(height: 6),
                      Flexible(
                        child: Text(
                          session.title.isEmpty
                              ? trf('កំពុងផ្សាយផ្ទាល់ឥឡូវនេះ', 'Live now')
                              : session.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (session.products.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          trf(
                            '${session.products.length} ទូរស័ព្ទក្នុង Live',
                            '${session.products.length} phones in this live',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
