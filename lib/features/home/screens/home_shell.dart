import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../chat/screens/chats_screen.dart';
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
    ChatsScreen(),
    FriendsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: StreamBuilder<List<ChatSummary>>(
        stream: _chats,
        builder: (context, chats) {
          final unread = (chats.data ?? const <ChatSummary>[])
              .where((c) => c.unreadFor(widget.uid))
              .length;
          return StreamBuilder<List<FriendRequest>>(
            stream: _incoming,
            builder: (context, reqs) {
              return _LammaNavigationBar(
                index: _index,
                onTap: (i) => setState(() => _index = i),
                badges: [unread, (reqs.data ?? const <FriendRequest>[]).length, 0],
              );
            },
          );
        },
      ),
    );
  }
}

class _LammaNavigationBar extends StatelessWidget {
  const _LammaNavigationBar({
    required this.index,
    required this.onTap,
    required this.badges,
  });

  final int index;
  final ValueChanged<int> onTap;
  final List<int> badges;

  static const _items = [
    (Icons.forum_outlined, Icons.forum_rounded, 'الدردشة'),
    (Icons.contacts_outlined, Icons.contacts_rounded, 'الأصدقاء'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 5, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: AppColors.line.withValues(alpha: .9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavigationItem(
                  icon: _items[i].$1,
                  selectedIcon: _items[i].$2,
                  label: _items[i].$3,
                  selected: i == index,
                  badge: badges[i],
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
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
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 210),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.lilac.withValues(alpha: .13) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              backgroundColor: AppColors.tea,
              textColor: AppColors.ink,
              child: Icon(
                selected ? selectedIcon : icon,
                size: 22,
                color: selected ? AppColors.lilac : AppColors.textDim,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.lilac : AppColors.textDim,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
