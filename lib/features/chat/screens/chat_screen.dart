import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/emoji_picker.dart';
import '../widgets/chat_message_bubble.dart';

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
  late final Stream<List<AppEmoji>> _emojis = Svc.emojis.watchActive();
  late final Stream<ChatSummary?> _chat = Svc.chats.watchChat(_id, widget.me.uid);
  late final Stream<bool> _typing = Svc.chats.watchTyping(_id, widget.other.uid);

  final _input = TextEditingController();
  Timer? _typingTimer;
  bool _typingActive = false;
  bool _sending = false;
  String? _lastMarked;
  Message? _replyingTo;
  Message? _editing;

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_typingActive) {
      _saveTyping(false);
    }
    _input.dispose();
    super.dispose();
  }

  void _saveTyping(bool value) {
    _ready.then((_) => Svc.chats.setTyping(_id, widget.me.uid, value)).catchError((_) {});
  }

  void _onInputChanged(String value) {
    _typingTimer?.cancel();
    if (value.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (!_typingActive) {
      _typingActive = true;
      _saveTyping(true);
    }
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (!_typingActive) return;
    _typingActive = false;
    _saveTyping(false);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _ready;
      if (_editing != null) {
        await Svc.chats.editMessage(_id, _editing!.id, text);
        if (mounted) toast(context, 'تم تعديل الرسالة.');
      } else {
        await Svc.chats.send(
          _id,
          widget.me.uid,
          widget.other.uid,
          text,
          senderName: widget.me.name,
          senderPhoto: widget.me.photoUrl,
          replyTo: _replyingTo,
        );
      }
      _input.clear();
      _stopTyping();
      if (mounted) {
        setState(() {
          _replyingTo = null;
          _editing = null;
        });
      }
    } catch (error) {
      if (mounted) {
        toast(context, _friendlyError(error, 'ما انرسلت الرسالة. تحقق من الصداقة وقواعد Firestore.'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendlyError(Object error, String fallback) {
    if (error is ArgumentError) return error.message?.toString() ?? fallback;
    return fallback;
  }

  void _insertEmoji(String emoji) {
    final oldText = _input.text;
    final selection = _input.selection;
    final start = selection.start < 0 ? oldText.length : selection.start;
    final end = selection.end < 0 ? oldText.length : selection.end;
    final next = oldText.replaceRange(start, end, emoji);
    _input.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _showEmojiPicker() async {
    final selected = await showLammaEmojiPicker(context, _emojis);
    if (selected != null && mounted) _insertEmoji(selected);
  }

  Future<void> _showMessageActions(Message message) async {
    final mine = message.senderId == widget.me.uid;
    final action = await showChatMessageMenu(
      context,
      mine: mine,
      deleted: message.deleted,
    );
    if (!mounted || action == null) return;

    if (action.startsWith('react:')) {
      await _react(message, action.substring(6));
      return;
    }
    switch (action) {
      case 'copy':
        if (!message.deleted) {
          await Clipboard.setData(ClipboardData(text: message.text));
          if (mounted) toast(context, 'تم نسخ الرسالة.');
        }
        break;
      case 'reply':
        setState(() {
          _replyingTo = message;
          _editing = null;
        });
        break;
      case 'edit':
        if (!mine || message.deleted) return;
        setState(() {
          _editing = message;
          _replyingTo = null;
          _input.text = message.text;
          _input.selection = TextSelection.collapsed(offset: _input.text.length);
        });
        break;
      case 'delete':
        if (!mine) return;
        final confirmed = await confirmDialog(
          context,
          title: 'حذف الرسالة؟',
          body: 'راح تظهر للطرف الثاني كرسالة محذوفة.',
          ok: 'حذف',
          danger: true,
        );
        if (confirmed) {
          try {
            await Svc.chats.deleteMessage(_id, message.id);
          } catch (_) {
            if (mounted) toast(context, 'ما كدرنا نحذف الرسالة.');
          }
        }
        break;
      case 'hide':
        try {
          await Svc.chats.hideMessage(_id, widget.me.uid, message.id);
        } catch (_) {
          if (mounted) toast(context, 'ما كدرنا نمسح الرسالة من عندك.');
        }
        break;
    }
  }

  Future<void> _react(Message message, String emoji) async {
    try {
      await Svc.chats.toggleReaction(_id, message.id, widget.me.uid, emoji);
    } catch (_) {
      if (mounted) toast(context, 'تعذرت إضافة التفاعل.');
    }
  }

  void _markConversationRead(List<Message> messages) {
    if (messages.isEmpty) return;
    final newest = messages.first;
    if (newest.senderId != widget.me.uid && _lastMarked != newest.id) {
      _lastMarked = newest.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Svc.chats.markRead(_id, widget.me.uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.ink.withValues(alpha: .96),
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(name: widget.other.name, photoUrl: widget.other.photoUrl, size: 42),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.other.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (widget.other.verified) ...[
                        const SizedBox(width: 5),
                        VerificationMark(
                          style: widget.other.verificationStyle,
                          imageUrl: widget.other.verificationImageUrl,
                          size: 17,
                        ),
                      ],
                    ],
                  ),
                  FutureBuilder<void>(
                    future: _ready,
                    builder: (context, ready) {
                      if (ready.connectionState != ConnectionState.done || ready.hasError) {
                        return const Text('محادثة خاصة', style: TextStyle(color: AppColors.textDim, fontSize: 10));
                      }
                      return StreamBuilder<bool>(
                        stream: _typing,
                        builder: (context, snapshot) => Text(
                          snapshot.data == true ? 'يكتب الآن...' : 'محادثة خاصة',
                          style: TextStyle(
                            color: snapshot.data == true ? AppColors.tea : AppColors.textDim,
                            fontSize: 10,
                            fontWeight: snapshot.data == true ? FontWeight.w800 : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
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
            radius: 1.35,
            colors: [Color(0xFF29213F), AppColors.ink, AppColors.ink],
          ),
        ),
        child: Column(
          children: [
            Container(height: 1, color: AppColors.line.withValues(alpha: .7)),
            Expanded(
              child: FutureBuilder<void>(
                future: _ready,
                builder: (context, ready) {
                  if (ready.hasError) {
                    return const EmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'ما تكدر تراسل هذا الشخص',
                      body: 'تأكد أن طلب الصداقة مقبول وأن قواعد Firestore منشورة.',
                    );
                  }
                  if (ready.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return StreamBuilder<ChatSummary?>(
                    stream: _chat,
                    builder: (context, chatSnapshot) {
                      if (chatSnapshot.hasError) {
                        return const EmptyState(icon: Icons.cloud_off_rounded, title: 'تعذّر تحميل حالة المحادثة');
                      }
                      final chat = chatSnapshot.data;
                      return StreamBuilder<List<Message>>(
                        stream: _messages,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const EmptyState(
                              icon: Icons.cloud_off_rounded,
                              title: 'تعذّر تحميل الرسائل',
                              body: 'راجع صلاحيات قراءة الرسائل في قواعد Firestore.',
                            );
                          }
                          final allMessages = snapshot.data;
                          if (allMessages == null) {
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          }
                          _markConversationRead(allMessages);
                          final hidden = chat?.hiddenMessageIds.toSet() ?? <String>{};
                          final messages = allMessages.where((m) => !hidden.contains(m.id)).toList();
                          if (messages.isEmpty) {
                            return EmptyState(
                              icon: Icons.waving_hand_rounded,
                              title: 'ابدأ الحديث مع ${widget.other.name}',
                              body: 'اضغط مطولاً على أي رسالة حتى ترد أو تتفاعل وياها.',
                            );
                          }
                          final otherReadAt = chat?.readAtFor(widget.other.uid);
                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(15, 18, 15, 18),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isLatestMine = index == 0 && message.senderId == widget.me.uid;
                              final isRead = isLatestMine &&
                                  otherReadAt != null &&
                                  message.createdAt != null &&
                                  !otherReadAt.isBefore(message.createdAt!);
                              return ChatMessageBubble(
                                message: message,
                                mine: message.senderId == widget.me.uid,
                                myUid: widget.me.uid,
                                isRead: isRead,
                                onLongPress: () => _showMessageActions(message),
                                onReaction: (emoji) => _react(message, emoji),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            _Composer(
              input: _input,
              onSend: _send,
              onEmoji: _showEmojiPicker,
              onChanged: _onInputChanged,
              onCancelContext: () => setState(() {
                _replyingTo = null;
                _editing = null;
                _input.clear();
              }),
              contextMessage: _editing ?? _replyingTo,
              editing: _editing != null,
              sending: _sending,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.onSend,
    required this.onEmoji,
    required this.onChanged,
    required this.onCancelContext,
    required this.contextMessage,
    required this.editing,
    required this.sending,
  });

  final TextEditingController input;
  final VoidCallback onSend;
  final VoidCallback onEmoji;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancelContext;
  final Message? contextMessage;
  final bool editing;
  final bool sending;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppColors.lilac.withValues(alpha: .18)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (contextMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(6, 3, 6, 5),
                        padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 6, 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(12),
                          border: const BorderDirectional(start: BorderSide(color: AppColors.tea, width: 3)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    editing ? 'تعديل الرسالة' : 'الرد على ${contextMessage!.senderName}',
                                    style: const TextStyle(color: AppColors.tea, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    contextMessage!.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textDim),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: onCancelContext,
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textDim),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'إيموجيات لَمّة',
                          onPressed: onEmoji,
                          icon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.lilac, size: 23),
                        ),
                        Expanded(
                          child: TextField(
                            controller: input,
                            minLines: 1,
                            maxLines: 5,
                            onChanged: onChanged,
                            inputFormatters: [LengthLimitingTextInputFormatter(2000)],
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
                        const SizedBox(width: 4),
                        IconButton.filled(
                          onPressed: sending ? null : onSend,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.lilac,
                            foregroundColor: AppColors.ink,
                            fixedSize: const Size(45, 45),
                          ),
                          icon: sending
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                              : Icon(editing ? Icons.check_rounded : Icons.arrow_upward_rounded, size: 21),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
