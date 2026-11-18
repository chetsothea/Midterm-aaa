import 'phone.dart';

// The live shopping session the admin started (GET /api/live)
class LiveSession {
  final bool isLive;
  final String youtubeId; // '' when nothing is live
  final String title;
  final List<Phone> products; // pinned under the stream, in the admin's order

  const LiveSession({
    required this.isLive,
    required this.youtubeId,
    required this.title,
    required this.products,
  });

  static const off = LiveSession(
    isLive: false,
    youtubeId: '',
    title: '',
    products: [],
  );

  factory LiveSession.fromJson(Map<String, dynamic> json) => LiveSession(
    isLive: json['is_live'] == true,
    youtubeId: json['youtube_id'] ?? '',
    title: json['title'] ?? '',
    products: [
      for (final p in (json['products'] as List? ?? const []))
        Phone.fromJson(Map<String, dynamic>.from(p)),
    ],
  );
}

// One message under the stream
class LiveComment {
  final int id;
  final String name;
  final String avatarUrl;
  final String message;

  const LiveComment({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.message,
  });

  factory LiveComment.fromJson(Map<String, dynamic> json) => LiveComment(
    id: json['id'],
    name: json['name'] ?? '',
    avatarUrl: json['avatar_url'] ?? '',
    message: json['message'] ?? '',
  );
}
