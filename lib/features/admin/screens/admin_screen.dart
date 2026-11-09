import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

/// لوحة الإدارة. الواجهة تتحقق من admins/{uid}، بس الحماية الفعلية بقواعد Firestore:
/// حتى لو أحد فتح هذي الشاشة بالقوة، كل الاستعلامات والكتابات راح ترفضها القواعد.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.me});
  final AppUser me;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final Stream<bool> _isAdmin = Svc.users.isAdmin(widget.me.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _isAdmin,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snap.data != true) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'غير مصرّح',
              body: 'هذي الصفحة للمشرف فقط.',
            ),
          );
        }
        return _AdminBody(me: widget.me);
      },
    );
  }
}

class _AdminBody extends StatelessWidget {
  const _AdminBody({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.shield_rounded, color: AppColors.tea, size: 22),
              SizedBox(width: 10),
              Text('لوحة الإدارة'),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.tea,
            labelColor: AppColors.text,
            unselectedLabelColor: AppColors.textDim,
            dividerColor: AppColors.line,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'نظرة عامة'),
              Tab(text: 'المستخدمون'),
              Tab(text: 'الإيموجيات'),
              Tab(text: 'السجل'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _OverviewTab(),
            _UsersTab(me: me),
            const _EmojisTab(),
            const _LogsTab(),
          ],
        ),
      ),
    );
  }
}

String _fullDate(DateTime? t) {
  if (t == null) return '—';
  return '${t.day}/${t.month}/${t.year} ${clock(t)}';
}

// ───────────────────────── نظرة عامة ─────────────────────────

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<AdminStats> _stats = Svc.admin.stats();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final next = Svc.admin.stats();
        setState(() => _stats = next);
        try {
          await next;
        } catch (_) {}
      },
      child: FutureBuilder<AdminStats>(
        future: _stats,
        builder: (context, snap) {
          final s = snap.data;
          final bannedPct = (s == null || s.users == 0)
              ? null
              : (s.banned * 100 / s.users).toStringAsFixed(1);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (snap.hasError)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('ما كدرنا نجيب الإحصائيات. تأكد من قواعد Firestore واسحب للتحديث.',
                      style: TextStyle(color: AppColors.danger)),
                ),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF30264C), AppColors.surfaceHigh, Color(0xFF171B2A)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.lilac.withValues(alpha: .2)),
                  boxShadow: [
                    BoxShadow(color: AppColors.violet.withValues(alpha: .12), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('مجتمع لَمّة', style: TextStyle(color: AppColors.lilac, fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          const Text('إجمالي المستخدمين', style: TextStyle(color: AppColors.textDim)),
                          const SizedBox(height: 4),
                          Text(s == null ? '…' : '${s.users}',
                              style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800, height: 1.1)),
                          if (bannedPct != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('نسبة المحظورين $bannedPct%',
                                  style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.lilac.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: AppColors.lilac.withValues(alpha: .2)),
                      ),
                      child: const Icon(Icons.groups_rounded, size: 31, color: AppColors.lilac),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Stat(label: 'جدد اليوم', value: s?.newToday, color: AppColors.lilac)),
                  const SizedBox(width: 12),
                  Expanded(child: _Stat(label: 'جدد (7 أيام)', value: s?.newUsers)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Stat(label: 'دخلوا آخر 24 ساعة', value: s?.active24h, color: AppColors.tea)),
                  const SizedBox(width: 12),
                  Expanded(child: _Stat(label: 'دخلوا آخر 7 أيام', value: s?.active7d)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Stat(label: 'موثّقون', value: s?.verified, color: AppColors.lilac)),
                  const SizedBox(width: 12),
                  Expanded(child: _Stat(label: 'محظورون', value: s?.banned, color: AppColors.danger)),
                ],
              ),
              const SizedBox(height: 20),
              _SignupsChart(counts: s?.signupsByDay ?? const []),
              const SizedBox(height: 28),
              const Text('صلاحيات الإدارة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'إضافة مشرف جديد تبقى من Firebase Console فقط عبر وثيقة admins/{uid}. '
                'الحظر والأوسمة والتوثيق تديرها من تبويب المستخدمين (اضغط على أي عضو، أو اضغط مطولاً للتحديد الجماعي). '
                'كل إجراء يتسجل بتبويب السجل.',
                style: TextStyle(color: AppColors.textDim, height: 1.7),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color = AppColors.text});
  final String label;
  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value == null ? '…' : '$value',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          ],
        ),
      );
}

