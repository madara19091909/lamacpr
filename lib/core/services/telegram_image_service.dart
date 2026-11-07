import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TelegramImageService {
  static const String _workerUrl = 'https://weathered-dream-e8de.eren1909eren.workers.dev';

  Future<String> upload({
    required String uid,
    required File file,
    required String kind,
  }) async {
    if (kind != 'avatar' && kind != 'banner') {
      throw ArgumentError('نوع الصورة غير صالح.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid) {
      throw StateError('يجب تسجيل الدخول بالحساب نفسه قبل رفع الصورة.');
    }
    final length = await file.length();
    if (length <= 0 || length > 9 * 1024 * 1024) {
      throw StateError('حجم الصورة يجب أن يكون أقل من 9 ميغابايت.');
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw StateError('تعذر التحقق من حسابك. سجّل الدخول مجدداً.');
    }
    final request = http.MultipartRequest('POST', Uri.parse('$_workerUrl/upload'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['kind'] = kind;
    request.files.add(await http.MultipartFile.fromPath('image', file.path));
    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('استجابة خدمة الصور غير مفهومة (${response.statusCode}).');
    }
    if (response.statusCode != 200 || data['ok'] != true) {
      final message = data['details'] ?? data['error'] ?? 'فشل رفع الصورة';
      throw StateError(message.toString());
    }
    final imageUrl = data['imageUrl'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      throw StateError('لم ترجع خدمة الصور رابط الصورة.');
    }
    final field = kind == 'avatar' ? 'photoUrl' : 'bannerUrl';
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      field: imageUrl,
      '${kind}TelegramFileId': data['fileId'],
      '${kind}UpdatedAt': FieldValue.serverTimestamp(),
    });
    return imageUrl;
  }
}
