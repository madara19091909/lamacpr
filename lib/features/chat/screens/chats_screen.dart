import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import 'chat_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppUser>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 13),
          child: Row(
            children: [
              const LammaMark(size: 39),
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
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.lilac.withValues(alpha: .5), width: 1.5),
                ),
                child: UserAvatar(name: me.name, photoUrl: me.photoUrl, size: 39),
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
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'ابحث عن محادثة أو شخص',
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
          padding: const EdgeInsets.fromLTRB(17, 17, 17, 8),
          child: Row(
            children: [
              const Text('رسائلك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const Spacer(),
              _FilterChip(
                label: 'الكل',
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 7),
              _FilterChip(
                label: 'غير مقروءة',
                selected: _filter == 'unread',
                onTap: () => setState(() => _filter = 'unread'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ChatSummary>>(
            stream: _chats,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'تعذّر تحميل المحادثات',
                  body: 'تأكد من اتصالك بالإنترنت وقواعد Firestore.',
                );
              }
              final all = snapshot.data;
              if (all == null) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              final conversations = all.where((chat) {
                // الواجهة الجديدة مخصصة للمحادثات الفردية فقط.
                if (chat.isGroup) return false;
                if (_filter == 'unread' && !chat.unreadFor(me.uid)) return false;
                if (_query.isEmpty) return true;
                final name = chat.participantNames[chat.otherOf(me.uid)] ?? '';
                final preview = '${chat.lastMessage} ${chat.lastSenderName} $name'.toLowerCase();
                return preview.contains(_query) || chat.otherOf(me.uid).contains(_query);
              }).toList();

              if (conversations.isEmpty) {
                return EmptyState(
                  icon: _query.isNotEmpty ? Icons.search_off_rounded : Icons.forum_outlined,
                  title: _query.isNotEmpty
                      ? 'ما لقينا محادثة مطابقة'
                      : _filter == 'unread'
                          ? 'ما عندك رسائل غير مقروءة'
                          : 'بداية حچي جديد',
                  body: _query.isNotEmpty
                      ? 'جرّب تبحث باسم ثاني.'
                      : 'افتح الأشخاص واختار صديق حتى تبدأ محادثة خاصة.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const Padding(
                  padding: EdgeInsetsDirectional.only(start: 77),
                  child: Divider(height: 1, color: AppColors.line),
                ),
                itemBuilder: (context, index) => _ConversationTile(
                  chat: conversations[index],
                  me: me,
                ),
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
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.lilac.withValues(alpha: .17) : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.lilac.withValues(alpha: .42) : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.lilac : AppColors.textDim,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.chat, required this.me});
  final ChatSummary chat;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final otherId = chat.otherOf(me.uid);
    return FutureBuilder<AppUser?>(
      future: Svc.users.byId(otherId),
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
                      MaterialPageRoute<void>(
                        builder: (_) => ChatScreen(me: me, other: other),
                      ),
                    ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(name: name, photoUrl: other?.photoUrl, size: 54),
                      if (unread)
                        PositionedDirectional(
                          bottom: 0,
                          end: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: AppColors.tea,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.ink, width: 2),
                            ),
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
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (other?.verified == true) ...[
                              const SizedBox(width: 5),
                              VerificationMark(
                                style: other!.verificationStyle,
                                imageUrl: other.verificationImageUrl,
                                size: 14,
                              ),
                            ],
                            const Spacer(),
                            Text(
                              clock(chat.lastMessageAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: unread ? AppColors.lilac : AppColors.textDim,
                                fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (mine) ...[
                              Icon(
                                Icons.done_all_rounded,
                                size: 15,
                                color: unread ? AppColors.lilac : AppColors.textDim,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                chat.lastMessage.isEmpty ? 'ابدأوا أول محادثة' : chat.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unread ? AppColors.text : AppColors.textDim,
                                  fontSize: 12,
                                  fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (unread)
                              Container(
                                constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: AppColors.lilac,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.circle, color: AppColors.ink, size: 7),
                                ),
                              ),
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
