import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/emoji_picker.dart';

// حالة الرسالة (للعرض فقط)
enum MessageStatus { sending, sent, read, failed }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.me, required this.other});
  final AppUser me;
  final AppUser other;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late final String _id = Svc.chats.chatId(widget.me.uid, widget.other.uid);
  late final Future<void> _ready = Svc.chats
      .ensureChat(_id, widget.me, widget.other)
      .then((_) => Svc.chats.markRead(_id, widget.me.uid));
  
  late final Stream<List<Message>> _messages = Svc.chats.watchMessages(_id);
  late final Stream<List<AppEmoji>> _emojis = Svc.emojis.watchActive();

  final _input = TextEditingController();
  final _scrollController = ScrollController();
  
  String? _lastMarked;
  Message? _replyingTo;
  bool _isAtBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() => _isAtBottom = _scrollController.offset < 80);
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    } else {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    
    final textToSend = t;
    _input.clear();
    _setReplyingTo(null);
    
    try {
      await _ready;
      await Svc.chats.send(
        _id, widget.me.uid, widget.other.uid, textToSend,
        senderName: widget.me.name,
        senderPhoto: widget.me.photoUrl,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      if (mounted) {
        _input.text = textToSend;
        toast(context, 'فشل الإرسال، تحقق من الاتصال.');
      }
    }
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

  void _setReplyingTo(Message? message) {
    setState(() => _replyingTo = message);
    if (message != null) FocusScope.of(context).unfocus();
  }

  void _copyMessageText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    toast(context, 'تم نسخ النص');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1A), // لون خلفية أعمق وأفخم
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            UserAvatar(name: widget.other.name, photoUrl: widget.other.photoUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.other.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                  const Text('متصل الآن', style: TextStyle(color: AppColors.lilac, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_horiz_rounded, size: 24), onPressed: () {}),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.2,
              colors: [Color(0xFF1E1633), Color(0xFF0F0B1A), Color(0xFF0F0B1A)],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<void>(
                  future: _ready,
                  builder: (context, rs) {
                    if (rs.hasError) return _buildEmptyState(Icons.lock_outline_rounded, 'المراسلة متاحة للأصدقاء فقط');
                    if (rs.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.lilac, strokeWidth: 2));
                    }
                    return StreamBuilder<List<Message>>(
                      stream: _messages,
                      builder: (context, snap) {
                        if (snap.hasError) return _buildEmptyState(Icons.cloud_off_rounded, 'تعذّر تحميل الرسائل');
                        final msgs = snap.data;
                        if (msgs == null) return const Center(child: CircularProgressIndicator(color: AppColors.lilac, strokeWidth: 2));
                        if (msgs.isEmpty) return _buildEmptyState(Icons.waving_hand_rounded, 'ابدأ الحديث مع ${widget.other.name}');

                        final newest = msgs.first;
                        if (newest.senderId != widget.me.uid && _lastMarked != newest.id) {
                          _lastMarked = newest.id;
                          WidgetsBinding.instance.addPostFrameCallback((_) => Svc.chats.markRead(_id, widget.me.uid));
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_isAtBottom) _scrollToBottom(animated: false);
                        });

                        return Stack(
                          children: [
                            ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              itemCount: msgs.length,
                              itemBuilder: (context, i) {
                                final msg = msgs[i];
                                final isMine = msg.senderId == widget.me.uid;
                                return _Bubble(
                                  message: msg,
                                  mine: isMine,
                                  onLongPress: () => _showMessageOptions(context, msg),
                                );
                              },
                            ),
                            if (!_isAtBottom)
                              Positioned(
                                bottom: 24,
                                left: 0, right: 0,
                                child: Center(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _scrollToBottom(),
                                      borderRadius: BorderRadius.circular(24),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.lilac.withValues(alpha: 0.15),
                                          border: Border.all(color: AppColors.lilac.withValues(alpha: 0.3)),
                                          shape: BoxShape.circle,
                                          backdropFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                        ),
                                        child: const Icon(Icons.arrow_downward_rounded, color: AppColors.lilac, size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              
              if (_replyingTo != null) _ReplyPreview(message: _replyingTo!, onClose: () => _setReplyingTo(null)),
              
              _Composer(
                input: _input,
                onSend: _send,
                onEmoji: _showEmojiPicker,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textDim.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(color: AppColors.textDim, fontSize: 15)),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, Message msg) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1528),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            _OptionTile(icon: Icons.reply_rounded, label: 'رد على الرسالة', color: AppColors.lilac, onTap: () { Navigator.pop(ctx); _setReplyingTo(msg); }),
            _OptionTile(icon: Icons.copy_rounded, label: 'نسخ النص', color: Colors.white70, onTap: () { Navigator.pop(ctx); _copyMessageText(msg.text); }),
            if (msg.senderId == widget.me.uid)
              _OptionTile(icon: Icons.delete_outline_rounded, label: 'حذف الرسالة', color: Colors.redAccent, onTap: () => Navigator.pop(ctx)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final Message message;
  final VoidCallback onClose;
  const _ReplyPreview({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1528),
        border: Border(top: BorderSide(color: AppColors.lilac.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 36, decoration: BoxDecoration(color: AppColors.lilac, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الرد على رسالة', style: TextStyle(fontSize: 11, color: AppColors.lilac, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(message.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close_rounded, size: 18, color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.input, required this.onSend, required this.onEmoji});
  final TextEditingController input;
  final VoidCallback onSend;
  final VoidCallback onEmoji;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: onEmoji,
                      icon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.lilac, size: 24),
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: TextField(
                        controller: input,
                        minLines: 1,
                        maxLines: 5,
                        inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالتك هنا...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: input,
                      builder: (context, value, _) {
                        final hasText = value.text.trim().isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          child: hasText
                              ? IconButton.filled(
                                  onPressed: onSend,
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.lilac,
                                    foregroundColor: const Color(0xFF0F0B1A),
                                    fixedSize: const Size(44, 44),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.arrow_upward_rounded, size: 22),
                                )
                              : const SizedBox(width: 44, height: 44), // يحافظ على الحجم لمنع القفز
                        );
                      },
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
  const _Bubble({required this.message, required this.mine, required this.onLongPress});
  final Message message;
  final bool mine;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          decoration: BoxDecoration(
            gradient: mine
                ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: mine ? null : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 6 : 20),
              bottomRight: Radius.circular(mine ? 20 : 6),
            ),
            border: Border.all(
              color: mine ? Colors.transparent : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: mine 
                ? [BoxShadow(color: const Color(0xFF6D28D9).withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6))] 
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message.text, 
                style: TextStyle(
                  fontSize: 15, 
                  height: 1.45, 
                  color: mine ? Colors.white : Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(clock(message.createdAt),
                      style: TextStyle(fontSize: 10.5, color: mine ? Colors.white.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.4))),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all_rounded, size: 15, color: Colors.white70), // يمكن تغيير لونه حسب حالة القراءة
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}