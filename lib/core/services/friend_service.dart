import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class FriendService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _friends(String uid) =>
      _db.collection('users').doc(uid).collection('friends');

  String _reqId(String sender, String receiver) => '${sender}_$receiver';

  Stream<Set<String>> watchFriendIds(String uid) =>
      _friends(uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());

  Stream<List<FriendRequest>> watchIncoming(String uid) => _db
      .collection('friend_requests')
      .where('receiverId', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map(FriendRequest.fromDoc).toList());

  /// معرفات الناس اللي أرسلت لهم طلب وما انقبل بعد.
  Stream<Set<String>> watchSentIds(String uid) => _db
      .collection('friend_requests')
      .where('senderId', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map((d) => (d.data()['receiverId'] as String?) ?? '').toSet());

  Future<void> sendRequest(AppUser me, String toUid) {
    return _db.collection('friend_requests').doc(_reqId(me.uid, toUid)).set({
      'senderId': me.uid,
      'receiverId': toUid,
      'status': 'pending',
      'senderName': me.name,
      'senderPhoto': me.photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelRequest(String myUid, String toUid) =>
      _db.collection('friend_requests').doc(_reqId(myUid, toUid)).delete();

  Future<void> reject(FriendRequest r) =>
      _db.collection('friend_requests').doc(r.id).delete();

  Future<void> accept(FriendRequest r) async {
    // الخطوة 1: نقبل الطلب (القواعد تتحقق منه قبل ما تسمح بإنشاء الصداقة).
    await _db.collection('friend_requests').doc(r.id).update({'status': 'accepted'});
    // الخطوة 2: نكتب الصداقة من الطرفين. إذا فشلت (انقطاع نت لحظي) نعيد المحاولة،
    // لأن الطلب صار 'accepted' ولن يظهر مرة ثانية بقائمة الطلبات المعلّقة.
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final batch = _db.batch();
        final data = {'since': FieldValue.serverTimestamp()};
        batch.set(_friends(r.receiverId).doc(r.senderId), data);
        batch.set(_friends(r.senderId).doc(r.receiverId), data);
        await batch.commit();
        return;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw lastError ?? StateError('تعذّر إكمال الصداقة.');
  }

  Future<void> remove(String myUid, String friendUid) async {
    final batch = _db.batch();
    batch.delete(_friends(myUid).doc(friendUid));
    batch.delete(_friends(friendUid).doc(myUid));
    await batch.commit();
    // نمسح وثيقة الطلب القديمة (وحدة منهم موجودة)، حتى يكدر يرسل طلب جديد مستقبلاً.
    for (final id in [_reqId(myUid, friendUid), _reqId(friendUid, myUid)]) {
      try {
        await _db.collection('friend_requests').doc(id).delete();
      } catch (_) {}
    }
  }
}
