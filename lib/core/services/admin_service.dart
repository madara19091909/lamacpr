import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';

/// عمليات الإدارة؛ الصلاحية النهائية مفروضة أيضاً بقواعد Firestore.
class AdminService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? _adminName;

  Future<int> _count(Query<Map<String, dynamic>> q) async =>
      (await q.count().get()).count ?? 0;

  Future<AdminStats> stats() async {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    Timestamp ts(DateTime d) => Timestamp.fromDate(d);
    final users = _db.collection('users');
    final days = [
      for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i),
    ];
    final r = await Future.wait<int>([
      _count(users),
      _count(users.where('banned', isEqualTo: true)),
      _count(users.where('createdAt', isGreaterThan: ts(now.subtract(const Duration(days: 7))))),
      _count(users.where('createdAt', isGreaterThanOrEqualTo: ts(startToday))),
      _count(users.where('verified', isEqualTo: true)),
      _count(users.where('lastSeen', isGreaterThan: ts(now.subtract(const Duration(hours: 24))))),
      _count(users.where('lastSeen', isGreaterThan: ts(now.subtract(const Duration(days: 7))))),
      for (final d in days)
        _count(users
            .where('createdAt', isGreaterThanOrEqualTo: ts(d))
            .where('createdAt', isLessThan: ts(DateTime(d.year, d.month, d.day + 1)))),
    ]);
    return AdminStats(
      users: r[0],
      banned: r[1],
      newUsers: r[2],
      newToday: r[3],
      verified: r[4],
      active24h: r[5],
      active7d: r[6],
      signupsByDay: r.sublist(7),
    );
  }

  Stream<List<AppUser>> watchUsers({int limit = 300}) => _db
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(AppUser.fromDoc).toList());

  /// حظر/فك حظر مع سبب. إذا القواعد القديمة ما تسمح بحقل السبب نرجع للحظر البسيط.
  Future<void> setBanned(AppUser user, bool banned, {String reason = ''}) async {
    final ref = _db.collection('users').doc(user.uid);
    final clean = reason.trim();
    try {
      await ref.update({
        'banned': banned,
        'banReason': banned ? clean : FieldValue.delete(),
        'bannedAt': banned ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      await ref.update({'banned': banned});
    }
    await _log(banned ? 'ban' : 'unban', target: user, detail: clean);
  }

  Future<void> bulkSetBanned(List<AppUser> users, bool banned) async {
    await _bulkUpdate(users, {'banned': banned});
    await _log(banned ? 'bulk_ban' : 'bulk_unban', detail: _names(users));
  }

  Future<void> bulkSetVerified(List<AppUser> users, bool verified) async {
    await _bulkUpdate(users, {'verified': verified});
    await _log(verified ? 'bulk_verify' : 'bulk_unverify', detail: _names(users));
  }

  String _names(List<AppUser> users) {
    final names = users.take(5).map((u) => u.name).join('، ');
    final more = users.length > 5 ? ' …' : '';
    return '${users.length} حساب: $names$more';
  }

  Future<void> _bulkUpdate(List<AppUser> users, Map<String, dynamic> data) async {
    for (var i = 0; i < users.length; i += 400) {
      final batch = _db.batch();
      for (final u in users.skip(i).take(400)) {
        batch.update(_db.collection('users').doc(u.uid), data);
      }
      await batch.commit();
    }
  }

  Future<void> setUserIdentity(
    String uid, {
    required List<AppBadge> badges,
    required bool verified,
    required String verificationStyle,
    String? verificationImageUrl,
    required String title,
    String targetName = '',
  }) async {
    if (badges.length > 8) {
      throw ArgumentError('يمكن منح المستخدم 8 أوسمة كحد أقصى.');
    }
    await _db.collection('users').doc(uid).update({
      'badges': badges.map((badge) => badge.toMap()).toList(),
      'verified': verified,
      'verificationStyle': verificationStyle,
      'verificationImageUrl': verificationImageUrl,
      'title': title.trim(),
    });
    await _log(
      'identity',
      targetUid: uid,
      targetName: targetName,
      detail: '${verified ? 'موثّق' : 'غير موثّق'} • ${badges.length} وسام'
          '${title.trim().isEmpty ? '' : ' • لقب: ${title.trim()}'}',
    );
  }

  Stream<List<AdminLog>> watchLogs({int limit = 100}) => _db
      .collection('admin_logs')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(AdminLog.fromDoc).toList());

  /// تسجيل الإجراء. فشله ما يمنع الإجراء نفسه (مثلاً قبل نشر القواعد الجديدة).
  Future<void> _log(
    String action, {
    AppUser? target,
    String? targetUid,
    String? targetName,
    String detail = '',
  }) async {
    try {
      final me = FirebaseAuth.instance.currentUser;
      if (me == null) return;
      if (_adminName == null) {
        final doc = await _db.collection('users').doc(me.uid).get();
        _adminName = (doc.data()?['displayName'] as String?)?.trim();
        if (_adminName == null || _adminName!.isEmpty) _adminName = 'مشرف';
      }
      final cleanDetail = detail.length > 300 ? detail.substring(0, 300) : detail;
      await _db.collection('admin_logs').add({
        'action': action,
        'adminUid': me.uid,
        'adminName': _adminName,
        'targetUid': target?.uid ?? targetUid ?? '',
        'targetName': target?.name ?? targetName ?? '',
        'detail': cleanDetail,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
