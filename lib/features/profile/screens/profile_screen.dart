import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../admin/screens/admin_screen.dart';

String _joinDate(DateTime? t) {
  if (t == null) return 'غير متوفر';
  return '${t.day}/${t.month}/${t.year}';
}

String _joinedAgo(DateTime? t) {
  if (t == null) return '—';
  final days = DateTime.now().difference(t).inDays;
  if (days < 1) return 'اليوم';
  if (days < 30) return '$days يوم';
  if (days < 365) return '${days ~/ 30} شهر';
  return '${days ~/ 365} سنة';
}

void _openImage(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => _ImageViewerScreen(url: url)),
  );
}

// ───────────────────────── ملفي الشخصي ─────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Stream<Set<String>> _friends =
      Svc.friends.watchFriendIds(context.read<AppUser>().uid);

  void _openSettings(AppUser me, {bool editor = false}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfileSettingsScreen(me: me, openEditor: editor),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppUser>();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _ProfileHero(
          user: me,
          topActions: [
            _HeroIconButton(
              icon: Icons.settings_rounded,
              tooltip: 'الإعدادات',
              onTap: () => _openSettings(me),
            ),
          ],
        ),
        _IdentityBlock(
          user: me,
          actions: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openSettings(me, editor: true),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('تعديل الملف'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _openSettings(me),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('الإعدادات'),
              ),
            ],
          ),
        ),
        StreamBuilder<Set<String>>(
          stream: _friends,
          builder: (context, snapshot) => _StatStrip(items: [
            _StatItem('${snapshot.data?.length ?? 0}', 'جهات الاتصال'),
            _StatItem('${me.badges.length}', 'الأوسمة'),
            _StatItem(_joinedAgo(me.createdAt), 'منذ الانضمام'),
          ]),
        ),
        _Section(
          title: 'نبذة عني',
          child: Text(
            me.bio.trim().isEmpty
                ? 'ما كتبت نبذة بعد. اضغط «تعديل الملف» وعرّف أصحابك بنفسك.'
                : me.bio,
            style: TextStyle(
              color: me.bio.trim().isEmpty ? AppColors.textDim : AppColors.text,
              height: 1.8,
              fontSize: 14,
            ),
          ),
        ),
        if (me.badges.isNotEmpty)
          _Section(
            title: 'الأوسمة',
            count: me.badges.length,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final badge in me.badges) AppIdentityBadge(badge: badge)],
            ),
          ),
        _Section(
          title: 'تفاصيل الحساب',
          child: _DetailList(user: me),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text('LAMMA  •  قريبين، حتى لو بعيدين',
              style: TextStyle(color: AppColors.textDim, fontSize: 10, letterSpacing: .3)),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ───────────────────────── الملف العام ─────────────────────────

class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14),
          child: _HeroIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'رجوع',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      body: StreamBuilder<AppUser?>(
        stream: Svc.users.watch(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SafeArea(
              child: EmptyState(icon: Icons.cloud_off_rounded, title: 'تعذّر تحميل الملف الشخصي'),
            );
          }
          final user = snapshot.data;
          if (user == null) {
            return SafeArea(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : const EmptyState(icon: Icons.person_off_rounded, title: 'هذا الحساب غير متاح'),
            );
          }
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _ProfileHero(user: user, extraTop: MediaQuery.paddingOf(context).top + kToolbarHeight - 40),
              _IdentityBlock(user: user),
              _StatStrip(items: [
                _StatItem('${user.badges.length}', 'الأوسمة'),
                _StatItem(user.verified ? 'موثّق' : 'عادي', 'حالة الحساب'),
                _StatItem(_joinedAgo(user.createdAt), 'منذ الانضمام'),
              ]),
              _Section(
                title: 'نبذة',
                child: Text(
                  user.bio.trim().isEmpty ? 'ما أضاف هذا العضو نبذة بعد.' : user.bio,
                  style: TextStyle(
                    color: user.bio.trim().isEmpty ? AppColors.textDim : AppColors.text,
                    height: 1.8,
                    fontSize: 14,
                  ),
                ),
              ),
              if (user.badges.isNotEmpty)
                _Section(
                  title: 'الأوسمة',
                  count: user.badges.length,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final badge in user.badges) AppIdentityBadge(badge: badge)],
                  ),
                ),
              _Section(title: 'تفاصيل العضوية', child: _DetailList(user: user)),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── مكونات الواجهة ─────────────────────────

