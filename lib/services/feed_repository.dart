import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../entities/post.dart';

// ── Cloudinary settings ──
// Cloudinary dashboard -> top left shows your "Cloud name".
// Settings -> Upload -> Upload presets -> Add preset -> Signing mode: Unsigned.
const _kCloudName = 'zyvukzwf';
const _kUploadPreset = 'flutter_unsigned';

/// Firestore layout:
///   posts/{postId}   uid, authorName, text, imageUrl, likedBy[], createdAt
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
    Uint8List? imageBytes,
  }) async {
    final imageUrl = imageBytes == null ? null : await _uploadImage(imageBytes);

    await _posts.doc().set({
      'uid': uid,
      'authorName': authorName,
      'text': text,
      'imageUrl': imageUrl,
      'likedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unsigned upload straight from the app. Returns the https image URL.
  Future<String> _uploadImage(Uint8List bytes) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_kCloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _kUploadPreset
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'post.jpg'),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 40));
    final res = await http.Response.fromStream(streamed);

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode != 200) {
      final msg =
          (body['error'] as Map?)?['message'] ?? 'HTTP ${res.statusCode}';
      throw Exception('Image upload failed: $msg');
    }
    final url = body['secure_url'];
    if (url is! String) throw Exception('Image upload failed: no URL returned');
    return url;
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