class _SignupsChart extends StatelessWidget {
  const _SignupsChart({required this.counts});
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final maxValue = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('التسجيلات آخر 7 أيام', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (counts.length != 7)
            const SizedBox(height: 100, child: Center(child: Text('…', style: TextStyle(color: AppColors.textDim))))
          else
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Builder(builder: (context) {
                        final d = DateTime(now.year, now.month, now.day - (6 - i));
                        final c = counts[i];
                        final isToday = i == 6;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('$c', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isToday ? AppColors.tea : AppColors.textDim)),
                            const SizedBox(height: 4),
                            Container(
                              width: 18,
                              height: (c == 0 ? 4 : 4 + 70 * c / maxValue).toDouble(),
                              decoration: BoxDecoration(
                                color: isToday ? AppColors.tea : AppColors.lilac.withValues(alpha: .7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
                          ],
                        );
                      }),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── المستخدمون ─────────────────────────

enum _UserFilter { all, banned, verified, badged, recent, active }

enum _UserSort { newest, lastSeen, name }

const _filterLabels = {
  _UserFilter.all: 'الكل',
  _UserFilter.banned: 'محظورون',
  _UserFilter.verified: 'موثّقون',
  _UserFilter.badged: 'أوسمة/ألقاب',
  _UserFilter.recent: 'جدد (7 أيام)',
  _UserFilter.active: 'نشطون (24 س)',
};

const _sortLabels = {
  _UserSort.newest: 'الأحدث انضماماً',
  _UserSort.lastSeen: 'آخر دخول',
  _UserSort.name: 'الاسم',
};

class _UsersTab extends StatefulWidget {
  const _UsersTab({required this.me});
  final AppUser me;

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  int _limit = 300;
  late Stream<List<AppUser>> _users = Svc.admin.watchUsers(limit: _limit);
  String _q = '';
  _UserFilter _filter = _UserFilter.all;
  _UserSort _sort = _UserSort.newest;
  final Map<String, AppUser> _selected = {};
  bool _busy = false;

  bool get _selecting => _selected.isNotEmpty;

  List<AppUser> _apply(List<AppUser> all) {
    final now = DateTime.now();
    final list = all.where((u) {
      if (_q.isNotEmpty) {
        final hay = '${u.name} ${u.username ?? ''} ${u.uid}'.toLowerCase();
        if (!hay.contains(_q)) return false;
      }
      return switch (_filter) {
        _UserFilter.all => true,
        _UserFilter.banned => u.banned,
        _UserFilter.verified => u.verified,
        _UserFilter.badged => u.badges.isNotEmpty || u.title.isNotEmpty,
        _UserFilter.recent => u.createdAt != null && now.difference(u.createdAt!).inDays < 7,
        _UserFilter.active => u.lastSeen != null && now.difference(u.lastSeen!).inHours < 24,
      };
    }).toList();
    switch (_sort) {
      case _UserSort.newest:
        break;
      case _UserSort.lastSeen:
        list.sort((a, b) {
          final x = a.lastSeen, y = b.lastSeen;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        });
      case _UserSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  void _toggle(AppUser u) {
    if (u.uid == widget.me.uid) return;
    setState(() {
      if (_selected.containsKey(u.uid)) {
        _selected.remove(u.uid);
      } else {
        _selected[u.uid] = u;
      }
    });
  }

  Future<void> _bulk(String kind) async {
    final targets = _selected.values.toList();
    if (targets.isEmpty) return;
    final label = switch (kind) {
      'ban' => 'حظر',
      'unban' => 'فك الحظر عن',
      'verify' => 'توثيق',
      _ => 'إلغاء توثيق',
    };
    final ok = await confirmDialog(
      context,
      title: '$label ${targets.length} حساب؟',
      body: 'راح ينطبق الإجراء على كل الحسابات المحددة.',
      ok: 'تأكيد',
      danger: kind == 'ban',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      switch (kind) {
        case 'ban':
          await Svc.admin.bulkSetBanned(targets, true);
        case 'unban':
          await Svc.admin.bulkSetBanned(targets, false);
        case 'verify':
          await Svc.admin.bulkSetVerified(targets, true);
        default:
          await Svc.admin.bulkSetVerified(targets, false);
      }
      for (final u in targets) {
        Svc.users.invalidate(u.uid);
      }
      if (!mounted) return;
      setState(_selected.clear);
      toast(context, 'تم تنفيذ الإجراء على ${targets.length} حساب.');
    } catch (_) {
      if (mounted) toast(context, 'تعذّر تنفيذ الإجراء. تأكد من قواعد Firestore وصلاحية المشرف.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_selecting)
          Container(
            color: AppColors.surfaceHigh,
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'إلغاء التحديد',
                  onPressed: () => setState(_selected.clear),
                  icon: const Icon(Icons.close_rounded),
                ),
                Text('${_selected.length} محدد', style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                if (_busy)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else ...[
                  IconButton(tooltip: 'توثيق', onPressed: () => _bulk('verify'), icon: const Icon(Icons.verified_rounded, color: AppColors.lilac)),
                  IconButton(tooltip: 'إلغاء التوثيق', onPressed: () => _bulk('unverify'), icon: const Icon(Icons.remove_moderator_outlined, color: AppColors.textDim)),
                  IconButton(tooltip: 'فك الحظر', onPressed: () => _bulk('unban'), icon: const Icon(Icons.lock_open_rounded, color: AppColors.tea)),
                  IconButton(tooltip: 'حظر', onPressed: () => _bulk('ban'), icon: const Icon(Icons.block_rounded, color: AppColors.danger)),
                ],
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو @المعرّف أو UID',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                PopupMenuButton<_UserSort>(
                  tooltip: 'ترتيب',
                  icon: const Icon(Icons.sort_rounded, color: AppColors.textDim),
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => [
                    for (final e in _sortLabels.entries)
                      PopupMenuItem(
                        value: e.key,
                        child: Row(
                          children: [
                            Icon(_sort == e.key ? Icons.check_rounded : null, size: 18, color: AppColors.lilac),
                            const SizedBox(width: 8),
                            Text(e.value),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final e in _filterLabels.entries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _filter == e.key,
                    onSelected: (_) => setState(() => _filter = e.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: _users,
            builder: (context, snap) {
              if (snap.hasError) {
                return const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'ما كدرنا نجيب المستخدمين',
                  body: 'تأكد إن قواعد Firestore منشورة وإن حسابك مضاف بمجموعة admins.',
                );
              }
              final all = snap.data;
              if (all == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              final users = _apply(all);
              final canLoadMore = all.length >= _limit;
              if (users.isEmpty && !canLoadMore) {
                return const EmptyState(icon: Icons.search_off_rounded, title: 'ما في نتائج', body: 'جرّب بحث أو فلتر ثاني.');
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                itemCount: users.length + 1,
                itemBuilder: (context, i) {
                  if (i == users.length) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        children: [
                          Text('${users.length} من ${all.length} حساب محمّل',
                              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                          if (canLoadMore)
                            TextButton(
                              onPressed: () => setState(() {
                                _limit += 300;
                                _users = Svc.admin.watchUsers(limit: _limit);
                              }),
                              child: const Text('عرض المزيد'),
                            ),
                        ],
                      ),
                    );
                  }
                  final u = users[i];
                  final self = u.uid == widget.me.uid;
                  final selected = _selected.containsKey(u.uid);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: self ? null : () => _toggle(u),
                    child: Container(
                      color: selected ? AppColors.lilac.withValues(alpha: .09) : null,
                      child: PersonRow(
                        name: u.name,
                        photoUrl: u.photoUrl,
                        verified: u.verified,
                        verificationStyle: u.verificationStyle,
                        verificationImageUrl: u.verificationImageUrl,
                        badges: u.badges,
                        onTap: _selecting ? () => _toggle(u) : () => _showUserDetails(context, u, widget.me),
                        subtitle: [
                          if (self) 'أنت',
                          '@${u.username ?? ''}',
                          if (!u.banned) 'آخر دخول ${timeAgo(u.lastSeen ?? u.createdAt)}',
                        ].join(' • '),
                        trailing: _selecting
                            ? Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: selected ? AppColors.lilac : AppColors.textDim)
                            : (u.banned
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withValues(alpha: .14),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('محظور', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700)),
                                  )
                                : null),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── تفاصيل العضو ─────────────────────────

Future<void> _showUserDetails(BuildContext context, AppUser user, AppUser me) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _UserDetailsSheet(user: user, me: me),
  );
}

Future<void> _banFlow(BuildContext context, AppUser u) async {
  if (u.banned) {
    final ok = await confirmDialog(
      context,
      title: 'فك الحظر عن ${u.name}؟',
      body: 'راح يرجع يكدر يستخدم التطبيق.',
      ok: 'فك الحظر',
    );
    if (!ok) return;
    try {
      await Svc.admin.setBanned(u, false);
      Svc.users.invalidate(u.uid);
      if (context.mounted) toast(context, 'تم فك الحظر.');
    } catch (_) {
      if (context.mounted) toast(context, 'تعذّر تنفيذ الإجراء. تأكد من القواعد وصلاحية المشرف.');
    }
    return;
  }
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => _BanReasonDialog(name: u.name),
  );
  if (reason == null) return;
  try {
    await Svc.admin.setBanned(u, true, reason: reason);
    Svc.users.invalidate(u.uid);
    if (context.mounted) toast(context, 'تم حظر ${u.name}.');
  } catch (_) {
    if (context.mounted) toast(context, 'تعذّر تنفيذ الإجراء. تأكد من القواعد وصلاحية المشرف.');
  }
}

class _BanReasonDialog extends StatefulWidget {
  const _BanReasonDialog({required this.name});
  final String name;

  @override
  State<_BanReasonDialog> createState() => _BanReasonDialogState();
}

class _BanReasonDialogState extends State<_BanReasonDialog> {
  final _reason = TextEditingController();
  static const _quick = ['إساءة أو مضايقة', 'رسائل مزعجة (سبام)', 'حساب مزيف', 'محتوى غير لائق'];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('حظر ${widget.name}؟', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('راح يتوقف حسابه عن استخدام التطبيق، ويشوف السبب اللي تكتبه.',
                style: TextStyle(color: AppColors.textDim, height: 1.6)),
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              maxLength: 120,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'سبب الحظر (اختياري)'),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final r in _quick)
                  ActionChip(label: Text(r, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => _reason.text = r)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: AppColors.textDim)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: const Text('حظر', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _UserDetailsSheet extends StatelessWidget {
  const _UserDetailsSheet({required this.user, required this.me});
  final AppUser user;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: Svc.users.watch(user.uid),
      initialData: user,
      builder: (context, snap) {
        final u = snap.data ?? user;
        final self = u.uid == me.uid;
        final hasBanner = u.bannerUrl != null && u.bannerUrl!.isNotEmpty;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: hasBanner
                      ? CachedNetworkImage(
                          imageUrl: u.bannerUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: AppColors.surfaceHigh),
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF30264C), Color(0xFF171B2A)]),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  UserAvatar(name: u.name, photoUrl: u.photoUrl, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(u.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                            ),
                            if (u.verified) ...[
                              const SizedBox(width: 6),
                              VerificationMark(style: u.verificationStyle, imageUrl: u.verificationImageUrl, size: 18),
                            ],
                          ],
                        ),
                        Text('@${u.username ?? ''}', style: const TextStyle(color: AppColors.textDim)),
                      ],
                    ),
                  ),
                ],
              ),
              if (u.title.isNotEmpty || u.badges.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (u.title.isNotEmpty)
                      Text('لقب: ${u.title}', style: const TextStyle(color: AppColors.tea, fontWeight: FontWeight.w700)),
                    for (final b in u.badges) AppIdentityBadge(badge: b),
                  ],
                ),
              ],
              if (u.bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(u.bio, style: const TextStyle(height: 1.6)),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: 'تاريخ الانضمام', value: _fullDate(u.createdAt)),
                    _InfoRow(label: 'آخر دخول', value: _fullDate(u.lastSeen)),
                    _InfoRow(
                      label: 'الحالة',
                      value: u.banned ? 'محظور' : 'نشط',
                      valueColor: u.banned ? AppColors.danger : AppColors.lilac,
                    ),
                    _InfoRow(
                      label: 'UID',
                      value: u.uid,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: u.uid));
                        toast(context, 'تم نسخ UID.');
                      },
                    ),
                  ],
                ),
              ),
              if (u.banned && u.banReason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.danger.withValues(alpha: .3)),
                  ),
                  child: Text('سبب الحظر: ${u.banReason}', style: const TextStyle(height: 1.6)),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editIdentity(context, u),
                      icon: const Icon(Icons.workspace_premium_rounded, size: 19),
                      label: const Text('الهوية والأوسمة'),
                    ),
                  ),
                  if (!self) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: u.banned ? AppColors.lilac : AppColors.danger,
                          foregroundColor: AppColors.ink,
                        ),
                        onPressed: () => _banFlow(context, u),
                        icon: Icon(u.banned ? Icons.lock_open_rounded : Icons.block_rounded, size: 19),
                        label: Text(u.banned ? 'فك الحظر' : 'حظر'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor, this.onCopy});
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: valueColor)),
            ),
            if (onCopy != null)
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.copy_rounded, size: 16, color: AppColors.lilac),
                ),
              ),
          ],
        ),
      );
}

