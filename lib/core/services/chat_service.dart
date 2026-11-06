import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class ChatService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');

  List<String> _pair(String a, String b) => [a, b]..sort();

  String chatId(String a, String b) => _pair(a, b).join('_');

  Stream<List<ChatSummary>> watchChats(String me) => _chats
      .where('participants', arrayContains: me)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => ChatSummary.fromDoc(d, me)).toList());

  Future<void> ensureChat(String id, AppUser me, AppUser other) {
    return _chats.doc(id).set({
      'participants': _pair(me.uid, other.uid),
      'participantNames': {me.uid: me.name, other.uid: other.name},
    }, SetOptions(merge: true));
  }

  Future<String> createGroup({
    required String title,
    required List<String> memberIds,
    required String creatorId,
  }) async {
    final participants = {...memberIds, creatorId}.toList()..sort();
    if (participants.length < 3) {
      throw ArgumentError('اختَر صديقين على الأقل حتى تنشئ مجموعة.');
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
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'تم إنشاء المجموعة',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': creatorId,
      'reads': {creatorId: FieldValue.serverTimestamp()},
    });
    return ref.id;
  }

  Stream<List<Message>> watchMessages(String id) => _chats
      .doc(id)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(150)
      .snapshots()
      .map((s) => s.docs.map(Message.fromDoc).toList());

  String _cleanText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) throw ArgumentError('الرسالة فارغة.');
    if (clean.length > 2000) throw ArgumentError('الرسالة طويلة (الحد 2000 حرف).');
    return clean;
  }

  Future<void> send(
    String id,
    String me,
    String other,
    String rawText, {
    String senderName = '',
    String? senderPhoto,
  }) async {
    final text = _cleanText(rawText);
    final ref = _chats.doc(id);
    final batch = _db.batch();
    batch.set(ref, {
      'participants': _pair(me, other),
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': me,
      'lastSenderName': senderName,
      'reads': {me: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
    batch.set(ref.collection('messages').doc(), {
      'senderId': me,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> sendGroup(
    String id,
    AppUser sender,
    String rawText,
  ) async {
    final text = _cleanText(rawText);
    final ref = _chats.doc(id);
    final batch = _db.batch();
    batch.update(ref, {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': sender.uid,
      'lastSenderName': sender.name,
      'reads.${sender.uid}': FieldValue.serverTimestamp(),
    });
    batch.set(ref.collection('messages').doc(), {
      'senderId': sender.uid,
      'senderName': sender.name,
      'senderPhoto': sender.photoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> markRead(String id, String me) =>
      _chats.doc(id).update({'reads.$me': FieldValue.serverTimestamp()});
}
