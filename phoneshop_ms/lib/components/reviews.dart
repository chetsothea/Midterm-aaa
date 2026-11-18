import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../data/models/phone.dart';
import '../data/models/review.dart';
import '../hooks/language.dart';
import '../theme/theme.dart';
import 'common.dart';
import 'motion.dart';
import 'ux.dart';

// Customer reviews: stars on the store cards, and on the detail page a
// summary (average, how many of each star), the reviews themselves and a
// "Write a review" for customers who received the phone.

const _starColor = Color(0xFFFFB800);

// Five stars, filled to [rating] (halves too)
class StarRow extends StatelessWidget {
  final double rating;
  final double size;

  const StarRow({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${rating.toStringAsFixed(1)} / 5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              rating >= i
                  ? Icons.star_rounded
                  : rating >= i - 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: size,
              color: rating >= i - 0.5 ? _starColor : AppColors.muted,
            ),
        ],
      ),
    );
  }
}

// "★ 4.5 (12)" on a store card; nothing while a phone has no reviews
class RatingChip extends StatelessWidget {
  final Phone phone;

  const RatingChip({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    if (phone.ratingCount == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 13, color: _starColor),
        const SizedBox(width: 2),
        Text(
          phone.ratingAverage.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        Text(
          ' (${phone.ratingCount})',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}

// The reviews block on the detail page, loading its own data
class ReviewsSection extends StatefulWidget {
  final Phone phone;

  const ReviewsSection({super.key, required this.phone});

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  late Future<ReviewSummary> _summary = ApiService.fetchReviews(
    widget.phone.id,
  );
  bool _showAll = false;

  void _reload() =>
      setState(() => _summary = ApiService.fetchReviews(widget.phone.id));

  Future<void> _write(ReviewSummary summary) async {
    final saved = await showWriteReview(
      context,
      phone: widget.phone,
      existing: summary.mine,
    );
    if (saved && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReviewSummary>(
      future: _summary,
      builder: (context, snapshot) {
        // Loading: three shimmering lines where the summary will be
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Shimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 28),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(height: 12),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 200, height: 12),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: AppColors.muted),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  trf('មិនអាចផ្ទុកការវាយតម្លៃបាន', "Couldn't load reviews"),
                  style: TextStyle(color: AppColors.textSoft),
                ),
              ),
              TextButton(
                onPressed: _reload,
                child: Text(trf('ព្យាយាមម្តងទៀត', 'Try again')),
              ),
            ],
          );
        }
        final summary = snapshot.data ?? ReviewSummary.empty;
        final shown = _showAll
            ? summary.reviews
            : summary.reviews.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summary.count == 0)
              // Empty: say so, and how reviews get here
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    const StarRow(rating: 0, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        trf(
                          'មិនទាន់មានការវាយតម្លៃ។ អ្នកដែលបានទទួលទូរស័ព្ទនេះ អាចវាយតម្លៃបាន។',
                          'No reviews yet. Customers who received this phone can review it.',
                        ),
                        style: TextStyle(
                          color: AppColors.textSoft,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              _summaryBlock(summary),
            for (final (i, review) in shown.indexed)
              Entrance(
                index: i,
                child: _ReviewTile(review: review),
              ),
            if (summary.reviews.length > 3 && !_showAll)
              TextButton(
                onPressed: () => setState(() => _showAll = true),
                child: Text(
                  trf(
                    'មើលទាំង ${summary.reviews.length}',
                    'See all ${summary.reviews.length}',
                  ),
                ),
              ),
            if (summary.canReview) ...[
              const SizedBox(height: AppSpacing.xs),
              PressScale(
                child: OutlinedButton.icon(
                  onPressed: () => _write(summary),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(
                    summary.mine == null
                        ? trf('សរសេរការវាយតម្លៃ', 'Write a review')
                        : trf('កែការវាយតម្លៃរបស់ខ្ញុំ', 'Edit my review'),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // Big average, its stars and count, and a bar per star level
  Widget _summaryBlock(ReviewSummary summary) {
    final most = summary.stars.values.fold(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                summary.average.toStringAsFixed(1),
                style: AppText.headline.copyWith(color: AppColors.text),
              ),
              StarRow(rating: summary.average),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                trf('${summary.count} ការវាយតម្លៃ', '${summary.count} reviews'),
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              children: [
                for (var s = 5; s >= 1; s--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text(
                            '$s',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: most == 0
                                    ? 0
                                    : (summary.stars[s] ?? 0) / most,
                              ),
                              duration: Motion.off(context)
                                  ? Duration.zero
                                  : AppDuration.slow,
                              curve: Curves.easeOutCubic,
                              builder: (context, f, _) =>
                                  LinearProgressIndicator(
                                    value: f,
                                    minHeight: 6,
                                    color: _starColor,
                                    backgroundColor: AppColors.line,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final date = review.createdAt?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                foregroundImage: review.avatarUrl.isEmpty
                    ? null
                    : NetworkImage(review.avatarUrl),
                child: Text(
                  review.name.isEmpty
                      ? '?'
                      : review.name.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        // Only buyers can review, so every review is verified
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: AppColors.green,
                          semanticLabel: trf('បានទិញពិត', 'Verified purchase'),
                        ),
                      ],
                    ),
                    StarRow(rating: review.rating.toDouble(), size: 12),
                  ],
                ),
              ),
              if (date != null)
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              review.comment,
              style: TextStyle(height: 1.5, color: AppColors.textSoft),
            ),
          ],
        ],
      ),
    );
  }
}