// ───────────────────────── السجل ─────────────────────────

class _LogsTab extends StatefulWidget {
  const _LogsTab();

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  late final Stream<List<AdminLog>> _logs = Svc.admin.watchLogs();

  static const _labels = {
    'ban': 'حظر عضو',
    'unban': 'فك حظر',
    'identity': 'تعديل هوية',
    'bulk_ban': 'حظر جماعي',
    'bulk_unban': 'فك حظر جماعي',
    'bulk_verify': 'توثيق جماعي',
    'bulk_unverify': 'إلغاء توثيق جماعي',
  };

  static IconData _icon(String a) => switch (a) {
        'ban' || 'bulk_ban' => Icons.block_rounded,
        'unban' || 'bulk_unban' => Icons.lock_open_rounded,
        'bulk_verify' => Icons.verified_rounded,
        'bulk_unverify' => Icons.remove_moderator_outlined,
        _ => Icons.workspace_premium_rounded,
      };

  static Color _color(String a) => switch (a) {
        'ban' || 'bulk_ban' => AppColors.danger,
        'unban' || 'bulk_unban' => AppColors.tea,
        _ => AppColors.lilac,
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminLog>>(
      stream: _logs,
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'ما كدرنا نجيب السجل',
            body: 'انشر ملف firestore.rules المحدّث (يحتوي مجموعة admin_logs) من Firebase Console.',
          );
        }
        final logs = snap.data;
        if (logs == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        if (logs.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'ما في إجراءات بعد',
            body: 'كل حظر أو تعديل هوية أو إجراء جماعي راح يظهر هنا.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
          itemBuilder: (context, i) {
            final l = logs[i];
            final color = _color(l.action);
            final subtitle = [
              if (l.targetName.isNotEmpty) l.targetName,
              if (l.detail.isNotEmpty) l.detail,
            ].join(' • ');
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: .13), shape: BoxShape.circle),
                child: Icon(_icon(l.action), size: 20, color: color),
              ),
              title: Text('${_labels[l.action] ?? l.action} • ${l.adminName}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: subtitle.isEmpty
                  ? null
                  : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
              trailing: Text(timeAgo(l.createdAt), style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
            );
          },
        );
      },
    );
  }
}