/// الغلاف + الصورة الشخصية الكبيرة بإطار متدرج. هذا العنصر المميز بالصفحة.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user, this.topActions = const [], this.extraTop = 0});
  final AppUser user;
  final List<Widget> topActions;
  final double extraTop;

  static const double _avatar = 96;

  @override
  Widget build(BuildContext context) {
    final bannerHeight = 176.0 + extraTop;
    final hasBanner = user.bannerUrl != null && user.bannerUrl!.isNotEmpty;
    final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty;
    return SizedBox(
      height: bannerHeight + _avatar / 2 + 6,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bannerHeight,
            child: GestureDetector(
              onTap: hasBanner ? () => _openImage(context, user.bannerUrl!) : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasBanner)
                    CachedNetworkImage(
                      imageUrl: user.bannerUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _DefaultBanner(seed: user.uid),
                      errorWidget: (_, __, ___) => _DefaultBanner(seed: user.uid),
                    )
                  else
                    _DefaultBanner(seed: user.uid),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: .18),
                          Colors.transparent,
                          AppColors.ink.withValues(alpha: .92),
                        ],
                        stops: const [0, .45, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (topActions.isNotEmpty)
            PositionedDirectional(
              top: 12,
              end: 14,
              child: Row(mainAxisSize: MainAxisSize.min, children: topActions),
            ),
          PositionedDirectional(
            bottom: 0,
            start: 20,
            child: GestureDetector(
              onTap: hasPhoto ? () => _openImage(context, user.photoUrl!) : null,
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [
                    AppColors.lilac,
                    AppColors.tea,
                    AppColors.violet,
                    AppColors.lilac,
                  ]),
                ),
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                  child: UserAvatar(name: user.name, photoUrl: user.photoUrl, size: _avatar),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: .38),
          foregroundColor: Colors.white,
          fixedSize: const Size(42, 42),
        ),
        icon: Icon(icon, size: 21),
      );
}

class _DefaultBanner extends StatelessWidget {
  const _DefaultBanner({required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) {
    // لون الغلاف الافتراضي يختلف من عضو لعضو حسب المعرّف.
    final hue = (seed.hashCode.abs() % 360).toDouble();
    final a = HSLColor.fromAHSL(1, hue, .42, .30).toColor();
    final b = HSLColor.fromAHSL(1, (hue + 50) % 360, .38, .18).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [a, b, AppColors.surface],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(start: -40, top: -60, child: _Glow(size: 200, color: a)),
          PositionedDirectional(end: 30, bottom: -90, child: _Glow(size: 210, color: AppColors.lilac)),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .10)),
      );
}

/// الاسم والمعرّف واللقب وأزرار الإجراءات.
class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.user, this.actions});
  final AppUser user;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final handle = '@${user.username ?? user.name}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.2),
                ),
              ),
              if (user.verified) ...[
                const SizedBox(width: 8),
                VerificationMark(style: user.verificationStyle, imageUrl: user.verificationImageUrl, size: 23),
              ],
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: handle));
              if (context.mounted) toast(context, 'تم نسخ اسم المستخدم.');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(handle,
                      style: const TextStyle(color: AppColors.lilac, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_rounded, size: 13, color: AppColors.textDim),
                ],
              ),
            ),
          ),
          if (user.title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.tea.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.tea.withValues(alpha: .38)),
              ),
              child: Text(user.title,
                  style: const TextStyle(color: AppColors.tea, fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
          if (actions != null) ...[
            const SizedBox(height: 16),
            actions!,
          ],
        ],
      ),
    );
  }
}

class _StatItem {
  const _StatItem(this.value, this.label);
  final String value;
  final String label;
}

