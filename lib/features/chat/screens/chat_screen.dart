import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.me, required this.other});
  final AppUser me;
  final AppUser other;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final String _id = Svc.chats.chatId(widget.me.uid, widget.other.uid);
  late final Future<void> _ready = Svc.chats
      .ensureChat(_id, widget.me, widget.other)
      .then((_) => Svc.chats.markRead(_id, widget.me.uid));
  late final Stream<List<Message>> _messages = Svc.chats.watchMessages(_id);

  final _input = TextEditingController();
  String? _lastMarked;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    _input.clear();
    try {
      await _ready;
      await Svc.chats.send(
        _id,
        widget.me.uid,
        widget.other.uid,
        t,
        senderName: widget.me.name,
        senderPhoto: widget.me.photoUrl,
      );
    } catch (_) {
      if (mounted) {
        _input.text = t;
        toast(context, 'ما انرسلت الرسالة، جرّب مرة ثانية.');
      }
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
            UserAvatar(name: widget.other.name, photoUrl: widget.other.photoUrl, size: 40),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(widget.other.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      ),
                      if (widget.other.verified) ...[
                        const SizedBox(width: 5),
                        VerificationMark(style: widget.other.verificationStyle, imageUrl: widget.other.verificationImageUrl, size: 17),
                      ],
                    ],
                  ),
                  const Text('محادثة خاصة', style: TextStyle(color: AppColors.textDim, fontSize: 11)),
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
            radius: 1.3,
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
                      title: 'ما تكدر تراسل هذا الشخص',
                      body: 'المراسلة متاحة بين الأصدقاء فقط.',
                    );
                  }
                  if (rs.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return StreamBuilder<List<Message>>(
                    stream: _messages,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const EmptyState(icon: Icons.cloud_off_rounded, title: 'تعذّر تحميل الرسائل');
                      }
                      final msgs = snap.data;
                      if (msgs == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      if (msgs.isEmpty) {
                        return EmptyState(
                          icon: Icons.waving_hand_rounded,
                          title: 'ابدأ الحديث مع ${widget.other.name}',
                          body: 'رسائلكم الخاصة ما يقدر أحد غيركم يقرأها.',
                        );
                      }
                      final newest = msgs.first;
                      if (newest.senderId != widget.me.uid && _lastMarked != newest.id) {
                        _lastMarked = newest.id;
                        WidgetsBinding.instance.addPostFrameCallback((_) => Svc.chats.markRead(_id, widget.me.uid));
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(15, 18, 15, 18),
                        itemCount: msgs.length,
                        itemBuilder: (context, i) => _Bubble(
                          message: msgs[i],
                          mine: msgs[i].senderId == widget.me.uid,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _Composer(input: _input, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.input, required this.onSend});
  final TextEditingController input;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                        controller: input,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالة…',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton.filled(
                      onPressed: onSend,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.lilac,
                        foregroundColor: AppColors.ink,
                        fixedSize: const Size(45, 45),
                      ),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 21),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(20);
    const sharp = Radius.circular(6);
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        decoration: BoxDecoration(
          gradient: mine
              ? const LinearGradient(colors: [Color(0xFF7651D6), Color(0xFF5635A8)], begin: Alignment.topRight, end: Alignment.bottomLeft)
              : null,
          color: mine ? null : Colors.white.withValues(alpha: .075),
          borderRadius: BorderRadiusDirectional.only(
            topStart: r,
            topEnd: r,
            bottomStart: mine ? sharp : r,
            bottomEnd: mine ? r : sharp,
          ),
          border: Border.all(color: mine ? AppColors.lilac.withValues(alpha: .23) : Colors.white.withValues(alpha: .09)),
          boxShadow: [
            if (mine) BoxShadow(color: AppColors.violet.withValues(alpha: .18), blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.text, style: const TextStyle(fontSize: 15, height: 1.5)),
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