Future<void> _editIdentity(BuildContext context, AppUser user) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _IdentityEditorDialog(user: user),
  );
}

class _IdentityEditorDialog extends StatefulWidget {
  const _IdentityEditorDialog({required this.user});
  final AppUser user;

  @override
  State<_IdentityEditorDialog> createState() => _IdentityEditorDialogState();
}

class _IdentityEditorDialogState extends State<_IdentityEditorDialog> {
  late final List<AppBadge> _badges = List.of(widget.user.badges);
  late final TextEditingController _badgeName = TextEditingController();
  late final TextEditingController _title = TextEditingController(text: widget.user.title);
  late bool _verified = widget.user.verified;
  late String _badgeStyle = 'gradient';
  late String _badgeIcon = 'star';
  late int _badgeColor = 0xFFBBA5FF;
  late final TextEditingController _badgeHex = TextEditingController(text: 'BBA5FF');
  late String _verifyStyle = widget.user.verificationStyle;
  String? _badgeImageUrl;
  late String? _verificationImageUrl = widget.user.verificationImageUrl;
  bool _uploadingBadgeImage = false;
  bool _uploadingVerificationImage = false;
  bool _saving = false;

  static const _colors = <int>[
    0xFFBBA5FF,
    0xFFFFC45C,
    0xFF69D9E8,
    0xFFFF91B8,
    0xFF75D6A5,
    0xFFFF806F,
    0xFF79A9FF,
    0xFFE29BFF,
  ];