/// شريط إحصائيات واحد بفواصل رفيعة بدل ثلاث بطاقات منفصلة.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.items});
  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.line)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(items[i].value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text)),
                    const SizedBox(height: 3),
                    Text(items[i].label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.count});
  final String title;
  final Widget child;
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.lilac.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$count',
                        style: const TextStyle(color: AppColors.lilac, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _DetailList extends StatelessWidget {
  const _DetailList({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (Icons.alternate_email_rounded, 'اسم المستخدم', '@${user.username ?? user.name}'),
      (Icons.event_available_rounded, 'تاريخ الانضمام', _joinDate(user.createdAt)),
      if (user.title.isNotEmpty) (Icons.military_tech_rounded, 'اللقب', user.title),
      (Icons.verified_user_outlined, 'التوثيق', user.verified ? 'حساب موثّق' : 'غير موثّق'),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                Icon(rows[i].$1, size: 18, color: AppColors.lilac),
                const SizedBox(width: 12),
                Text(rows[i].$2, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rows[i].$3,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageViewerScreen extends StatelessWidget {
  const _ImageViewerScreen({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const CircularProgressIndicator(strokeWidth: 2),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      );
}

// ───────────────────────── الإعدادات ─────────────────────────

/// تُفتح عبر Navigator خارج نطاق Provider<AppUser>، لذلك تستلم العضو مباشرة.
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key, required this.me, this.openEditor = false});
  final AppUser me;
  final bool openEditor;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  String get _uid => widget.me.uid;
  late final Stream<bool> _isAdmin = Svc.users.isAdmin(widget.me.uid);
  late final Stream<AppUser?> _meStream = Svc.users.watch(widget.me.uid);
  bool _uploadingAvatar = false;
  bool _uploadingBanner = false;
  bool _openedEditor = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.openEditor && !_openedEditor) {
      _openedEditor = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editProfile(widget.me);
      });
    }
  }

  Future<void> _changeImage({required bool banner}) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: banner ? 1800 : 1000,
      maxHeight: banner ? 900 : 1000,
      imageQuality: banner ? 86 : 88,
    );
    if (image == null || !mounted) return;
    setState(() {
      if (banner) {
        _uploadingBanner = true;
      } else {
        _uploadingAvatar = true;
      }
    });
    try {
      if (banner) {
        await Svc.users.updateBanner(_uid, File(image.path));
        if (mounted) toast(context, 'تم تحديث غلاف الحساب.');
      } else {
        await Svc.users.updateAvatar(_uid, File(image.path));
        if (mounted) toast(context, 'تم تحديث الصورة الشخصية.');
      }
    } catch (error) {
      if (mounted) toast(context, 'تعذّر رفع الصورة: ${error is StateError ? error.message : error}');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
          _uploadingBanner = false;
        });
      }
    }
  }

  Future<void> _editProfile(AppUser me) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _EditProfileSheet(me: me),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _meStream,
      initialData: widget.me,
      builder: (context, snapshot) => _buildBody(context, snapshot.data ?? widget.me),
    );
  }

  Widget _buildBody(BuildContext context, AppUser me) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الحساب')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _EditablePreview(
            user: me,
            uploadingBanner: _uploadingBanner,
            uploadingAvatar: _uploadingAvatar,
            onBanner: _uploadingBanner ? null : () => _changeImage(banner: true),
            onAvatar: _uploadingAvatar ? null : () => _changeImage(banner: false),
          ),
          const SizedBox(height: 18),
          _SettingsSection(title: 'بيانات الحساب', children: [
            _SettingsTile(
              icon: Icons.edit_note_rounded,
              title: 'الاسم والنبذة',
              subtitle: me.bio.trim().isEmpty ? 'أضف نبذة عنك' : me.bio.trim(),
              onTap: () => _editProfile(me),
            ),
            const Divider(height: 1),
            _SettingsTile(
              icon: Icons.alternate_email_rounded,
              title: 'اسم المستخدم',
              subtitle: '@${me.username ?? me.name}',
              onTap: () => _editProfile(me),
            ),
            const Divider(height: 1),
            _SettingsTile(
              icon: Icons.copy_rounded,
              title: 'معرّف الحساب (UID)',
              subtitle: 'اضغط لنسخ معرّفك',
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: me.uid));
                if (context.mounted) toast(context, 'تم نسخ معرّف الحساب.');
              },
            ),
          ]),
          StreamBuilder<bool>(
            stream: _isAdmin,
            builder: (context, snapshot) => snapshot.data == true
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _SettingsSection(title: 'الإدارة', children: [
                      _SettingsTile(
                        icon: Icons.admin_panel_settings_rounded,
                        color: AppColors.tea,
                        title: 'مركز الإدارة',
                        subtitle: 'الأعضاء والأوسمة والإيموجيات وسجل العمليات',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => AdminScreen(me: me)),
                        ),
                      ),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _SettingsSection(title: 'الجلسة', children: [
            _SettingsTile(
              icon: Icons.logout_rounded,
              color: AppColors.danger,
              title: 'تسجيل الخروج',
              subtitle: 'الخروج من حسابك على هذا الجهاز',
              onTap: () async {
                final confirmed = await confirmDialog(
                  context,
                  title: 'تسجيل الخروج؟',
                  body: 'تقدر ترجع بأي وقت بنفس الحساب.',
                  ok: 'خروج',
                  danger: true,
                );
                if (confirmed) await Svc.auth.signOut();
              },
            ),
          ]),
        ],
      ),
    );
  }
}

