import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';

class ChatService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');

  List<String> _pair(String a, String b) => [a, b]..sort();

  String chatId(String a, String b) => _pair(a, b).join('_');

  /// لا نستخدم orderBy هنا حتى لا تتعطل القائمة إذا لم تُنشر الفهرسة المركبة
  /// على مشروع Firebase. الترتيب يتم محلياً بعد استلام محادثات العضو فقط.
  Stream<List<ChatSummary>> watchChats(String me) => _chats
      .where('participants', arrayContains: me)
      .snapshots()
      .map((snapshot) {
        final chats = snapshot.docs.map((doc) => ChatSummary.fromDoc(doc, me)).toList();
        chats.sort((a, b) => (b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        return chats;
      });

  Stream<ChatSummary?> watchChat(String id, String me) => _chats
      .doc(id)
      .snapshots()
      .map((snapshot) => snapshot.exists ? ChatSummary.fromDoc(snapshot, me) : null);

  Future<void> ensureChat(String id, AppUser me, AppUser other) {
    // set مع merge يسمح بإنشاء المحادثة الأولى أو تحديث أسماء الطرفين،
    // من دون تصفير آخر رسالة كلما فتح المستخدم المحادثة.
    return _chats.doc(id).set({
      'participants': _pair(me.uid, other.uid),
      'participantNames': {me.uid: me.name, other.uid: other.name},
    }, SetOptions(merge: true));
  }

  Future<String> createGroup({
    required String title,
    required List<String> memberIds,
    required String creatorId,
    required String creatorName,
    Map<String, String> memberNames = const {},
  }) async {
    final participants = {...memberIds, creatorId}.toList()..sort();
    if (participants.length < 2) {
      throw ArgumentError('اختَر صديقاً واحداً على الأقل حتى تنشئ مجموعة.');
    }
    if (participants.length > 50) {
      throw ArgumentError('الحد الأقصى للمجموعة 50 عضواً.');
    }
    final cleanTitle = title.trim();
    if (cleanTitle.length < 2 || cleanTitle.length > 40) {
      throw ArgumentError('اسم المجموعة لازم يكون من حرفين إلى 40 حرفاً.');
    }
    final ref = _chats.doc();
    await ref.set({
      'type': 'group',
      'title': cleanTitle,
      'participants': participants,
      'admins': [creatorId],
      'createdBy': creatorId,
      'description': '',
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': 'تم إنشاء المجموعة',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': creatorId,
      'lastSenderName': creatorName,
      'reads': {creatorId: FieldValue.serverTimestamp()},
      'participantNames': {creatorId: creatorName, ...memberNames},
    });
    return ref.id;
  }

  Future<void> renameGroup(String chatId, String title) async {
    final clean = title.trim();
    if (clean.length < 2 || clean.length > 40) {
      throw ArgumentError('اسم المجموعة لازم يكون من حرفين إلى 40 حرفاً.');
    }
    await _chats.doc(chatId).update({
      'title': clean,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGroupDescription(String chatId, String description) async {
    final clean = description.trim();
    if (clean.length > 180) {
      throw ArgumentError('وصف المجموعة لا يتجاوز 180 حرفاً.');
    }
    await _chats.doc(chatId).update({
      'description': clean,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addGroupMember(String chatId, AppUser member) async {
    final ref = _chats.doc(chatId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('المجموعة غير موجودة.');
      final data = snapshot.data() ?? <String, dynamic>{};
      final participants = (data['participants'] as List? ?? const []).whereType<String>().toSet();
      final admins = (data['admins'] as List? ?? const []).whereType<String>().toSet();
      if (participants.length >= 50) throw StateError('وصلت المجموعة للحد الأقصى (50 عضواً).');
      final actorUid = FirebaseAuth.instance.currentUser?.uid;
      if (actorUid == null || !admins.contains(actorUid)) throw StateError('إضافة الأعضاء متاحة لمشرفي المجموعة فقط.');
      if (participants.contains(member.uid)) return;
      participants.add(member.uid);
      final names = Map<String, dynamic>.from((data['participantNames'] as Map?) ?? const {});
      names[member.uid] = member.name;
      transaction.update(ref, {
        'participants': participants.toList()..sort(),
        'participantNames': names,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> removeGroupMember(String chatId, String memberUid) async {
    final ref = _chats.doc(chatId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('المجموعة غير موجودة.');
      final data = snapshot.data() ?? <String, dynamic>{};
      final actorUid = FirebaseAuth.instance.currentUser?.uid;
      final createdBy = (data['createdBy'] as String?) ?? '';
      final participants = (data['participants'] as List? ?? const []).whereType<String>().toSet();
      final admins = (data['admins'] as List? ?? const []).whereType<String>().toSet();
      if (actorUid == null || !admins.contains(actorUid)) throw StateError('إزالة الأعضاء متاحة لمشرفي المجموعة فقط.');
      if (memberUid == createdBy) throw StateError('لا يمكن إزالة منشئ المجموعة.');
      if (admins.contains(memberUid) && actorUid != createdBy) {
        throw StateError('إزالة مشرف آخر متاحة لمنشئ المجموعة فقط.');
      }
      if (!participants.contains(memberUid)) return;
      participants.remove(memberUid);
      admins.remove(memberUid);
      final names = Map<String, dynamic>.from((data['participantNames'] as Map?) ?? const {});
      names.remove(memberUid);
      transaction.update(ref, {
        'participants': participants.toList()..sort(),
        'admins': admins.toList(),
        'participantNames': names,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setGroupAdmin(String chatId, String memberUid, bool admin) async {
    final ref = _chats.doc(chatId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('المجموعة غير موجودة.');
      final data = snapshot.data() ?? <String, dynamic>{};
      final actorUid = FirebaseAuth.instance.currentUser?.uid;
      final participants = (data['participants'] as List? ?? const []).whereType<String>().toSet();
      final admins = (data['admins'] as List? ?? const []).whereType<String>().toSet();
      if (actorUid == null || actorUid != data['createdBy']) {
        throw StateError('منشئ المجموعة وحده يغيّر صلاحيات المشرفين.');
      }
      if (!participants.contains(memberUid)) throw StateError('العضو غير موجود بالمجموعة.');
      if (admin) {
        admins.add(memberUid);
      } else {
        if (memberUid == data['createdBy']) throw StateError('لا يمكن إزالة صلاحية منشئ المجموعة.');
        admins.remove(memberUid);
      }
      transaction.update(ref, {
        'admins': admins.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> leaveGroup(String chatId) async {
    final ref = _chats.doc(chatId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('المجموعة غير موجودة.');
      final data = snapshot.data() ?? <String, dynamic>{};
      final actorUid = FirebaseAuth.instance.currentUser?.uid;
      final createdBy = (data['createdBy'] as String?) ?? '';
      final participants = (data['participants'] as List? ?? const []).whereType<String>().toSet();
      final admins = (data['admins'] as List? ?? const []).whereType<String>().toSet();
      if (actorUid == null || !participants.contains(actorUid)) throw StateError('أنت مو عضو بهذه المجموعة.');
      if (actorUid == createdBy) throw StateError('منشئ المجموعة لازم ينقل الملكية قبل المغادرة.');
      if (admins.contains(actorUid) && admins.length == 1) {
        throw StateError('عيّن مشرفاً آخر قبل مغادرة المجموعة.');
      }
      participants.remove(actorUid);
      admins.remove(actorUid);
      final names = Map<String, dynamic>.from((data['participantNames'] as Map?) ?? const {});
      names.remove(actorUid);
      transaction.update(ref, {
        'participants': participants.toList()..sort(),
        'admins': admins.toList(),
        'participantNames': names,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<Message>> watchMessages(String id) => _chats
      .doc(id)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(150)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Message.fromDoc).toList());

  String _cleanText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) throw ArgumentError('الرسالة فارغة.');
    if (clean.length > 2000) throw ArgumentError('الرسالة طويلة (الحد 2000 حرف).');
    return clean;
  }

  Map<String, dynamic>? _replyData(Message? replyTo) {
    if (replyTo == null) return null;
    return {
      'id': replyTo.id,
      'text': replyTo.deleted ? 'رسالة محذوفة' : replyTo.text,
      'sender': replyTo.senderName,
    };
  }

  Future<void> send(
    String id,
    String me,
    String other,
    String rawText, {
    String senderName = '',
    String? senderPhoto,
    Message? replyTo,
  }) async {
    final text = _cleanText(rawText);
    final chatRef = _chats.doc(id);
    final messageRef = chatRef.collection('messages').doc();
    final batch = _db.batch();
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': me,
      'lastSenderName': senderName,
      'reads.$me': FieldValue.serverTimestamp(),
    });
    batch.set(messageRef, {
      'senderId': me,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      if (_replyData(replyTo) != null) 'replyTo': _replyData(replyTo),
    });
    await batch.commit();
  }

  Future<void> sendGroup(
    String id,
    AppUser sender,
    String rawText, {
    Message? replyTo,
  }) async {
    final text = _cleanText(rawText);
    final chatRef = _chats.doc(id);
    final messageRef = chatRef.collection('messages').doc();
    final batch = _db.batch();
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': sender.uid,
      'lastSenderName': sender.name,
      'reads.${sender.uid}': FieldValue.serverTimestamp(),
    });
    batch.set(messageRef, {
      'senderId': sender.uid,
      'senderName': sender.name,
      'senderPhoto': sender.photoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      if (_replyData(replyTo) != null) 'replyTo': _replyData(replyTo),
    });
    await batch.commit();
  }

  Future<void> editMessage(String chatId, String messageId, String rawText) async {
    final text = _cleanText(rawText);
    await _chats.doc(chatId).collection('messages').doc(messageId).update({
      'text': text,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _chats.doc(chatId).collection('messages').doc(messageId).update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// يخفي رسالة الطرف الآخر عند العضو الحالي فقط، ولا يحذفها من سجل بقية المشاركين.
  Future<void> hideMessage(String chatId, String myUid, String messageId) async {
    await _chats.doc(chatId).update({
      'hiddenMessages.$myUid': FieldValue.arrayUnion([messageId]),
    });
  }

  Future<void> toggleReaction(
    String chatId,
    String messageId,
    String myUid,
    String emoji,
  ) async {
    final ref = _chats.doc(chatId).collection('messages').doc(messageId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? <String, dynamic>{};
      final raw = data['reactions'];
      final reactions = <String, String>{};
      if (raw is Map) {
        raw.forEach((key, value) {
          if (key is String && value is String) reactions[key] = value;
        });
      }
      if (reactions[myUid] == emoji) {
        reactions.remove(myUid);
      } else {
        reactions[myUid] = emoji;
      }
      transaction.update(ref, {'reactions': reactions});
    });
  }

  Future<void> setTyping(String chatId, String myUid, bool isTyping) async {
    await _chats.doc(chatId).collection('typing').doc(myUid).set({
      'isTyping': isTyping,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<bool> watchTyping(String chatId, String otherUid) => _chats
      .doc(chatId)
      .collection('typing')
      .doc(otherUid)
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        final updatedAt = data?['updatedAt'];
        if (data?['isTyping'] != true || updatedAt is! Timestamp) return false;
        return DateTime.now().difference(updatedAt.toDate()).inSeconds < 8;
      });

  Stream<int> watchTypingCount(String chatId, String myUid) => _chats
      .doc(chatId)
      .collection('typing')
      .where('isTyping', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.where((doc) {
            if (doc.id == myUid) return false;
            final updatedAt = doc.data()['updatedAt'];
            return updatedAt is Timestamp &&
                DateTime.now().difference(updatedAt.toDate()).inSeconds < 8;
          }).length);

  Future<void> markRead(String id, String me) =>
      _chats.doc(id).update({'reads.$me': FieldValue.serverTimestamp()});
}
