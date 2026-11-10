import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import '../../profile/screens/profile_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  AppUser get _me => context.read<AppUser>();
  late final String _uid = context.read<AppUser>().uid;
  late final Stream<List<ChatSummary>> _chats = Svc.chats.watchChats(_uid);
  late final Stream<Set<String>> _friendIds = Svc.friends.watchFriendIds(_uid);
  late final Stream<Set<String>> _sentIds = Svc.friends.watchSentIds(_uid);

  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _filter = 'all';
  Future<List<AppUser>>? _peopleResults;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _query = value.trim();
      _peopleResults = null;
    });
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _peopleResults = _query.length < 2 ? null : Svc.users.search(_query, _me.uid);
      });
    });
  }

  void _openDirect(AppUser other) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatScreen(me: _me, other: other)),
    );
  }

  void _openGroup(ChatSummary chat) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupChatScreen(
          me: _me,
          chatId: chat.id,
          title: chat.title.isEmpty ? 'مجموعة لَمّة' : chat.title,
          memberCount: chat.participants.length,
        ),
      ),
    );
  }

  Future<List<AppUser>> _loadGroupCandidates() async {
    final ids = await Svc.friends
        .watchFriendIds(_me.uid)
        .first
        .timeout(const Duration(seconds: 15));
    final loaded = await Future.wait<AppUser?>(ids.map(Svc.users.byId));
    final users = loaded.whereType<AppUser>().toList();
    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  Future<void> _createGroup() async {
    final title = TextEditingController();
    final selected = <String>{};
    // تُحمّل قائمة الأصدقاء مرة واحدة قبل فتح الواجهة. لا نعيد تشغيل FutureBuilder
    // عند تحديد كل عضو، لأن ذلك كان يعيد دوران القائمة ويمنع الاختيار المستقر.
    final candidatesFuture = _loadGroupCandidates();
    final newChatId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .84,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Row(
                    children: [
                      Icon(Icons.group_add_rounded, color: AppColors.lilac),
                      SizedBox(width: 9),
                      Text('إنشاء مجموعة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: TextField(
                    controller: title,
                    maxLength: 40,
                    onChanged: (_) => refresh(() {}),
                    decoration: const InputDecoration(
                      hintText: 'اسم المجموعة',
                      prefixIcon: Icon(Icons.edit_rounded),
                      counterText: '',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 15, 20, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('اختَر الأصدقاء',
                            style: TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                      Text('${selected.length}/49',
                          style: const TextStyle(color: AppColors.lilac, fontWeight: FontWeight.w900, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<AppUser>>(
                    future: candidatesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'تعذّر تحميل الأصدقاء',
                          body: 'تأكد من اتصالك بالإنترنت وصلاحيات قراءة جهات الاتصال. ${snapshot.error}',
                        );
                      }
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      final users = snapshot.data ?? const <AppUser>[];
                      if (users.isEmpty) {
                        return const EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'ما عندك أصدقاء بعد',
                          body: 'أضف أصدقاء من صفحة جهات الاتصال حتى تسوي مجموعة.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final checked = selected.contains(user.uid);
                          return CheckboxListTile(
                            key: ValueKey(user.uid),
                            value: checked,
                            onChanged: (value) => refresh(() {
                              if (value == true) {
                                if (selected.length < 49) selected.add(user.uid);
                              } else {
                                selected.remove(user.uid);
                              }
                            }),
                            secondary: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => PublicProfileScreen(uid: user.uid),
                              )),
                              child: UserAvatar(name: user.name, photoUrl: user.photoUrl, size: 43),
                            ),
                            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('@${user.username ?? user.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            activeColor: AppColors.lilac,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            controlAffinity: ListTileControlAffinity.trailing,
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${selected.length} أصدقاء محددين • تحتاج صديقاً واحداً على الأقل',
                            style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                      ),
                      FilledButton.icon(
                        onPressed: selected.isEmpty || title.text.trim().length < 2
                            ? null
                            : () async {
                                try {
                                  final groupTitle = title.text.trim();
                                  final names = <String, String>{
                                    for (final user in (await candidatesFuture).where((u) => selected.contains(u.uid)))
                                      user.uid: user.name,
                                    _me.uid: _me.name,
                                  };
                                  final id = await Svc.chats.createGroup(
                                    title: groupTitle,
                                    memberIds: selected.toList(),
                                    creatorId: _me.uid,
                                    creatorName: _me.name,
                                    memberNames: names,
                                  );
                                  if (sheetContext.mounted) Navigator.pop(sheetContext, id);
                                } catch (error) {
                                  if (sheetContext.mounted) {
                                    final message = error is ArgumentError
                                        ? error.message.toString()
                                        : 'تعذّر إنشاء المجموعة: $error';
                                    toast(sheetContext, message);
                                  }
                                }
                              },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('إنشاء'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final groupTitle = title.text.trim();
    // نؤخر dispose حتى تنتهي أنيميشن إغلاق النافذة.
    Future<void>.delayed(const Duration(milliseconds: 500), title.dispose);
    if (newChatId != null && mounted) {
      _openGroup(ChatSummary(
        id: newChatId,
        participants: [...selected, _me.uid],
        lastMessage: 'تم إنشاء المجموعة',
        lastSenderName: _me.name,
        lastSenderId: _me.uid,
        type: 'group',
        title: groupTitle,
      ));
    }
  }

  Future<void> _handlePeopleTap(AppUser user, Set<String> friends, Set<String> sent) async {
    if (friends.contains(user.uid)) {
      _openDirect(user);
      return;
    }
    if (sent.contains(user.uid)) {
      toast(context, 'طلب الصداقة مرسل مسبقاً.');
      return;
    }
    try {
      await Svc.friends.sendRequest(_me, user.uid);
      if (mounted) toast(context, 'تم إرسال طلب الصداقة.');
    } catch (_) {
      if (mounted) toast(context, 'ما كدرنا نرسل الطلب. جرّب من صفحة الأصدقاء.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // نراقب العضو حتى يتحدث الاسم/الصورة أعلى الصفحة فوراً.
    context.watch<AppUser>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 13),
          child: Row(
            children: [
              const LammaMark(size: 41),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لَمّة', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.4)),
                    SizedBox(height: 1),
                    Text('قريبين، حتى لو بعيدين', style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'إنشاء مجموعة',
                onPressed: _createGroup,
                style: IconButton.styleFrom(backgroundColor: AppColors.surfaceHigh, foregroundColor: AppColors.lilac),
                icon: const Icon(Icons.group_add_rounded),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.lilac.withValues(alpha: .5), width: 1.5),
                ),
                child: UserAvatar(name: _me.name, photoUrl: _me.photoUrl, size: 39),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.line.withValues(alpha: .9)),
            ),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'ابحث عن محادثة أو اسم مستخدم',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textDim),
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 15, 17, 10),
          child: Row(
            children: [
              const Text('رسائلك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _FilterChip(label: 'الكل', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                      const SizedBox(width: 7),
                      _FilterChip(label: 'غير مقروءة', selected: _filter == 'unread', onTap: () => setState(() => _filter = 'unread')),
                      const SizedBox(width: 7),
                      _FilterChip(label: 'المجموعات', selected: _filter == 'groups', onTap: () => setState(() => _filter = 'groups')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ChatSummary>>(
            stream: _chats,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'تعذّر تحميل المحادثات',
                  body: 'خطأ Firestore: ${snapshot.error}',
                );
              }
              final all = snapshot.data;
              if (all == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              final conversations = all.where((chat) {
                if (_filter == 'groups' && !chat.isGroup) return false;
                if (_filter == 'unread' && !chat.unreadFor(_me.uid)) return false;
                if (_query.isEmpty) return true;
                final otherId = chat.isGroup ? '' : chat.otherOf(_me.uid);
                final name = chat.isGroup
                    ? chat.title
                    : (chat.participantNames[otherId] ?? '');
                final preview = '${chat.lastMessage} ${chat.lastSenderName} $name'.toLowerCase();
                return preview.contains(_query.toLowerCase()) || otherId.contains(_query);
              }).toList();

              return StreamBuilder<Set<String>>(
                stream: _friendIds,
                builder: (context, friendsSnapshot) => StreamBuilder<Set<String>>(
                  stream: _sentIds,
                  builder: (context, sentSnapshot) {
                    final friends = friendsSnapshot.data ?? <String>{};
                    final sent = sentSnapshot.data ?? <String>{};
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
                      children: [
                        if (_query.length >= 2) ...[
                          const SectionLabel('الأشخاص'),
                          _PeopleSearchResults(
                            future: _peopleResults,
                            friends: friends,
                            sent: sent,
                            onTap: (user) => _handlePeopleTap(user, friends, sent),
                          ),
                          const SectionLabel('المحادثات المطابقة'),
                        ],
                        if (conversations.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: EmptyState(
                              icon: _query.isNotEmpty ? Icons.search_off_rounded : Icons.forum_outlined,
                              title: _query.isNotEmpty
                                  ? 'ما لقينا محادثة مطابقة'
                                  : _filter == 'groups'
                                      ? 'ما عندك مجموعات بعد'
                                      : _filter == 'unread'
                                          ? 'ما عندك رسائل غير مقروءة'
                                          : 'بداية حچي جديد',
                              body: _query.isNotEmpty
                                  ? 'تأكد من الاسم أو جرّب البحث باسم المستخدم.'
                                  : _filter == 'groups'
                                      ? 'اضغط زر إنشاء مجموعة حتى تجمع أصدقاءك.'
                                      : 'افتح جهات الاتصال واختار صديق حتى تبدأ محادثة.',
                            ),
                          )
                        else
                          for (final chat in conversations)
                            chat.isGroup
                                ? _GroupConversationTile(chat: chat, me: _me, onTap: () => _openGroup(chat))
                                : _ConversationTile(chat: chat, me: _me),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PeopleSearchResults extends StatelessWidget {
  const _PeopleSearchResults({
    required this.future,
    required this.friends,
    required this.sent,
    required this.onTap,
  });

  final Future<List<AppUser>>? future;
  final Set<String> friends;
  final Set<String> sent;
  final ValueChanged<AppUser> onTap;

  @override
  Widget build(BuildContext context) {
    if (future == null) return const SizedBox(height: 8);
    return FutureBuilder<List<AppUser>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('تعذّر البحث عن الأشخاص: ${snapshot.error}',
                style: const TextStyle(color: AppColors.danger, fontSize: 11)),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final users = snapshot.data ?? const <AppUser>[];
        if (users.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('ما لقينا حسابات بهذا الاسم.', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          );
        }
        return Column(
          children: [
            for (final user in users)
              PersonRow(
                name: user.name,
                photoUrl: user.photoUrl,
                verified: user.verified,
                verificationStyle: user.verificationStyle,
                verificationImageUrl: user.verificationImageUrl,
                subtitle: '@${user.username ?? user.name}',
                onTap: () => onTap(user),
                onAvatarTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PublicProfileScreen(uid: user.uid),
                )),
                trailing: TextButton(
                  onPressed: () => onTap(user),
                  child: Text(friends.contains(user.uid) ? 'مراسلة' : sent.contains(user.uid) ? 'مرسل' : 'إضافة'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.lilac.withValues(alpha: .17) : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? AppColors.lilac.withValues(alpha: .42) : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.lilac : AppColors.textDim,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String _chatPreview(String text) => text.replaceAll(
  RegExp(r'\[\[lamma_emoji:[^\]]+\]\]'),
  'إيموجي مخصص',
);

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.chat, required this.me});
  final ChatSummary chat;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final otherId = chat.otherOf(me.uid);
    return StreamBuilder<AppUser?>(
      stream: Svc.users.watch(otherId),
      builder: (context, snapshot) {
        final other = snapshot.data;
        final name = other?.name ?? chat.participantNames[otherId] ?? 'مستخدم';
        final unread = chat.unreadFor(me.uid);
        final mine = chat.lastSenderId == me.uid;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: other == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => ChatScreen(me: me, other: other)),
                    ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
              child: Row(
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: other == null ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => PublicProfileScreen(uid: other.uid),
                    )),
                    child: UserAvatar(name: name, photoUrl: other?.photoUrl, size: 54),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, fontWeight: unread ? FontWeight.w900 : FontWeight.w700)),
                            ),
                            if (other?.verified == true) ...[
                              const SizedBox(width: 5),
                              VerificationMark(style: other!.verificationStyle, imageUrl: other.verificationImageUrl, size: 14),
                            ],
                            const Spacer(),
                            Text(clock(chat.lastMessageAt),
                                style: TextStyle(fontSize: 10, color: unread ? AppColors.lilac : AppColors.textDim)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (mine) ...[
                              Icon(Icons.done_all_rounded, size: 15,
                                  color: chat.readAtFor(otherId) != null &&
                                          chat.lastMessageAt != null &&
                                          !chat.readAtFor(otherId)!.isBefore(chat.lastMessageAt!)
                                      ? AppColors.tea
                                      : AppColors.textDim),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                chat.lastMessage.isEmpty ? 'ابدأوا أول محادثة' : _chatPreview(chat.lastMessage),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unread ? AppColors.text : AppColors.textDim,
                                  fontSize: 12,
                                  fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (unread) const Icon(Icons.circle, color: AppColors.lilac, size: 9),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupConversationTile extends StatelessWidget {
  const _GroupConversationTile({required this.chat, required this.me, required this.onTap});
  final ChatSummary chat;
  final AppUser me;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadFor(me.uid);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.violet, Color(0xFF3D8E9B)]),
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 27),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(chat.title.isEmpty ? 'مجموعة لَمّة' : chat.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: unread ? FontWeight.w900 : FontWeight.w700)),
                      ),
                      Text(clock(chat.lastMessageAt), style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage.isEmpty ? '${chat.participants.length} أعضاء' : '${chat.lastSenderName.isEmpty ? '' : '${chat.lastSenderName}: '}${_chatPreview(chat.lastMessage)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: unread ? AppColors.text : AppColors.textDim, fontSize: 12),
                        ),
                      ),
                      if (unread) const Icon(Icons.circle, color: AppColors.lilac, size: 9),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
