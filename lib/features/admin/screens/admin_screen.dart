import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
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
      length: 3,
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
            indicatorColor: AppColors.tea,
            labelColor: AppColors.text,
            unselectedLabelColor: AppColors.textDim,
            dividerColor: AppColors.line,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [Tab(text: 'نظرة عامة'), Tab(text: 'المستخدمون'), Tab(text: 'المنشورات')],
          ),
        ),
        body: TabBarView(
          children: [
            const _OverviewTab(),
            _UsersTab(me: me),
            const _PostsTab(),
          ],
        ),
      ),
    );
  }
}

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
        setState(() => _stats = Svc.admin.stats());
        await _stats;
      },
      child: FutureBuilder<AdminStats>(
        future: _stats,
        builder: (context, snap) {
          final s = snap.data;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (snap.hasError)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('ما كدرنا نجيب الإحصائيات. تأكد من قواعد Firestore.',
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
                              style: const TextStyle(
                                  fontSize: 46, fontWeight: FontWeight.w800, height: 1.1)),
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
                  Expanded(child: _Stat(label: 'منشورات', value: s?.posts)),
                  const SizedBox(width: 12),
                  Expanded(child: _Stat(label: 'جدد (7 أيام)', value: s?.newUsers)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat(label: 'محظورون', value: s?.banned, color: AppColors.danger),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text('صلاحيات الإدارة',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'إضافة مشرف جديد تبقى من Firebase Console فقط عبر وثيقة admins/{uid}. '
                'أما الأوسمة والألقاب والتوثيق فتقدر تديرها مباشرة من قائمة المستخدمين عبر زر الهوية.',
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

class _UsersTab extends StatefulWidget {
  const _UsersTab({required this.me});
  final AppUser me;

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late final Stream<List<AppUser>> _users = Svc.admin.watchUsers();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'بحث بالاسم',
              prefixIcon: Icon(Icons.search_rounded),
            ),
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
              final users = _q.isEmpty
                  ? all
                  : all.where((u) => u.name.toLowerCase().contains(_q)).toList();
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: users.length,
                itemBuilder: (context, i) {
                  final u = users[i];
                  final self = u.uid == widget.me.uid;
                  return PersonRow(
                    name: u.name,
                    photoUrl: u.photoUrl,
                    verified: u.verified,
                    verificationStyle: u.verificationStyle,
                    verificationImageUrl: u.verificationImageUrl,
                    badges: u.badges,
                    subtitle: [
                      if (self) 'أنت',
                      if (u.banned) 'محظور' else if (!self) 'انضم ${timeAgo(u.createdAt)}',
                      if (u.verified) 'موثّق',
                      if (u.badges.isNotEmpty) '${u.badges.length} وسام',
                    ].join(' • '),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'إدارة الأوسمة والتوثيق',
                          onPressed: () => _editIdentity(context, u),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.lilac.withValues(alpha: .12),
                            foregroundColor: AppColors.lilac,
                          ),
                          icon: const Icon(Icons.workspace_premium_rounded, size: 19),
                        ),
                        if (!self)
                          PopupMenuButton<String>(
                            tooltip: 'خيارات العضو',
                            onSelected: (value) async {
                              final ban = value == 'ban';
                              final ok = await confirmDialog(
                                context,
                                title: ban ? 'حظر ${u.name}؟' : 'فك الحظر عن ${u.name}؟',
                                body: ban
                                    ? 'راح يتوقف حسابه عن استخدام التطبيق.'
                                    : 'راح يرجع يكدر يستخدم التطبيق.',
                                ok: ban ? 'حظر' : 'فك الحظر',
                                danger: ban,
                              );
                              if (ok) await Svc.admin.setBanned(u.uid, ban);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: u.banned ? 'unban' : 'ban',
                                child: Text(u.banned ? 'فك الحظر' : 'حظر العضو',
                                    style: TextStyle(color: u.banned ? AppColors.lilac : AppColors.danger)),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textDim),
                          ),
                      ],
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
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw StateError('حجم الصورة يجب أن يكون أقل من 5 ميغابايت.');
    }
    final ext = image.name.contains('.') ? image.name.split('.').last.toLowerCase() : 'jpg';
    final contentType = image.mimeType ?? switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    if (!contentType.startsWith('image/')) {
      throw StateError('الملف المختار ليس صورة.');
    }
    final name = '${DateTime.now().microsecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance
        .ref('identity/$adminUid/${widget.user.uid}/$folder/$name');
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return snapshot.ref.getDownloadURL();
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
      toast(context, 'تعذّر رفع الصورة. تأكد من نشر قواعد Storage وأن حسابك مشرف.');
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
      toast(context, 'تعذّر رفع الصورة. تأكد من نشر قواعد Storage وأن حسابك مشرف.');
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
      );
      Svc.users.invalidate(widget.user.uid);
      if (mounted) Navigator.pop(context);
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

class _PostsTab extends StatefulWidget {
  const _PostsTab();

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  late final Stream<List<Post>> _posts = Svc.admin.watchPosts();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Post>>(
      stream: _posts,
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'ما كدرنا نجيب المنشورات',
            body: 'تأكد إن قواعد Firestore منشورة وإن حسابك مضاف بمجموعة admins.',
          );
        }
        final posts = snap.data;
        if (posts == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        if (posts.isEmpty) {
          return const EmptyState(icon: Icons.forum_outlined, title: 'ما كو منشورات بعد');
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final p = posts[i];
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(name: p.authorName, photoUrl: p.authorPhoto, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(p.authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Text(timeAgo(p.createdAt),
                                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                          ],
                        ),
                        if (p.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(p.text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(height: 1.5)),
                          ),
                        if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: p.imageUrl!,
                                height: 110,
                                width: 160,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const SizedBox(height: 110, width: 160),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'حذف المنشور؟',
                        body: 'منشور ${p.authorName} راح ينحذف نهائياً.',
                        ok: 'حذف',
                        danger: true,
                      );
                      if (ok) await Svc.admin.deletePost(p);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
