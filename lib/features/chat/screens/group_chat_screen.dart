import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.me,
    required this.chatId,
    required this.title,
    required this.memberCount,
  });

  final AppUser me;
  final String chatId;
  final String title;
  final int memberCount;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  late final Future<void> _ready = Svc.chats.markRead(widget.chatId, widget.me.uid);
  late final Stream<List<Message>> _messages = Svc.chats.watchMessages(widget.chatId);
  final _input = TextEditingController();
  String? _lastMarked;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await Svc.chats.sendGroup(widget.chatId, widget.me, text);
    } catch (_) {
      if (mounted) {
        _input.text = text;
        toast(context, 'ما انرسلت الرسالة. تحقق من اتصالك وجرّب مرة ثانية.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.ink.withValues(alpha: .92),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.violet, Color(0xFF3D8E9B)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  Text('${widget.memberCount} أعضاء • مجموعة',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.25,
            colors: [Color(0xFF25203B), AppColors.ink, AppColors.ink],
          ),
        ),
        child: Column(
          children: [
            Container(height: 1, color: AppColors.line.withValues(alpha: .7)),
            Expanded(
              child: FutureBuilder<void>(
                future: _ready,
                builder: (context, rs) {
                  if (rs.hasError) {
                    return const EmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'ما تكدر تفتح المجموعة',
                      body: 'تأكد أن حسابك عضو بالمجموعة وأن قواعد Firestore منشورة.',
                    );
                  }
                  if (rs.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return StreamBuilder<List<Message>>(
                    stream: _messages,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const EmptyState(icon: Icons.cloud_off_rounded, title: 'تعذّر تحميل رسائل المجموعة');
                      }
                      final messages = snap.data;
                      if (messages == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      if (messages.isEmpty) {
                        return const EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'بداية المجموعة',
                          body: 'اكتب أول رسالة وابدأوا الحديث مع بعض.',
                        );
                      }
                      final newest = messages.first;
                      if (newest.senderId != widget.me.uid && _lastMarked != newest.id) {
                        _lastMarked = newest.id;
                        WidgetsBinding.instance.addPostFrameCallback((_) => Svc.chats.markRead(widget.chatId, widget.me.uid));
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                        itemCount: messages.length,
                        itemBuilder: (context, i) => _GroupBubble(
                          message: messages[i],
                          mine: messages[i].senderId == widget.me.uid,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(27),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 7, 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .075),
                        borderRadius: BorderRadius.circular(27),
                        border: Border.all(color: Colors.white.withValues(alpha: .13)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                hintText: 'اكتب للمجموعة…',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                              ),
                            ),
                          ),
                          IconButton.filled(
                            onPressed: _sending ? null : _send,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.lilac,
                              foregroundColor: AppColors.ink,
                              fixedSize: const Size(45, 45),
                            ),
                            icon: _sending
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                                : const Icon(Icons.arrow_upward_rounded, size: 21),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupBubble extends StatelessWidget {
  const _GroupBubble({required this.message, required this.mine});
  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(19);
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        decoration: BoxDecoration(
          gradient: mine
              ? const LinearGradient(colors: [Color(0xFF7651D6), Color(0xFF5635A8)])
              : null,
          color: mine ? null : Colors.white.withValues(alpha: .075),
          borderRadius: BorderRadiusDirectional.only(
            topStart: r,
            topEnd: r,
            bottomStart: mine ? const Radius.circular(5) : r,
            bottomEnd: mine ? r : const Radius.circular(5),
          ),
          border: Border.all(color: mine ? AppColors.lilac.withValues(alpha: .2) : Colors.white.withValues(alpha: .09)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine && message.senderName.isNotEmpty) ...[
              Text(message.senderName,
                  style: const TextStyle(color: AppColors.tea, fontSize: 11, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
            ],
            Text(message.text, style: const TextStyle(fontSize: 14.5, height: 1.5)),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(clock(message.createdAt),
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: mine ? .72 : .48))),
            ),
          ],
        ),
      ),
    );
  }
}