// The sheet to rate a phone: five big stars to tap (each pops and ticks),
// a word for the chosen rating, an optional comment, and Send.
// Resolves true when the review was saved.
Future<bool> showWriteReview(
  BuildContext context, {
  required Phone phone,
  Review? existing,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _WriteReviewSheet(phone: phone, existing: existing),
  );
  return saved == true;
}

class _WriteReviewSheet extends StatefulWidget {
  final Phone phone;
  final Review? existing;

  const _WriteReviewSheet({required this.phone, this.existing});

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _comment = TextEditingController(text: widget.existing?.comment);
  bool _sending = false;

  static List<String> get _words => [
    '',
    trf('អាក្រក់ណាស់', 'Terrible'),
    trf('មិនល្អ', 'Poor'),
    trf('ធម្មតា', 'Okay'),
    trf('ល្អ', 'Good'),
    trf('ល្អណាស់', 'Excellent'),
  ];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_rating == 0) return;
    setState(() => _sending = true);
    try {
      await ApiService.postReview(
        widget.phone.id,
        rating: _rating,
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      Haptics.success();
      Navigator.pop(context, true);
      showMessage(
        context,
        trf('អរគុណសម្រាប់ការវាយតម្លៃ!', 'Thanks for your review!'),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showMessage(context, '$e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.phone.name,
              textAlign: TextAlign.center,
              style: AppText.title.copyWith(color: AppColors.text),
            ),
            const SizedBox(height: AppSpacing.md),
            // The stars: tap one, it and the ones before it light up
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  PressScale(
                    scale: 0.8,
                    child: IconButton(
                      tooltip: '$i',
                      iconSize: 40,
                      onPressed: () => setState(() => _rating = i),
                      icon: AnimatedScale(
                        scale: i <= _rating ? 1.1 : 1,
                        duration: AppDuration.slow,
                        curve: Curves.elasticOut,
                        child: Icon(
                          i <= _rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: i <= _rating ? _starColor : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedSwitcher(
              duration: AppDuration.fast,
              child: Text(
                _rating == 0
                    ? trf('ចុចលើផ្កាយ', 'Tap a star')
                    : _words[_rating],
                key: ValueKey(_rating),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _rating == 0 ? AppColors.muted : _starColor,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _comment,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: trf(
                  'មតិរបស់អ្នក (មិនចាំបាច់)',
                  'Your comment (optional)',
                ),
                hintText: trf(
                  'កាមេរ៉ា ថ្ម អេក្រង់... យ៉ាងម៉េចដែរ?',
                  'How are the camera, battery, screen...?',
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _sending
                ? BusyBar(label: trf('កំពុងផ្ញើ...', 'Sending...'))
                : FilledButton.icon(
                    onPressed: _rating == 0 ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(trf('ផ្ញើការវាយតម្លៃ', 'Send review')),
                  ),
          ],
        ),
      ),
    );
  }
}
