import 'model_utils.dart';

/// One social post in the feed (Firestore: posts/{id}).
class Post {
  const Post({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.imageUrl,
    this.likedBy = const [],
  });

  final String id;
  final String uid;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final String? imageUrl;

  /// Uids of the users who liked the post.
  final List<String> likedBy;

  int get likeCount => likedBy.length;
  bool isLikedBy(String uid) => likedBy.contains(uid);

  factory Post.fromMap(String id, Map<String, dynamic> m) {
    final img = m['imageUrl'];
    return Post(
      id: id,
      uid: '${m['uid'] ?? ''}',
      authorName: '${m['authorName'] ?? 'Athlete'}',
      text: '${m['text'] ?? ''}',
      // null while a server timestamp is still pending -> "now".
      createdAt: toDate(m['createdAt']),
      imageUrl: img is String && img.isNotEmpty ? img : null,
      likedBy: stringList(m['likedBy']),
    );
  }
}
