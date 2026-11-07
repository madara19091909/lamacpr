import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;
List<String> _strings(dynamic v) =>
    v is List ? v.whereType<String>().toList() : <String>[];

class AppBadge {
  const AppBadge({
    required this.id,
    required this.label,
    this.icon = 'star',
    this.color = 0xFFBBA5FF,
    this.style = 'gradient',
    this.imageUrl,
  });

  final String id;
  final String label;
  final String icon;
  final int color;
  final String style;
  final String? imageUrl;

  factory AppBadge.fromMap(Map<String, dynamic> map) => AppBadge(
        id: (map['id'] as String?) ?? DateTime.now().microsecondsSinceEpoch.toString(),
        label: (map['label'] as String?) ?? 'عضو مميز',
        icon: (map['icon'] as String?) ?? 'star',
        color: (map['color'] as num?)?.toInt() ?? 0xFFBBA5FF,
        style: (map['style'] as String?) ?? 'gradient',
        imageUrl: map['imageUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'icon': icon,
        'color': color,
        'style': style,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      };
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.bannerUrl,
    this.username,
    this.bio = '',
    this.banned = false,
    this.createdAt,
    this.badges = const [],
    this.verified = false,
    this.verificationStyle = 'classic',
    this.verificationImageUrl,
    this.title = '',
  });

  final String uid;
  final String name;
  final String? photoUrl;
  final String? bannerUrl;
  final String? username;
  final String bio;
  final bool banned;
  final DateTime? createdAt;
  final List<AppBadge> badges;
  final bool verified;
  final String verificationStyle;
  final String? verificationImageUrl;
  final String title;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final rawBadges = m['badges'];
    final badges = rawBadges is List
        ? rawBadges
            .whereType<Map>()
            .map((e) => AppBadge.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <AppBadge>[];
    final displayName = (m['displayName'] as String?)?.trim();
    final storedUsername = (m['username'] as String?)
        ?.trim()
        .replaceFirst(RegExp(r'^@'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final legacyName = (m['name'] as String?)?.trim();
    final emailName = (m['email'] as String?)?.split('@').first.trim();
    // بعض الحسابات القديمة خزّنت UID مكان الاسم؛ لا نعرضه كاسم للمستخدم.
    final resolvedName = [displayName, legacyName, emailName, storedUsername]
        .whereType<String>()
        .map((value) => value.trim())
        .firstWhere((value) => value.isNotEmpty && value != d.id, orElse: () => 'مستخدم');
    final visibleUsername = storedUsername?.isNotEmpty == true && storedUsername != d.id
        ? storedUsername
        : 'lamma_${d.id.substring(0, d.id.length < 6 ? d.id.length : 6)}';
    return AppUser(
      uid: d.id,
      name: resolvedName,
      username: visibleUsername,
      photoUrl: m['photoUrl'] as String?,
      bannerUrl: m['bannerUrl'] as String?,
      bio: (m['bio'] as String?) ?? '',
      banned: m['banned'] == true,
      createdAt: _ts(m['createdAt']),
      badges: badges,
      verified: m['verified'] == true,
      verificationStyle: (m['verificationStyle'] as String?) ?? 'classic',
      verificationImageUrl: m['verificationImageUrl'] as String?,
      title: (m['title'] as String?) ?? '',
    );
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    this.senderPhoto,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String? senderPhoto;

  factory FriendRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return FriendRequest(
      id: d.id,
      senderId: (m['senderId'] as String?) ?? '',
      receiverId: (m['receiverId'] as String?) ?? '',
      senderName: (m['senderName'] as String?) ?? 'مستخدم',
      senderPhoto: m['senderPhoto'] as String?,
    );
  }
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.participants,
    required this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.lastSenderName = '',
    this.readAt,
    this.type = 'direct',
    this.title = '',
    this.photoUrl,
    this.participantNames = const {},
    this.reads = const {},
    this.hiddenMessageIds = const [],
  });

  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final String lastSenderName;
  final DateTime? readAt;
  final String type;
  final String title;
  final String? photoUrl;
  final Map<String, String> participantNames;
  final Map<String, DateTime?> reads;
  final List<String> hiddenMessageIds;

  DateTime? readAtFor(String uid) => reads[uid];

  bool get isGroup => type == 'group';

  String otherOf(String me) =>
      participants.firstWhere((p) => p != me, orElse: () => me);

  bool unreadFor(String me) {
    if (lastSenderId == null || lastSenderId == me || lastMessageAt == null) {
      return false;
    }
    return readAt == null || lastMessageAt!.isAfter(readAt!);
  }

  factory ChatSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> d, String me) {
    final m = d.data() ?? {};
    final rawReads = (m['reads'] as Map?) ?? const {};
    final reads = <String, DateTime?>{};
    rawReads.forEach((key, value) {
      if (key is String) reads[key] = _ts(value);
    });
    final rawHidden = (m['hiddenMessages'] as Map?) ?? const {};
    final hidden = _strings(rawHidden[me]);
    final rawNames = (m['participantNames'] as Map?) ?? const {};
    final names = <String, String>{};
    rawNames.forEach((key, value) {
      if (key is String && value is String) names[key] = value;
    });
    return ChatSummary(
      id: d.id,
      participants: _strings(m['participants']),
      lastMessage: (m['lastMessage'] as String?) ?? '',
      lastMessageAt: _ts(m['lastMessageAt']),
      lastSenderId: m['lastSenderId'] as String?,
      lastSenderName: (m['lastSenderName'] as String?) ?? '',
      readAt: reads[me],
      type: (m['type'] as String?) ?? 'direct',
      title: (m['title'] as String?) ?? '',
      photoUrl: m['photoUrl'] as String?,
      participantNames: names,
      reads: reads,
      hiddenMessageIds: hidden,
    );
  }
}

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
    this.senderName = '',
    this.senderPhoto,
    this.edited = false,
    this.deleted = false,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.reactions = const {},
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  final String senderName;
  final String? senderPhoto;
  final bool edited;
  final bool deleted;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final Map<String, String> reactions;

  factory Message.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final reply = (m['replyTo'] as Map?) ?? const {};
    final rawReactions = (m['reactions'] as Map?) ?? const {};
    final reactions = <String, String>{};
    rawReactions.forEach((key, value) {
      if (key is String && value is String) reactions[key] = value;
    });
    return Message(
      id: d.id,
      senderId: (m['senderId'] as String?) ?? '',
      text: (m['text'] as String?) ?? '',
      createdAt: _ts(m['createdAt']),
      senderName: (m['senderName'] as String?) ?? '',
      senderPhoto: m['senderPhoto'] as String?,
      edited: m['editedAt'] is Timestamp,
      deleted: m['deleted'] == true,
      replyToId: reply['id'] as String?,
      replyToText: reply['text'] as String?,
      replyToSender: reply['sender'] as String?,
      reactions: reactions,
    );
  }
}

class AdminStats {
  const AdminStats({
    required this.users,
    required this.banned,
    required this.newUsers,
  });

  final int users;
  final int banned;
  final int newUsers;
}


class AppEmoji {
  const AppEmoji({
    required this.id,
    required this.emoji,
    required this.label,
    this.enabled = true,
  });

  final String id;
  final String emoji;
  final String label;
  final bool enabled;

  factory AppEmoji.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppEmoji(
      id: doc.id,
      emoji: (data['emoji'] as String?) ?? '✨',
      label: (data['label'] as String?) ?? '',
      enabled: data['enabled'] != false,
    );
  }
}
