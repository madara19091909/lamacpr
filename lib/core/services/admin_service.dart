import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'post_service.dart';

/// عمليات الإدارة؛ الصلاحية النهائية مفروضة أيضاً بقواعد Firestore.
class AdminService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<AdminStats> stats() async {
    final week = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
    final r = await Future.wait([
      _db.collection('users').count().get(),
      _db.collection('posts').count().get(),
      _db.collection('users').where('banned', isEqualTo: true).count().get(),
      _db.collection('users').where('createdAt', isGreaterThan: week).count().get(),
    ]);
    return AdminStats(
      users: r[0].count ?? 0,
      posts: r[1].count ?? 0,
      banned: r[2].count ?? 0,
      newUsers: r[3].count ?? 0,
    );
  }

  Stream<List<AppUser>> watchUsers() => _db
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());

  Stream<List<Post>> watchPosts() => _db
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Post.fromDoc).toList());

  Future<void> setBanned(String uid, bool banned) =>
      _db.collection('users').doc(uid).update({'banned': banned});

  Future<void> setUserIdentity(
    String uid, {
    required List<AppBadge> badges,
    required bool verified,
    required String verificationStyle,
    String? verificationImageUrl,
    required String title,
  }) {
    if (badges.length > 8) {
      throw ArgumentError('يمكن منح المستخدم 8 أوسمة كحد أقصى.');
    }
    return _db.collection('users').doc(uid).update({
      'badges': badges.map((b) => b.toMap()).toList(),
      'verified': verified,
      'verificationStyle': verificationStyle,
      'verificationImageUrl': verificationImageUrl,
      'title': title.trim(),
    });
  }

  Future<void> deletePost(Post p) => PostService().delete(p);
}
