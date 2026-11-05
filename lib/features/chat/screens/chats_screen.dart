import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late final Stream<List<ChatSummary>> _chats =
      Svc.chats.watchChats(context.read<AppUser>().uid);
  final _search = TextEditingController();
  String _query = '';
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _newGroup(AppUser me) async {
    final created = await showModalBottomSheet<(String, String, int)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceHigh,
      builder: (_) => _CreateGroupSheet(me: me),
    );
    if (!mounted || created == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupChatScreen(
          me: me,
          chatId: created.$1,
          title: created.$2,
          memberCount: created.$3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppUser>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المحادثات', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                    SizedBox(height: 3),
                    Text('كل أحاديثك بمكان واحد', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.lilac, Color(0xFF8C70EA)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: .25), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: IconButton(
                  tooltip: 'إنشاء مجموعة',
                  onPressed: () => _newGroup(me),
                  color: AppColors.ink,
                  icon: const Icon(Icons.group_add_rounded),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .055),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: .09)),
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'بحث في المحادثات…',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textDim),
                    suffixIcon: Icon(Icons.tune_rounded, color: AppColors.textDim, size: 19),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 40,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(label: 'الكل', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
              const SizedBox(width: 8),
              _FilterChip(label: 'غير مقروءة', selected: _filter == 'unread', onTap: () => setState(() => _filter = 'unread')),
              const SizedBox(width: 8),
              _FilterChip(label: 'المجموعات', selected: _filter == 'groups', onTap: () => setState(() => _filter = 'groups')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<ChatSummary>>(
            stream: _chats,
            builder: (context, snap) {
              if (snap.hasError) {
                return const EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'ما كدرنا نحمّل المحادثات',
                  body: 'تأكد من نشر الفهارس وقواعد Firestore.',
                );
              }
              final all = snap.data;
              if (all == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              final chats = all.where((chat) {
                if (_filter == 'unread' && !chat.unreadFor(me.uid)) return false;
                if (_filter == 'groups' && !chat.isGroup) return false;
                if (_query.isEmpty) return true;
                final members = chat.participantNames.values.join(' ');
                final text = '${chat.title} $members ${chat.lastMessage} ${chat.lastSenderName}'.toLowerCase();
                return text.contains(_query) || chat.participants.any((p) => p.toLowerCase().contains(_query));
              }).toList();
              if (chats.isEmpty) {
                return EmptyState(
                  icon: _filter == 'groups' ? Icons.groups_2_outlined : Icons.chat_bubble_outline_rounded,
                  title: _query.isNotEmpty
                      ? 'ماكو نتائج مطابقة'
                      : _filter == 'groups'
                          ? 'ما عندك مجموعات بعد'
                          : _filter == 'unread'
                              ? 'كلشي مقروء حالياً'
                              : 'ما عندك محادثات بعد',
                  body: _filter == 'groups'
                      ? 'اضغط زر إنشاء مجموعة واجمع أصدقاءك بمكان واحد.'
                      : 'افتح تبويب الأصدقاء وابدأ محادثة جديدة.',
                  action: _filter == 'groups'
                      ? FilledButton.icon(
                          onPressed: () => _newGroup(me),
                          icon: const Icon(Icons.group_add_rounded),
                          label: const Text('إنشاء مجموعة'),
                        )
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 22),
                itemCount: chats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 5),
                itemBuilder: (context, i) => _ChatRow(chat: chats[i], me: me),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.lilac.withValues(alpha: .18) : AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? AppColors.lilac.withValues(alpha: .5) : AppColors.line),
          ),
          child: Text(label,
              style: TextStyle(color: selected ? AppColors.lilac : AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      );
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat, required this.me});
  final ChatSummary chat;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    if (chat.isGroup) return _row(context, title: chat.title, photoUrl: chat.photoUrl, isGroup: true);
    return FutureBuilder<AppUser?>(
      future: Svc.users.byId(chat.otherOf(me.uid)),
      builder: (context, snap) {
        final other = snap.data;
        if (other == null) return const SizedBox(height: 82);
        return _row(context, title: other.name, photoUrl: other.photoUrl, other: other);
      },
    );
  }

  Widget _row(BuildContext context, {
    required String title,
    String? photoUrl,
    AppUser? other,
    bool isGroup = false,
  }) {
    final unread = chat.unreadFor(me.uid);
    final mine = chat.lastSenderId == me.uid;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () {
          if (isGroup) {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => GroupChatScreen(me: me, chatId: chat.id, title: title, memberCount: chat.participants.length),
            ));
          } else if (other != null) {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ChatScreen(me: me, other: other),
            ));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          decoration: BoxDecoration(
            color: unread ? Colors.white.withValues(alpha: .065) : Colors.white.withValues(alpha: .025),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: unread ? AppColors.lilac.withValues(alpha: .16) : Colors.white.withValues(alpha: .035)),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isGroup)
                    Container(
                      width: 53,
                      height: 53,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.violet, Color(0xFF347D8F)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.groups_rounded, color: Colors.white, size: 27),
                    )
                  else
                    UserAvatar(name: title, photoUrl: photoUrl, size: 53),
                  if (unread)
                    PositionedDirectional(
                      bottom: -2,
                      end: -2,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(color: AppColors.tea, shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 2)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                        ),
                        if (other?.verified == true) ...[
                          const SizedBox(width: 5),
                          VerificationMark(style: other!.verificationStyle, imageUrl: other!.verificationImageUrl, size: 15),
                        ],
                        if (isGroup) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.groups_2_rounded, size: 14, color: AppColors.textDim),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      chat.isGroup && chat.lastSenderName.isNotEmpty
                          ? '${mine ? 'أنت' : chat.lastSenderName}: ${chat.lastMessage}'
                          : mine
                              ? 'أنت: ${chat.lastMessage}'
                              : chat.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread ? AppColors.text : AppColors.textDim,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(timeAgo(chat.lastMessageAt),
                      style: TextStyle(color: unread ? AppColors.tea : AppColors.textDim, fontSize: 10, fontWeight: unread ? FontWeight.w800 : FontWeight.w500)),
                  const SizedBox(height: 8),
                  if (unread)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.lilac, borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.done_all_rounded, color: AppColors.ink, size: 11),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.me});
  final AppUser me;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _title = TextEditingController();
  final Set<String> _selected = {};
  late final Stream<Set<String>> _friends = Svc.friends.watchFriendIds(widget.me.uid);
  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_selected.length < 2) {
      toast(context, 'اختَر صديقين على الأقل.');
      return;
    }
    setState(() => _creating = true);
    try {
      final title = _title.text.trim();
      final id = await Svc.chats.createGroup(
        title: title,
        memberIds: _selected.toList(),
        creatorId: widget.me.uid,
      );
      if (mounted) Navigator.pop(context, (id, title, _selected.length + 1));
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        toast(context, e is ArgumentError ? e.message.toString() : 'ما كدرنا ننشئ المجموعة.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: .2), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.group_add_rounded, color: AppColors.lilac),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مجموعة جديدة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        Text('اجمع أصدقاءك بمحادثة واحدة', style: TextStyle(fontSize: 11, color: AppColors.textDim)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _title,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'اسم المجموعة', hintText: 'مثلاً: شلة الأصدقاء', counterText: ''),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  const Expanded(child: Text('اختَر الأعضاء', style: TextStyle(fontWeight: FontWeight.w900))),
                  Text('${_selected.length} محدد', style: const TextStyle(color: AppColors.lilac, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<Set<String>>(
                stream: _friends,
                builder: (context, snap) {
                  final ids = snap.data;
                  if (ids == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  if (ids.isEmpty) {
                    return const EmptyState(icon: Icons.people_outline_rounded, title: 'ما عندك أصدقاء بعد', body: 'أضف أصدقاء أولاً حتى تكدر تسوي مجموعة.');
                  }
                  return ListView.builder(
                    itemCount: ids.length,
                    itemBuilder: (context, i) {
                      final id = ids.elementAt(i);
                      return FutureBuilder<AppUser?>(
                        future: Svc.users.byId(id),
                        builder: (context, userSnap) {
                          final user = userSnap.data;
                          if (user == null) return const SizedBox(height: 61);
                          return CheckboxListTile(
                            value: _selected.contains(id),
                            activeColor: AppColors.lilac,
                            checkColor: AppColors.ink,
                            onChanged: (checked) => setState(() {
                              if (checked == true && _selected.length < 49) _selected.add(id);
                              if (checked != true) _selected.remove(id);
                            }),
                            secondary: UserAvatar(name: user.name, photoUrl: user.photoUrl, size: 40),
                            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            subtitle: Text(user.bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
                            controlAffinity: ListTileControlAffinity.trailing,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _creating ? null : _create,
                  icon: _creating
                      ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                      : const Icon(Icons.arrow_back_rounded),
                  label: Text(_creating ? 'جاري الإنشاء…' : 'إنشاء المجموعة (${_selected.length + 1})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
