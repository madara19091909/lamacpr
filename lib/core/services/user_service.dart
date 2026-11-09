import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'auth_service.dart';
import 'telegram_image_service.dart';

class UserService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');


  /// ينشئ ملف المستخدم أول مرة يدخل، ويهاجر حقول الحسابات القديمة تدريجياً.
  Future<void> ensureProfile(User u) async {
    final ref = _users.doc(u.uid);
    final snap = await ref.get();
    final emailFallback = (u.email ?? 'مستخدم').split('@').first.trim();
    final typed = (AuthService.pendingName ?? u.displayName ?? '').trim();
    String safeName(String? value) {
      var candidate = value?.trim() ?? '';
      if (candidate.length < 2 || candidate == u.uid) {
        candidate = typed.length >= 2 ? typed : emailFallback;
      }
      if (candidate.length < 2) candidate = 'عضو لَمّة';
      if (candidate.length > 40) candidate = candidate.substring(0, 40);
      return candidate;
    }

    final defaultUsername = 'lamma_${u.uid.substring(0, u.uid.length < 6 ? u.uid.length : 6)}';
    if (snap.exists) {
      final data = snap.data() ?? <String, dynamic>{};
      final storedDisplayName = (data['displayName'] as String?)?.trim();
      final legacyName = (data['name'] as String?)?.trim();
      final resolvedName = safeName(
        storedDisplayName?.isNotEmpty == true && storedDisplayName != u.uid
            ? storedDisplayName
            : legacyName,
      );
      final storedUsername = (data['username'] as String?)?.trim();
      final normalizedUsername = storedUsername
          ?.replaceFirst(RegExp(r'^@'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      final validUsername = normalizedUsername != null &&
          normalizedUsername.length >= 3 &&
          normalizedUsername.length <= 24 &&
          normalizedUsername != u.uid;
      final updates = <String, dynamic>{
        'lastSeen': FieldValue.serverTimestamp(),
      };
      if (storedDisplayName != resolvedName) {
        updates['displayName'] = resolvedName;
      }
      if ((data['displayNameLower'] as String?)?.isNotEmpty != true || storedDisplayName != resolvedName) {
        updates['displayNameLower'] = resolvedName.toLowerCase();
      }
      if (!validUsername) {
        updates['username'] = defaultUsername;
        updates['usernameLower'] = defaultUsername.toLowerCase();
      } else if ((data['usernameLower'] as String?)?.isNotEmpty != true || storedUsername != normalizedUsername) {
        updates['username'] = normalizedUsername;
        updates['usernameLower'] = normalizedUsername!.toLowerCase();
      }
      await ref.update(updates);
      return;
    }

    final name = safeName(typed.isNotEmpty ? typed : emailFallback);
    await ref.set({
      'uid': u.uid,
      'displayName': name,
      'displayNameLower': name.toLowerCase(),
      'username': defaultUsername,
      'usernameLower': defaultUsername.toLowerCase(),
      'photoUrl': u.photoURL,
      'bannerUrl': null,
      'bio': '',
      'banned': false,
      'badges': <Map<String, dynamic>>[],
      'verified': false,
      'verificationStyle': 'classic',
      'title': '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Stream<AppUser?> watch(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? AppUser.fromDoc(s) : null);

  /// يتحقق إذا المستخدم مشرف: وجود وثيقة admins/{uid}. الإضافة تكون يدوياً من Console فقط.
  Stream<bool> isAdmin(String uid) => _db
      .collection('admins')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists);

  /// قراءة حديثة دائماً؛ لا نخزّن ملف العضو للأبد حتى لا تبقى الأوسمة
  /// أو الصورة أو الاسم القديم ظاهراً بعد تحديثه من لوحة الإدارة.
  Future<AppUser?> byId(String uid) async {
    final s = await _users.doc(uid).get();
    return s.exists ? AppUser.fromDoc(s) : null;
  }

  void invalidate(String uid) {
    // بقيت الدالة للتوافق مع الشاشات القديمة؛ byId لم يعد يستخدم Cache دائم.
  }

  Future<List<AppUser>> search(String query, String myUid) async {
    final rawQuery = query.trim();
    final q = rawQuery.toLowerCase();
    if (q.isEmpty) return [];
    final results = await Future.wait([
      _users.orderBy('displayNameLower').startAt([q]).endAt(['$q\uf8ff']).limit(20).get(),
      _users.orderBy('usernameLower').startAt([q]).endAt(['$q\uf8ff']).limit(20).get(),
      // استعلام احتياطي للحسابات القديمة التي لم تملك حقول البحث الصغيرة بعد.
      _users.orderBy('displayName').startAt([rawQuery]).endAt(['$rawQuery\uf8ff']).limit(20).get(),
    ]);
    final combined = <String, AppUser>{};
    for (final doc in results.expand((snapshot) => snapshot.docs)) {
      final user = AppUser.fromDoc(doc);
      if (user.uid != myUid && !user.banned) combined[user.uid] = user;
    }
    return combined.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> updateProfile(String uid, {required String name, required String username, required String bio}) async {
    final clean = name.trim();
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '').replaceAll(RegExp(r'\s+'), '_');
    if (clean.length < 2 || clean.length > 40) {
      throw ArgumentError('الاسم لازم يكون من حرفين إلى 40 حرفاً.');
    }
    if (cleanUsername.length < 3 || cleanUsername.length > 24) {
      throw ArgumentError('اسم المستخدم لازم يكون من 3 إلى 24 حرفاً.');
    }
    final duplicate = await _users
        .where('usernameLower', isEqualTo: cleanUsername.toLowerCase())
        .limit(2)
        .get();
    if (duplicate.docs.any((doc) => doc.id != uid)) {
      throw ArgumentError('اسم المستخدم مستخدم من حساب آخر. جرّب اسماً مختلفاً.');
    }
    await _users.doc(uid).update({
      'displayName': clean,
      'displayNameLower': clean.toLowerCase(),
      'username': cleanUsername,
      'usernameLower': cleanUsername.toLowerCase(),
      'bio': bio.trim(),
    });
  }

  final TelegramImageService _telegramImages = TelegramImageService();

  Future<void> updateBanner(String uid, File file) async {
    await _telegramImages.upload(uid: uid, file: file, kind: 'banner');
  }

  Future<void> updateAvatar(String uid, File file) async {
    await _telegramImages.upload(uid: uid, file: file, kind: 'avatar');
  }
}