/// معاينة الغلاف والصورة مع أزرار تغيير مباشرة فوقها.
class _EditablePreview extends StatelessWidget {
  const _EditablePreview({
    required this.user,
    required this.uploadingBanner,
    required this.uploadingAvatar,
    required this.onBanner,
    required this.onAvatar,
  });

  final AppUser user;
  final bool uploadingBanner;
  final bool uploadingAvatar;
  final VoidCallback? onBanner;
  final VoidCallback? onAvatar;

  @override
  Widget build(BuildContext context) {
    final hasBanner = user.bannerUrl != null && user.bannerUrl!.isNotEmpty;
    return SizedBox(
      height: 190,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasBanner)
                    CachedNetworkImage(
                      imageUrl: user.bannerUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _DefaultBanner(seed: user.uid),
                    )
                  else
                    _DefaultBanner(seed: user.uid),
                  Container(color: Colors.black.withValues(alpha: .22)),
                  PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: _CameraButton(
                      label: 'تغيير الغلاف',
                      busy: uploadingBanner,
                      onTap: onBanner,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 0,
            start: 18,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                  child: UserAvatar(name: user.name, photoUrl: user.photoUrl, size: 80),
                ),
                PositionedDirectional(
                  bottom: 0,
                  end: 0,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAvatar,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.lilac,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                      child: uploadingAvatar
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 15, color: AppColors.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            bottom: 8,
            start: 114,
            end: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text('@${user.username ?? user.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.lilac, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.label, required this.busy, required this.onTap});
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.photo_camera_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 7),
                Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(title,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(children: children),
          ),
        ],
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (color ?? AppColors.lilac).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color ?? AppColors.lilac, size: 19),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textDim),
      );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.me});
  final AppUser me;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.me.name);
  late final TextEditingController _username = TextEditingController(text: widget.me.username ?? '');
  late final TextEditingController _bio = TextEditingController(text: widget.me.bio);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Svc.users.updateProfile(
        widget.me.uid,
        name: _name.text,
        username: _username.text,
        bio: _bio.text,
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('تم تحديث بيانات الملف الشخصي.')));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        toast(
          context,
          error is ArgumentError ? error.message.toString() : 'تعذّر حفظ البيانات: $error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 6, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('تعديل الملف الشخصي',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('هذي المعلومات تظهر لأصحابك بصفحة ملفك.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12)),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'الاسم الظاهر',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _username,
                maxLength: 24,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  prefixText: '@',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bio,
                maxLength: 120,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'النبذة الشخصية',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                      )
                    : const Text('حفظ التغييرات'),
              ),
            ],
          ),
        ),
      );
}
