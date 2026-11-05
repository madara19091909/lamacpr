import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../chat/screens/chats_screen.dart';
import '../../feed/screens/feed_screen.dart';
import '../../friends/screens/friends_screen.dart';
import '../../profile/screens/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.uid});
  final String uid;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final Stream<List<ChatSummary>> _chats = Svc.chats.watchChats(widget.uid);
  late final Stream<List<FriendRequest>> _incoming = Svc.friends.watchIncoming(widget.uid);

  static const _pages = <Widget>[
    FeedScreen(),
    ChatsScreen(),
    FriendsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _index, children: _pages)),
      bottomNavigationBar: StreamBuilder<List<ChatSummary>>(
        stream: _chats,
        builder: (context, chats) {
          final unread = (chats.data ?? const <ChatSummary>[])
              .where((c) => c.unreadFor(widget.uid))
              .length;
          return StreamBuilder<List<FriendRequest>>(
            stream: _incoming,
            builder: (context, reqs) {
              return _FloatingNav(
                index: _index,
                onTap: (i) => setState(() => _index = i),
                badges: [0, unread, (reqs.data ?? const <FriendRequest>[]).length, 0],
              );
            },
          );
        },
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.index, required this.onTap, required this.badges});

  final int index;
  final ValueChanged<int> onTap;
  final List<int> badges;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'المحادثات'),
    (Icons.people_outline_rounded, Icons.people_rounded, 'الأصدقاء'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavItem(
                  icon: _items[i].$1,
                  selectedIcon: _items[i].$2,
                  label: _items[i].$3,
                  selected: i == index,
                  badge: badges[i],
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.lilac.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: AppColors.tea,
              textColor: AppColors.ink,
              child: Icon(
                selected ? selectedIcon : icon,
                size: 24,
                color: selected ? AppColors.lilac : AppColors.textDim,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: Text(label,
                          style: const TextStyle(
                              color: AppColors.lilac, fontWeight: FontWeight.w700, fontSize: 13)),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
