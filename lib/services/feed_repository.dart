import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../entities/post.dart';
import 'cloudinary_service.dart';

/// Firestore layout:
///   posts/{postId}   uid, authorName, authorPhotoUrl, text, imageUrl,
///                    likedBy[], createdAt
/// Images live on Cloudinary; only the URL is stored in the post.
class FeedRepository {
  FeedRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  /// Newest first. Ordering by a normal field needs no custom index.
  Stream<List<Post>> watchPosts({int limit = 50}) => _posts
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => Post.fromMap(d.id, d.data())).toList());

  /// Uploads the photo to Cloudinary first (if any), then writes the post.
  Future<void> createPost({
    required String uid,
    required String authorName,
    required String text,
    String? authorPhotoUrl,
    Uint8List? imageBytes,
  }) async {
    final imageUrl = imageBytes == null
        ? null
        : await CloudinaryService.uploadImage(imageBytes, filename: 'post.jpg');

    await _posts.doc().set({
      'uid': uid,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'imageUrl': imageUrl,
      'likedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleLike(String postId, String uid, {required bool like}) =>
      _posts.doc(postId).update({
        'likedBy': like
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
      });

  /// Deletes the post. The image stays on Cloudinary: deleting needs your
  /// API secret, which must never be shipped inside the app.
  Future<void> deletePost(Post p) => _posts.doc(p.id).delete();
}
