import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// عمليات الإدارة؛ الصلاحية النهائية مفروضة أيضاً بقواعد Firestore.
class AdminService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<AdminStats> stats() async {
    final week = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
    final results = await Future.wait([
      _db.collection('users').count().get(),
      _db.collection('users').where('banned', isEqualTo: true).count().get(),
      _db.collection('users').where('createdAt', isGreaterThan: week).count().get(),
    ]);
    return AdminStats(
      users: results[0].count ?? 0,
      banned: results[1].count ?? 0,
      newUsers: results[2].count ?? 0,
    );
  }

  Stream<List<AppUser>> watchUsers() => _db
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(AppUser.fromDoc).toList());

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
      'badges': badges.map((badge) => badge.toMap()).toList(),
      'verified': verified,
      'verificationStyle': verificationStyle,
      'verificationImageUrl': verificationImageUrl,
      'title': title.trim(),
    });
  }
}
