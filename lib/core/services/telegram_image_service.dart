import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// All binary images in LAMMA are stored through the Cloudflare Worker ->
/// Telegram Bot -> private Telegram channel pipeline. No Firebase Storage.
class TelegramImageService {
  static const String workerUrl =
      'https://weathered-dream-e8de.eren1909eren.workers.dev';
  static const int maxUploadBytes = 9 * 1024 * 1024;

  static const Set<String> supportedKinds = {
    'avatar',
    'banner',
    'badge',
    'verification',
    'emoji',
  };

  /// Detect the actual image format from its magic bytes; do not trust the
  /// filename or the gallery-provided MIME type.
  static ({String mime, String ext})? _detectImage(List<int> b) {
    if (b.length < 12) return null;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return (mime: 'image/jpeg', ext: 'jpg');
    }
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return (mime: 'image/png', ext: 'png');
    }
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
      return (mime: 'image/gif', ext: 'gif');
    }
    if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return (mime: 'image/webp', ext: 'webp');
    }
    return null;
  }

  Future<String> upload({
    required String uid,
    required File file,
    required String kind,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(
      uid: uid,
      bytes: bytes,
      fileName: file.uri.pathSegments.isEmpty
          ? '$kind.jpg'
          : file.uri.pathSegments.last,
      kind: kind,
    );
  }

  /// Upload bytes using the same Worker endpoint for profile images, custom
  /// badges, verification marks, and custom chat emoji artwork.
  Future<String> uploadBytes({
    required String uid,
    required Uint8List bytes,
    required String fileName,
    required String kind,
  }) async {
    if (!supportedKinds.contains(kind)) {
      throw ArgumentError('نوع الصورة غير مدعوم.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid) {
      throw StateError('يجب تسجيل الدخول بالحساب نفسه قبل رفع الصورة.');
    }
    if (bytes.isEmpty || bytes.length > maxUploadBytes) {
      throw StateError('حجم الصورة يجب ألا يتجاوز 9 ميغابايت.');
    }
    final detected = _detectImage(bytes);
    if (detected == null) {
      throw StateError('صيغة الصورة غير مدعومة. استخدم JPG أو PNG أو WEBP أو GIF.');
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw StateError('تعذر التحقق من حسابك. سجّل الدخول مجدداً.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$workerUrl/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['kind'] = kind;
    final safeStem = fileName
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final stem = safeStem.replaceFirst(RegExp(r'\.[^.]*$'), '');
    final safeName = '${stem.isEmpty ? kind : stem}.${detected.ext}';
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: safeName,
      contentType: MediaType.parse(detected.mime),
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      data = decoded;
    } catch (_) {
      throw StateError('استجابة Cloudflare غير مفهومة (${response.statusCode}).');
    }
    if (response.statusCode < 200 || response.statusCode >= 300 || data['ok'] != true) {
      final message = data['details'] ?? data['error'] ?? data['message'] ??
          'فشل رفع الصورة إلى قناة التخزين';
      throw StateError(message.toString());
    }

    final rawImageUrl = data['imageUrl'] ?? data['url'];
    final imageUrl = rawImageUrl is String ? rawImageUrl : null;
    final parsedUrl = imageUrl == null ? null : Uri.tryParse(imageUrl);
    if (parsedUrl == null || parsedUrl.scheme != 'https' || parsedUrl.host.isEmpty) {
      throw StateError('Worker لم يرجع رابط HTTPS صالحاً للصورة.');
    }

    // Only profile uploads update the user's own profile document here.
    // Badge / verification / emoji URLs are saved by their respective services.
    if (kind == 'avatar' || kind == 'banner') {
      final field = kind == 'avatar' ? 'photoUrl' : 'bannerUrl';
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        field: imageUrl,
      });
    }
    return imageUrl!;
  }
}
