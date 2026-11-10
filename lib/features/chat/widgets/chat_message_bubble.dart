import '../../../core/widgets/sticker_text_controller.dart';
import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/screens/profile_screen.dart';

enum ChatMessageAction { copy, reply, hide, edit, delete }

Future<String?> showChatMessageMenu(
  BuildContext context, {
  required bool mine,
  required bool deleted,
}) {
  const quickReactions = ['❤️', '😂', '👍', '😮', '😢', '🔥'];
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceHigh,
    isScrollControlled: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('تفاعل ويا الرسالة', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final emoji in quickReactions)
                InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => Navigator.pop(sheetContext, 'react:$emoji'),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Text(emoji, style: const TextStyle(fontSize: 25)),
                  ),
                ),
            ],
          ),
          const Divider(height: 22),
          if (mine && !deleted)
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.lilac),
              title: const Text('تعديل الرسالة'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
          ListTile(
            leading: const Icon(Icons.reply_rounded, color: AppColors.lilac),
            title: const Text('رد'),
            onTap: () => Navigator.pop(sheetContext, 'reply'),
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded, color: AppColors.textDim),
            title: const Text('نسخ'),
            onTap: () => Navigator.pop(sheetContext, 'copy'),
          ),
          if (!deleted)
            ListTile(
              leading: Icon(
                mine ? Icons.delete_forever_rounded : Icons.visibility_off_rounded,
                color: AppColors.danger,
              ),
              title: Text(mine ? 'حذف للجميع' : 'مسح من عندي'),
              subtitle: Text(
                mine ? 'راح تنحذف الرسالة من المحادثة' : 'راح تختفي من محادثتك فقط',
                style: const TextStyle(color: AppColors.textDim, fontSize: 11),
              ),
              onTap: () => Navigator.pop(sheetContext, mine ? 'delete' : 'hide'),
            ),
        ],
      ),
    ),
  );
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.myUid,
    required this.onLongPress,
    required this.onReaction,
    this.showSender = false,
    this.isRead = false,
  });

  final Message message;
  final bool mine;
  final String myUid;
  final VoidCallback onLongPress;
  final ValueChanged<String> onReaction;
  final bool showSender;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(21);
    const sharp = Radius.circular(6);
    final counts = <String, int>{};
    for (final emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onTap: onLongPress,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            gradient: mine
                ? const LinearGradient(
                    colors: [Color(0xFF7957D9), Color(0xFF5032A0)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : null,
            color: mine ? null : AppColors.surfaceHigh.withValues(alpha: .96),
            borderRadius: BorderRadiusDirectional.only(
              topStart: radius,
              topEnd: radius,
              bottomStart: mine ? sharp : radius,
              bottomEnd: mine ? radius : sharp,
            ),
            border: Border.all(
              color: mine
                  ? AppColors.lilac.withValues(alpha: .24)
                  : Colors.white.withValues(alpha: .075),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSender && message.senderId.isNotEmpty) ...[
                _GroupSenderHeader(message: message),
                const SizedBox(height: 5),
              ],
              if (message.replyToId != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsetsDirectional.fromSTEB(9, 6, 9, 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(10),
                    border: const BorderDirectional(
                      start: BorderSide(color: AppColors.tea, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.replyToSender?.isNotEmpty == true
                            ? message.replyToSender!
                            : 'رد على رسالة',
                        style: const TextStyle(color: AppColors.tea, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stickerPreview(message.replyToText ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
              ],
              _MessageRichText(
                text: message.deleted ? 'تم حذف هذه الرسالة' : message.text,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.48,
                  color: message.deleted ? Colors.white70 : AppColors.text,
                  fontStyle: message.deleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.edited && !message.deleted) ...[
                    Text('معدّلة', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: .58))),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    clock(message.createdAt),
                    style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: .62)),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 5),
                    Icon(
                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 14,
                      color: isRead ? AppColors.tea : Colors.white70,
                    ),
                    if (isRead) ...[
                      const SizedBox(width: 3),
                      Text('مقروءة', style: TextStyle(fontSize: 9, color: AppColors.tea.withValues(alpha: .95))),
                    ],
                  ],
                ],
              ),
              if (counts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    for (final item in counts.entries)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onReaction(item.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: message.reactions[myUid] == item.key
                                ? AppColors.lilac.withValues(alpha: .22)
                                : Colors.black.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: .12)),
                          ),
                          child: Text('${item.key} ${item.value}', style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _MessageRichText extends StatelessWidget {
  const _MessageRichText({required this.text, required this.style});
  final String text;
  final TextStyle style;

  static final RegExp _emojiToken = RegExp(r'\[\[lamma_emoji:([^\]]+)\]\]');

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _emojiToken.allMatches(text)) {
      if (match.start > cursor) spans.add(TextSpan(text: text.substring(cursor, match.start)));
      final encoded = match.group(1) ?? '';
      String? url;
      Uri? parsedUrl;
      try {
        url = Uri.decodeComponent(encoded);
        parsedUrl = Uri.tryParse(url);
      } catch (_) {
        // رمز مشوّه (percent-encoding غير صالح) — نعرضه كنص بدل ما ينهار التطبيق.
        url = null;
      }
      if (url == null || parsedUrl == null ||
          !['http', 'https'].contains(parsedUrl.scheme) || parsedUrl.host.isEmpty) {
        spans.add(TextSpan(text: match.group(0), style: style));
        cursor = match.end;
        continue;
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5)),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 22),
            ),
          ),
        ),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(children: spans), style: style);
  }
}

class _GroupSenderHeader extends StatelessWidget {
  const _GroupSenderHeader({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: Svc.users.watch(message.senderId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.name ?? message.senderName;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => PublicProfileScreen(uid: message.senderId),
          )),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(name: name, photoUrl: user?.photoUrl ?? message.senderPhoto, size: 23),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.tea, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
                if (user?.verified == true) ...[
                  const SizedBox(width: 4),
                  VerificationMark(style: user!.verificationStyle, imageUrl: user!.verificationImageUrl, size: 13),
                ],
                if (user?.badges.isNotEmpty == true) ...[
                  const SizedBox(width: 5),
                  AppIdentityBadge(badge: user!.badges.first, compact: true),
                ] else if (user?.title.isNotEmpty == true) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.lilac.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(user!.title, style: const TextStyle(color: AppColors.lilac, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
