import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../chat/screens/chat_screen.dart';
import '../../profile/screens/profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final String _uid = context.read<AppUser>().uid;
  late final Stream<Set<String>> _friendIds = Svc.friends.watchFriendIds(_uid);
  late final Stream<List<FriendRequest>> _incoming = Svc.friends.watchIncoming(_uid);
  late final Stream<Set<String>> _sent = Svc.friends.watchSentIds(_uid);

  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  Future<List<AppUser>>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = v.trim();
        _results = _query.isEmpty ? null : Svc.users.search(_query, _uid);
      });
    });
  }

  Future<void> _guard(Future<void> Function() action, String failMessage) async {
    try {
      await action();
    } catch (_) {
      if (mounted) toast(context, failMessage);
    }
  }

  void _openChat(AppUser me, AppUser other) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatScreen(me: me, other: other)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppUser>();
    return StreamBuilder<Set<String>>(
      stream: _friendIds,
      builder: (context, fs) {
        final friendIds = fs.data ?? <String>{};
        return StreamBuilder<List<FriendRequest>>(
          stream: _incoming,
          builder: (context, inc) {
            final incoming = inc.data ?? const <FriendRequest>[];
            return StreamBuilder<Set<String>>(
              stream: _sent,
              builder: (context, sn) {
                final sent = sn.data ?? <String>{};
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: Text('جهات الاتصال',
                          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _search,
                        onChanged: _onChanged,
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن شخص بالاسم',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      ..._searchResults(me, friendIds, sent, incoming)
                    else ...[
                      if (incoming.isNotEmpty) ...[
                        SectionLabel('طلبات التواصل (${incoming.length})'),
                        for (final r in incoming)
                          PersonRow(
                            name: r.senderName,
                            photoUrl: r.senderPhoto,
                            subtitle: 'يريد يضيفك إلى جهات الاتصال',
                            onAvatarTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => PublicProfileScreen(uid: r.senderId),
                            )),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _guard(() => Svc.friends.reject(r), 'ما كدرنا نرفض الطلب.'),
                                  icon: const Icon(Icons.close_rounded, color: AppColors.textDim),
                                ),
                                FilledButton(
                                  onPressed: () => _guard(() => Svc.friends.accept(r), 'ما كدرنا نقبل الطلب. جرّب مرة ثانية.'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(72, 40),
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                  ),
                                  child: const Text('قبول'),
                                ),
                              ],
                            ),
                          ),
                      ],
                      SectionLabel('جهات اتصالي (${friendIds.length})'),
                      if (friendIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: EmptyState(
                            icon: Icons.people_outline_rounded,
                            title: 'جهات الاتصال فارغة',
                            body: 'ابحث عن الأشخاص بالاسم وأرسل طلب تواصل.',
                          ),
                        )
                      else
                        for (final id in friendIds)
                          _FriendRow(
                            key: ValueKey(id),
                            uid: id,
                            me: me,
                            onOpen: (u) => _openChat(me, u),
                          ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _searchResults(
    AppUser me,
    Set<String> friendIds,
    Set<String> sent,
    List<FriendRequest> incoming,
  ) {
    return [
      const SizedBox(height: 8),
      FutureBuilder<List<AppUser>>(
        future: _results,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('تعذّر البحث: ${snap.error}',
                  style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            );
          }
          final users = snap.data ?? const <AppUser>[];
          if (users.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'ما لقينا أحد',
                body: 'تأكد من كتابة الاسم مثل ما هو مسجّل.',
              ),
            );
          }
          return Column(
            children: [
              for (final u in users)
                PersonRow(
                  name: u.name,
                  photoUrl: u.photoUrl,
                  verified: u.verified,
                  verificationStyle: u.verificationStyle,
                  verificationImageUrl: u.verificationImageUrl,
                  badges: u.badges,
                  subtitle: '@${u.username ?? u.name}${u.bio.isNotEmpty ? ' • ${u.bio}' : ''}',
                  onAvatarTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => PublicProfileScreen(uid: u.uid),
                  )),
                  trailing: _action(me, u, friendIds, sent, incoming),
                ),
            ],
          );
        },
      ),
    ];
  }

  Widget _action(
    AppUser me,
    AppUser u,
    Set<String> friendIds,
    Set<String> sent,
    List<FriendRequest> incoming,
  ) {
    Widget chip(String t) => Text(t, style: const TextStyle(color: AppColors.textDim, fontSize: 13));
    if (friendIds.contains(u.uid)) return chip('جهة اتصال');
    if (sent.contains(u.uid)) return chip('تم الإرسال');
    final req = incoming.where((r) => r.senderId == u.uid).toList();
    if (req.isNotEmpty) {
      return FilledButton(
        onPressed: () => _guard(() => Svc.friends.accept(req.first), 'ما كدرنا نقبل الطلب. جرّب مرة ثانية.'),
        style: FilledButton.styleFrom(minimumSize: const Size(72, 40)),
        child: const Text('قبول'),
      );
    }
    return OutlinedButton(
      onPressed: () async {
        try {
          await Svc.friends.sendRequest(me, u.uid);
        } catch (_) {
          if (mounted) toast(context, 'ما كدرنا نرسل الطلب.');
        }
      },
      style: OutlinedButton.styleFrom(minimumSize: const Size(72, 40)),
      child: const Text('إضافة'),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({super.key, required this.uid, required this.me, required this.onOpen});
  final String uid;
  final AppUser me;
  final ValueChanged<AppUser> onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: Svc.users.watch(uid),
      builder: (context, snap) {
        final u = snap.data;
        if (u == null) return const SizedBox(height: 68);
        return PersonRow(
          name: u.name,
          photoUrl: u.photoUrl,
          verified: u.verified,
          verificationStyle: u.verificationStyle,
          verificationImageUrl: u.verificationImageUrl,
          badges: u.badges,
          subtitle: u.bio,
          onTap: () => onOpen(u),
          onAvatarTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => PublicProfileScreen(uid: u.uid),
          )),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textDim),
            onSelected: (_) async {
              final ok = await confirmDialog(
                context,
                title: 'إزالة ${u.name}؟',
                body: 'راح ينتهي التواصل بين الحسابين.',
                ok: 'إزالة',
                danger: true,
              );
              if (!ok) return;
              try {
                await Svc.friends.remove(me.uid, u.uid);
              } catch (_) {
                if (context.mounted) toast(context, 'ما كدرنا نزيل الصديق. جرّب مرة ثانية.');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'remove',
                child: Text('إزالة الصديق', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        );
      },
    );
  }
}
