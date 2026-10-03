import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Uploads images to Cloudinary with an unsigned preset (no secret in the app).
/// Used for post photos and profile pictures.
class CloudinaryService {
  CloudinaryService._();

  static const _cloudName = 'zyvukzwf';
  static const _uploadPreset = 'flutter_unsigned';

  /// Returns the https URL of the uploaded image.
  static Future<String> uploadImage(
    Uint8List bytes, {
    String filename = 'image.jpg',
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamed = await request.send().timeout(const Duration(seconds: 40));
    final res = await http.Response.fromStream(streamed);

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode != 200) {
      final msg = (body['error'] as Map?)?['message'] ?? 'HTTP ${res.statusCode}';
      throw Exception('Image upload failed: $msg');
    }
    final url = body['secure_url'];
    if (url is! String) throw Exception('Image upload failed: no URL returned');
    return url;
  }
}