  @override
  void dispose() {
    _badgeName.dispose();
    _badgeHex.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<String> _uploadIdentityImage(XFile image, String folder) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) throw StateError('لا يوجد حساب إدارة مسجل.');
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty || bytes.length > 9 * 1024 * 1024) {
      throw StateError('حجم الصورة يجب ألا يتجاوز 9 ميغابايت.');
    }
    final kind = folder == 'badges' ? 'badge' : 'verification';
    return Svc.telegramImages.uploadBytes(
      uid: adminUid,
      bytes: bytes,
      fileName: image.name,
      kind: kind,
    );
  }

  Future<void> _pickBadgeImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 1400,
      );
      if (image == null || !mounted) return;
      setState(() => _uploadingBadgeImage = true);
      final url = await _uploadIdentityImage(image, 'badges');
      if (!mounted) return;
      setState(() {
        _badgeImageUrl = url;
        _uploadingBadgeImage = false;
      });
      toast(context, 'تم رفع صورة الوسام.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingBadgeImage = false);
      toast(context, 'تعذّر رفع الصورة عبر Cloudflare. تأكد من تحديث Worker وأن حسابك مشرف.');
    }
  }

  Future<void> _pickVerificationImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 1000,
      );
      if (image == null || !mounted) return;
      setState(() => _uploadingVerificationImage = true);
      final url = await _uploadIdentityImage(image, 'verification');
      if (!mounted) return;
      setState(() {
        _verificationImageUrl = url;
        _uploadingVerificationImage = false;
      });
      toast(context, 'تم رفع صورة التوثيق.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingVerificationImage = false);
      toast(context, 'تعذّر رفع الصورة عبر Cloudflare. تأكد من تحديث Worker وأن حسابك مشرف.');
    }
  }

  void _addBadge() {
    final label = _badgeName.text.trim();
    if (label.isEmpty) {
      toast(context, 'اكتب اسم الوسام أولاً.');
      return;
    }
    if (_badges.length >= 8) {
      toast(context, 'الحد الأقصى 8 أوسمة للعضو.');
      return;
    }
    setState(() {
      _badges.add(AppBadge(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        label: label,
        icon: _badgeIcon,
        color: _badgeColor,
        style: _badgeStyle,
        imageUrl: _badgeImageUrl,
      ));
      _badgeImageUrl = null;
      _badgeName.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Svc.admin.setUserIdentity(
        widget.user.uid,
        badges: _badges,
        verified: _verified,
        verificationStyle: _verifyStyle,
        verificationImageUrl: _verificationImageUrl,
        title: _title.text,
        targetName: widget.user.name,
      );
      Svc.users.invalidate(widget.user.uid);
      if (mounted) {
        toast(context, 'تم حفظ هوية ${widget.user.name} بنجاح.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      toast(context, 'تعذّر حفظ الهوية. تأكد من نشر قواعد Firestore.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 690),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.badge_rounded, color: AppColors.lilac),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('هوية ${widget.user.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(18),
                children: [
                  const Text('معاينة الأوسمة', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_badges.isEmpty)
                    const Text('ماكو أوسمة مضافة لهذا العضو.', style: TextStyle(color: AppColors.textDim, fontSize: 12))
                  else
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final b in _badges)
                          InputChip(
                            label: AppIdentityBadge(badge: b, compact: true),
                            onDeleted: () => setState(() => _badges.removeWhere((x) => x.id == b.id)),
                            deleteIconColor: AppColors.danger,
                            backgroundColor: AppColors.surfaceHigh,
                            side: const BorderSide(color: AppColors.line),
                          ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _badgeName,
                    maxLength: 24,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'اسم الوسام أو اللقب', counterText: '', prefixIcon: Icon(Icons.label_outline_rounded)),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _badgeStyle,
                    decoration: const InputDecoration(labelText: 'شكل الوسام'),
                    items: const [
                      DropdownMenuItem(value: 'gradient', child: Text('متدرّج فاخر')),
                      DropdownMenuItem(value: 'outline', child: Text('إطار أنيق')),
                      DropdownMenuItem(value: 'glow', child: Text('توهّج')),
                      DropdownMenuItem(value: 'glass', child: Text('زجاجي')),
                      DropdownMenuItem(value: 'shield', child: Text('درع')),
                      DropdownMenuItem(value: 'ribbon', child: Text('شريط')),
                      DropdownMenuItem(value: 'capsule', child: Text('كبسولة')),
                    ],
                    onChanged: (v) => setState(() => _badgeStyle = v ?? 'gradient'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _badgeIcon,
                    decoration: const InputDecoration(labelText: 'رمز الوسام'),
                    items: const [
                      DropdownMenuItem(value: 'star', child: Text('نجمة')),
                      DropdownMenuItem(value: 'crown', child: Text('تاج')),
                      DropdownMenuItem(value: 'bolt', child: Text('برق')),
                      DropdownMenuItem(value: 'diamond', child: Text('ألماسة')),
                      DropdownMenuItem(value: 'heart', child: Text('قلب')),
                      DropdownMenuItem(value: 'shield', child: Text('درع')),
                      DropdownMenuItem(value: 'fire', child: Text('نار')),
                      DropdownMenuItem(value: 'leaf', child: Text('ورقة')),
                    ],
                    onChanged: (v) => setState(() => _badgeIcon = v ?? 'star'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploadingBadgeImage ? null : _pickBadgeImage,
                          icon: _uploadingBadgeImage
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.photo_library_outlined),
                          label: Text(_badgeImageUrl == null ? 'اختيار صورة من المعرض' : 'تغيير صورة الوسام'),
                        ),
                      ),
                      if (_badgeImageUrl != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'إزالة الصورة',
                          onPressed: () => setState(() => _badgeImageUrl = null),
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('لون الوسام', style: TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final c in _colors)
                        GestureDetector(
                          onTap: () => setState(() {
                            _badgeColor = c;
                            _badgeHex.text = c.toRadixString(16).substring(2).toUpperCase();
                          }),
                          child: Container(
                            width: 31,
                            height: 31,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(color: _badgeColor == c ? Colors.white : Colors.transparent, width: 3),
                              boxShadow: [if (_badgeColor == c) BoxShadow(color: Color(c).withValues(alpha: .45), blurRadius: 10)],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _badgeHex,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'لون مخصص HEX', prefixText: '#', counterText: ''),
                    onChanged: (value) {
                      final parsed = int.tryParse(value.replaceAll('#', ''), radix: 16);
                      if (value.trim().length == 6 && parsed != null) {
                        setState(() => _badgeColor = 0xFF000000 | parsed);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  AppIdentityBadge(
                    badge: AppBadge(id: 'preview', label: _badgeName.text.trim().isEmpty ? 'معاينة الوسام' : _badgeName.text.trim(), icon: _badgeIcon, color: _badgeColor, style: _badgeStyle, imageUrl: _badgeImageUrl),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _uploadingBadgeImage ? null : _addBadge,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة الوسام إلى العضو'),
                  ),
                  const Divider(height: 28),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _verified,
                    activeColor: AppColors.lilac,
                    title: const Text('تفعيل علامة التوثيق', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('تظهر بجانب اسم العضو في ملفه الشخصي.', style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                    onChanged: (v) => setState(() => _verified = v),
                  ),
                  DropdownButtonFormField<String>(
                    value: _verifyStyle,
                    decoration: const InputDecoration(labelText: 'تصميم علامة التوثيق'),
                    items: const [
                      DropdownMenuItem(value: 'classic', child: Text('أزرق كلاسيكي')),
                      DropdownMenuItem(value: 'gold', child: Text('ذهبي')),
                      DropdownMenuItem(value: 'purple', child: Text('بنفسجي')),
                      DropdownMenuItem(value: 'cyan', child: Text('سماوي')),
                      DropdownMenuItem(value: 'rose', child: Text('وردي')),
                      DropdownMenuItem(value: 'star', child: Text('نجمة موثّقة')),
                      DropdownMenuItem(value: 'diamond', child: Text('ألماسي')),
                      DropdownMenuItem(value: 'shield', child: Text('درع توثيق')),
                      DropdownMenuItem(value: 'seal', child: Text('ختم فاخر')),
                    ],
                    onChanged: (v) => setState(() => _verifyStyle = v ?? 'classic'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploadingVerificationImage ? null : _pickVerificationImage,
                          icon: _uploadingVerificationImage
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.photo_library_outlined),
                          label: Text(_verificationImageUrl == null ? 'اختيار صورة التوثيق من المعرض' : 'تغيير صورة التوثيق'),
                        ),
                      ),
                      if (_verificationImageUrl != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'إزالة صورة التوثيق',
                          onPressed: () => setState(() => _verificationImageUrl = null),
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('معاينة العلامة', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                      const SizedBox(width: 10),
                      VerificationMark(style: _verifyStyle, imageUrl: _verificationImageUrl, size: 30),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _title,
                    maxLength: 32,
                    decoration: const InputDecoration(labelText: 'لقب رئيسي اختياري', hintText: 'مثلاً: المؤسس، المشرف العام', counterText: ''),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_saving || _uploadingBadgeImage || _uploadingVerificationImage) ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                      : const Text('حفظ هوية العضو'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _EmojisTab extends StatefulWidget {
  const _EmojisTab();

  @override
  State<_EmojisTab> createState() => _EmojisTabState();
}

class _EmojisTabState extends State<_EmojisTab> {
  late final Stream<List<AppEmoji>> _emojis = Svc.emojis.watchAll();

  Future<void> _addEmoji() async {
    final draft = await showDialog<_EmojiDraft>(
      context: context,
      builder: (_) => const _EmojiDraftDialog(),
    );
    if (draft == null) return;
    try {
      String? imageUrl = draft.imageUrl.trim().isEmpty ? null : draft.imageUrl.trim();
      if (draft.image != null) {
        final adminUid = FirebaseAuth.instance.currentUser?.uid;
        if (adminUid == null) throw StateError('سجّل الدخول بحساب الإدارة أولاً.');
        final bytes = await draft.image!.readAsBytes();
        imageUrl = await Svc.telegramImages.uploadBytes(
          uid: adminUid,
          bytes: bytes,
          fileName: draft.image!.name,
          kind: 'emoji',
        );
      }
      await Svc.emojis.add(emoji: draft.emoji, label: draft.label, imageUrl: imageUrl);
      if (mounted) toast(context, 'تمت إضافة الإيموجي لكل مستخدمي لَمّة.');
    } catch (e) {
      if (mounted) toast(context, 'ما كدرنا نضيف الإيموجي: $e');
    }
  }

  Future<void> _deleteEmoji(AppEmoji emoji) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف ${emoji.label.isEmpty ? 'الإيموجي' : emoji.label}؟',
      body: 'راح ينحذف من منتقي الإيموجيات عند جميع المستخدمين.',
      ok: 'حذف',
      danger: true,
    );
    if (!ok) return;
    try {
      await Svc.emojis.delete(emoji.id);
    } catch (_) {
      if (mounted) toast(context, 'تعذّر حذف الإيموجي.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEmoji,
        backgroundColor: AppColors.lilac,
        foregroundColor: AppColors.ink,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة إيموجي'),
      ),
      body: StreamBuilder<List<AppEmoji>>(
        stream: _emojis,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'تعذّر تحميل الإيموجيات',
              body: 'تأكد من نشر قواعد Firestore الجديدة.',
            );
          }
          final items = snapshot.data;
          if (items == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.emoji_emotions_outlined,
              title: 'ماكو إيموجيات مضافة',
              body: 'اضغط إضافة إيموجي حتى تضيف رموز خاصة تظهر لكل أعضاء لَمّة داخل المحادثات.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.lilac.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: item.isImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(item.imageUrl!, width: 42, height: 42, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AppColors.textDim)),
                            )
                          : Text(item.emoji, style: const TextStyle(fontSize: 29)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label.isEmpty ? 'إيموجي مخصص' : item.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(item.enabled ? 'ظاهر للمستخدمين' : 'متوقف مؤقتاً', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: item.enabled,
                      activeColor: AppColors.lilac,
                      onChanged: (value) async {
                        try {
                          await Svc.emojis.setEnabled(item.id, value);
                        } catch (_) {
                          if (mounted) toast(context, 'تعذّر تحديث حالة الإيموجي.');
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => _deleteEmoji(item),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmojiDraft {
  const _EmojiDraft({required this.emoji, required this.label, required this.imageUrl, this.image});
  final String emoji;
  final String label;
  final String imageUrl;
  final XFile? image;
}

class _EmojiDraftDialog extends StatefulWidget {
  const _EmojiDraftDialog();

  @override
  State<_EmojiDraftDialog> createState() => _EmojiDraftDialogState();
}

class _EmojiDraftDialogState extends State<_EmojiDraftDialog> {
  final _emoji = TextEditingController();
  final _label = TextEditingController();
  final _imageUrl = TextEditingController();
  XFile? _image;
  String? _error;

  @override
  void dispose() {
    _emoji.dispose();
    _label.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (image != null && mounted) setState(() { _image = image; _imageUrl.clear(); _error = null; });
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذّر فتح معرض الصور: $error');
    }
  }

  void _submit() {
    final value = _emoji.text.trim();
    final url = _imageUrl.text.trim();
    if (value.isEmpty && _image == null && url.isEmpty) {
      setState(() => _error = 'اكتب رمزاً أو اختر صورة أو ألصق رابط صورة.');
      return;
    }
    if (value.runes.length > 8) {
      setState(() => _error = 'الرمز النصي يجب ألا يتجاوز 8 محارف.');
      return;
    }
    if (url.isNotEmpty) {
      final parsed = Uri.tryParse(url);
      if (parsed == null || !['http', 'https'].contains(parsed.scheme) || parsed.host.isEmpty) {
        setState(() => _error = 'رابط الصورة غير صالح؛ استخدم رابط HTTP أو HTTPS.');
        return;
      }
    }
    if (_label.text.trim().length > 30) {
      setState(() => _error = 'الاسم يجب ألا يتجاوز 30 حرفاً.');
      return;
    }
    Navigator.pop(context, _EmojiDraft(
      emoji: value,
      label: _label.text.trim(),
      imageUrl: url,
      image: _image,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('إضافة إيموجي مخصص'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emoji,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 34),
                decoration: const InputDecoration(hintText: '😀', labelText: 'إيموجي نصي (اختياري)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                maxLength: 30,
                decoration: const InputDecoration(labelText: 'اسم الإيموجي', hintText: 'مثلاً: لَمّة'),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_image == null ? 'اختيار صورة من الجهاز' : 'تم اختيار: ${_image!.name}'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _imageUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'أو رابط صورة مباشر',
                  hintText: 'https://example.com/emoji.webp',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                onChanged: (_) { if (_imageUrl.text.isNotEmpty && _image != null) setState(() => _image = null); },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: _submit, child: const Text('إضافة')),
        ],
      );
}
