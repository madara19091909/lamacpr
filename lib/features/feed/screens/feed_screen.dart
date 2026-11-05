import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final Stream<List<Post>> _feed = Svc.posts.watchFeed(context.read<AppUser>().uid);

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppUser>();
    return StreamBuilder<List<Post>>(
      stream: _feed,
      builder: (context, snap) {
        final posts = snap.data;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(me: me)),
            SliverToBoxAdapter(child: _ComposerBar(me: me)),
            if (snap.hasError)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'ما كدرنا نحمّل المنشورات',
                  body: 'تأكد من الإنترنت، ومن نشر الفهارس (firestore.indexes.json) وقواعد Firestore.',
                ),
              )
            else if (posts == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'بداية لَمّة جديدة',
                  body: 'انشر أول منشور، أو ضيف أصدقاء من تبويب الأصدقاء حتى تشوف منشوراتهم هنا.',
                ),
              )
            else
              SliverList.separated(
                itemCount: posts.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) => PostTile(post: posts[i], me: me),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Row(
          children: [
            const LammaMark(size: 34),
            const SizedBox(width: 10),
            const Text('لَمّة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const Spacer(),
            UserAvatar(name: me.name, photoUrl: me.photoUrl, size: 38),
          ],
        ),
      );
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showComposer(context, me),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text('شنو بالك؟ شاركنا…',
                      style: TextStyle(color: AppColors.textDim, fontSize: 15)),
                ),
                Icon(Icons.image_outlined, color: AppColors.lilac),
              ],
            ),
          ),
        ),
      );
}

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post, required this.me});
  final Post post;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final liked = post.likedBy.contains(me.uid);
    final mine = post.authorId == me.uid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(name: post.authorName, photoUrl: post.authorPhoto, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    Text(timeAgo(post.createdAt),
                        style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                    const Spacer(),
                    if (mine)
                      SizedBox(
                        height: 24,
                        width: 28,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_horiz_rounded,
                              size: 20, color: AppColors.textDim),
                          onSelected: (_) async {
                            final ok = await confirmDialog(
                              context,
                              title: 'حذف المنشور؟',
                              body: 'ما تكدر ترجعه بعد الحذف.',
                              ok: 'حذف',
                              danger: true,
                            );
                            if (ok) await Svc.posts.delete(post);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('حذف المنشور', style: TextStyle(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (post.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(post.text, style: const TextStyle(fontSize: 15.5, height: 1.65)),
                  ),
                if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 380),
                        child: CachedNetworkImage(
                          imageUrl: post.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(height: 220, color: AppColors.surface),
                          errorWidget: (_, __, ___) => Container(
                            height: 120,
                            color: AppColors.surface,
                            child: const Icon(Icons.broken_image_outlined, color: AppColors.textDim),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                _LikeButton(
                  liked: liked,
                  count: post.likedBy.length,
                  onTap: () => Svc.posts.toggleLike(post.id, me.uid, liked),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.count, required this.onTap});
  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(liked),
                  size: 22,
                  color: liked ? AppColors.tea : AppColors.textDim,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text('$count',
                    style: TextStyle(
                        color: liked ? AppColors.tea : AppColors.textDim,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      );
}

Future<void> showComposer(BuildContext context, AppUser me) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _Composer(me: me),
    );

class _Composer extends StatefulWidget {
  const _Composer({required this.me});
  final AppUser me;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  File? _image;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _publish() async {
    final t = _text.text.trim();
    if (t.isEmpty && _image == null) return;
    setState(() => _busy = true);
    try {
      await Svc.posts.create(me: widget.me, text: t, image: _image);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'ما كدرنا ننشر، جرّب مرة ثانية.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(name: widget.me.name, photoUrl: widget.me.photoUrl, size: 40),
                const SizedBox(width: 12),
                Text(widget.me.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              maxLength: 1000,
              style: const TextStyle(fontSize: 17, height: 1.6),
              decoration: const InputDecoration(
                hintText: 'شنو بالك؟',
                filled: false,
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_image!,
                          height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _image = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.image_outlined, color: AppColors.lilac),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _publish,
                  style: FilledButton.styleFrom(minimumSize: const Size(110, 46)),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                        )
                      : const Text('نشر'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
