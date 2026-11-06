import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/models.dart';
import 'auth_service.dart';

class UserService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  final Map<String, Future<AppUser?>> _cache = {};

  /// ينشئ ملف المستخدم أول مرة يدخل، وبعدها يحدّث آخر ظهور.
  Future<void> ensureProfile(User u) async {
    final ref = _users.doc(u.uid);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({'lastSeen': FieldValue.serverTimestamp()});
      return;
    }
    final typed = (AuthService.pendingName ?? u.displayName ?? '').trim();
    final fallback = (u.email ?? 'مستخدم').split('@').first;
    final name = typed.isEmpty ? fallback : typed;
    await ref.set({
      'uid': u.uid,
      'displayName': name,
      'displayNameLower': name.toLowerCase(),
      'photoUrl': u.photoURL,
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

  Future<AppUser?> byId(String uid) => _cache.putIfAbsent(uid, () async {
        final s = await _users.doc(uid).get();
        return s.exists ? AppUser.fromDoc(s) : null;
      });

  void invalidate(String uid) {
    _cache.remove(uid);
  }

  Future<List<AppUser>> search(String query, String myUid) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final snap = await _users
        .orderBy('displayNameLower')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(20)
        .get();
    return snap.docs
        .map(AppUser.fromDoc)
        .where((u) => u.uid != myUid && !u.banned)
        .toList();
  }

  Future<void> updateProfile(String uid, {required String name, required String bio}) async {
    final clean = name.trim();
    await _users.doc(uid).update({
      'displayName': clean,
      'displayNameLower': clean.toLowerCase(),
      'bio': bio.trim(),
    });
    _cache.remove(uid);
  }

  Future<void> updateAvatar(String uid, File file) async {
    final ref = FirebaseStorage.instance.ref('users/$uid/avatar.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    final fresh = '$url&v=${DateTime.now().millisecondsSinceEpoch}';
    await _users.doc(uid).update({'photoUrl': fresh});
    _cache.remove(uid);
  }
}
