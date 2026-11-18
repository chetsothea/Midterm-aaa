// One customer's stars and words about a phone
class Review {
  final int id;
  final String name;
  final String avatarUrl;
  final int rating; // 1..5
  final String comment;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'],
    name: json['name'] ?? '',
    avatarUrl: json['avatar_url'] ?? '',
    rating: int.tryParse('${json['rating']}') ?? 0,
    comment: json['comment'] ?? '',
    createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
  );
}

// Everything the detail page shows about a phone's reviews
class ReviewSummary {
  final double average;
  final int count;
  final Map<int, int> stars; // 5 -> how many gave 5 stars, ...
  final List<Review> reviews; // newest first
  final bool canReview; // the signed-in customer received this phone
  final Review? mine;

  const ReviewSummary({
    required this.average,
    required this.count,
    required this.stars,
    required this.reviews,
    required this.canReview,
    this.mine,
  });

  static const empty = ReviewSummary(
    average: 0,
    count: 0,
    stars: {},
    reviews: [],
    canReview: false,
  );

  factory ReviewSummary.fromJson(Map<String, dynamic> json) => ReviewSummary(
    average: double.tryParse('${json['average']}') ?? 0,
    count: int.tryParse('${json['count']}') ?? 0,
    stars: {
      for (final e in Map<String, dynamic>.from(json['stars'] ?? {}).entries)
        int.parse(e.key): int.tryParse('${e.value}') ?? 0,
    },
    reviews: [
      for (final r in (json['reviews'] as List? ?? const []))
        Review.fromJson(Map<String, dynamic>.from(r)),
    ],
    canReview: json['can_review'] == true,
    mine: json['mine'] is Map
        ? Review.fromJson(Map<String, dynamic>.from(json['mine']))
        : null,
  );
}
