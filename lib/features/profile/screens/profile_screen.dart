import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../admin/screens/admin_screen.dart';

/// صفحة الحساب الشخصية: عرض الهوية فقط، بدون حشر أدوات الإدارة والتعديل داخلها.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppUser>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 34),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('ملفي الشخصي', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            ),
            IconButton.filledTonal(
              tooltip: 'إعدادات الحساب',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ProfileSettingsScreen(me: me),
              )),
              style: IconButton.styleFrom(backgroundColor: AppColors.surfaceHigh, foregroundColor: AppColors.lilac),
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        const SizedBox(height: 13),
        _ProfileIdentityCard(user: me),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _ProfileActionCard(
                icon: Icons.edit_rounded,
                title: 'تعديل الملف',
                subtitle: 'الاسم والنبذة والصور',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ProfileSettingsScreen(me: me, openEditor: true),
                )),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileActionCard(
                icon: Icons.tune_rounded,
                title: 'الإعدادات',
                subtitle: 'الخصوصية والحساب',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ProfileSettingsScreen(me: me),
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        _ProfileInfoCard(
          title: 'نبذة عني',
          icon: Icons.auto_awesome_rounded,
          child: Text(
            me.bio.trim().isEmpty ? 'هذا المكان مخصص لنبذة قصيرة عنك.' : me.bio,
            style: const TextStyle(color: AppColors.textDim, height: 1.8, fontSize: 13),
          ),
        ),
        if (me.badges.isNotEmpty) ...[
          const SizedBox(height: 13),
          _ProfileInfoCard(
            title: 'الأوسمة والإنجازات',
            icon: Icons.workspace_premium_rounded,
            trailing: Text('${me.badges.length}', style: const TextStyle(color: AppColors.lilac, fontWeight: FontWeight.w900)),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final badge in me.badges) AppIdentityBadge(badge: badge)],
            ),
          ),
        ],
        const SizedBox(height: 13),
        StreamBuilder<Set<String>>(
          stream: Svc.friends.watchFriendIds(me.uid),
          builder: (context, snapshot) => _ProfileInfoCard(
            title: 'معلومات الحساب',
            icon: Icons.insights_rounded,
            child: Row(
              children: [
                Expanded(child: _ProfileMetric(value: '${snapshot.data?.length ?? 0}', label: 'جهات الاتصال')),
                Expanded(child: _ProfileMetric(value: me.badges.length.toString(), label: 'الأوسمة')),
                Expanded(child: _ProfileMetric(value: me.verified ? 'موثّق' : 'عادي', label: 'حالة الحساب')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text('LAMMA  •  قريبين، حتى لو بعيدين',
              style: TextStyle(color: AppColors.textDim, fontSize: 10, letterSpacing: .3)),
        ),
      ],
    );
  }
}

/// صفحة الملف العام لأي عضو. تُفتح من صورة الحساب في الدردشة وجهات الاتصال.
class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: StreamBuilder<AppUser?>(
        stream: Svc.users.watch(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(icon: Icons.cloud_off_rounded, title: 'تعذّر تحميل الملف الشخصي');
          }
          final user = snapshot.data;
          if (user == null) {
            return snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : const EmptyState(icon: Icons.person_off_rounded, title: 'هذا الحساب غير متاح');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _ProfileIdentityCard(user: user),
              const SizedBox(height: 14),
              _ProfileInfoCard(
                title: 'النبذة الشخصية',
                icon: Icons.notes_rounded,
                child: Text(
                  user.bio.isEmpty ? 'لم يضف هذا العضو نبذة شخصية بعد.' : user.bio,
                  style: const TextStyle(color: AppColors.textDim, height: 1.8, fontSize: 13),
                ),
              ),
              if (user.badges.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ProfileInfoCard(
                  title: 'الأوسمة والإنجازات',
                  icon: Icons.workspace_premium_rounded,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final badge in user.badges) AppIdentityBadge(badge: badge)],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _ProfileInfoCard(
                title: 'تفاصيل العضوية',
                icon: Icons.verified_user_outlined,
                child: Column(
                  children: [
                    _ProfileDetailRow(label: 'اسم المستخدم', value: '@${user.username ?? user.name}'),
                    const Divider(height: 18),
                    _ProfileDetailRow(
                      label: 'تاريخ الانضمام',
                      value: user.createdAt == null
                          ? 'غير متوفر'
                          : '${user.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}',
                    ),
                    if (user.title.isNotEmpty) ...[
                      const Divider(height: 18),
                      _ProfileDetailRow(label: 'اللقب', value: user.title),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: AppColors.lilac.withValues(alpha: .2)),
        boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: .10), blurRadius: 25, offset: const Offset(0, 9))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (user.bannerUrl != null && user.bannerUrl!.isNotEmpty)
                  Image.network(user.bannerUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _DefaultProfileBanner())
                else
                  const _DefaultProfileBanner(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: .03), Colors.black.withValues(alpha: .48)],
                    ),
                  ),
                ),
                const Positioned(
                  top: 15,
                  left: 16,
                  child: Row(
                    children: [
                      Icon(Icons.bubble_chart_rounded, color: Colors.white70, size: 15),
                      SizedBox(width: 5),
                      Text('LAMMA MEMBER', style: TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Positioned(
                  right: 19,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle,
                      border: Border.all(color: AppColors.lilac.withValues(alpha: .65), width: 1.5)),
                    child: UserAvatar(name: user.name, photoUrl: user.photoUrl, size: 78),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 7, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
                    if (user.verified) ...[
                      const SizedBox(width: 7),
                      VerificationMark(style: user.verificationStyle, imageUrl: user.verificationImageUrl, size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text('@${user.username ?? user.name}', style: const TextStyle(color: AppColors.lilac, fontSize: 12, fontWeight: FontWeight.w700)),
                if (user.title.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.tea.withValues(alpha: .12), borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.tea.withValues(alpha: .35))),
                    child: Text(user.title, style: const TextStyle(color: AppColors.tea, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
                if (user.badges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 7, runSpacing: 7,
                    children: [for (final badge in user.badges.take(3)) AppIdentityBadge(badge: badge, compact: true)]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultProfileBanner extends StatelessWidget {
  const _DefaultProfileBanner();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
        colors: [Color(0xFF503B82), Color(0xFF263A55), Color(0xFF171521)]),
    ),
    child: Stack(children: [
      Positioned(left: -25, top: -55, child: _BannerGlow(size: 170)),
      Positioned(right: 40, bottom: -85, child: _BannerGlow(size: 190)),
      Positioned(left: 30, bottom: 24, child: Icon(Icons.auto_awesome_rounded, size: 22, color: Colors.white24)),
    ]),
  );
}

class _BannerGlow extends StatelessWidget {
  const _BannerGlow({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lilac.withValues(alpha: .08)),
  );
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({required this.title, required this.icon, required this.child, this.trailing});
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: AppColors.lilac, size: 18), const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
        if (trailing != null) trailing!]),
      const SizedBox(height: 13),
      child,
    ]),
  );
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceHigh,
    borderRadius: BorderRadius.circular(19),
    child: InkWell(
      borderRadius: BorderRadius.circular(19), onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.lilac, size: 20), const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
      ])),
    ),
  );
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: AppColors.lilac, fontWeight: FontWeight.w900, fontSize: 17)),
    const SizedBox(height: 4),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
  ]);
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 12))),
    Flexible(child: Text(value, textAlign: TextAlign.end,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
  ]);
}

/// الإعدادات منفصلة عن البروفايل، وتضم تغيير الصور والبيانات ولوحة المشرف.
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key, required this.me, this.openEditor = false});
  final AppUser me;
  final bool openEditor;
  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  // الشاشات المفتوحة بـ Navigator ما تشوف Provider<AppUser> (لأنه داخل شاشة home)،
  // لذلك نمرّر العضو مباشرة ونتابع تحديثاته من Firestore.
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
    setState(() { if (banner) { _uploadingBanner = true; } else { _uploadingAvatar = true; } });
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
      if (mounted) setState(() { _uploadingAvatar = false; _uploadingBanner = false; });
    }
  }

  Future<void> _editProfile(AppUser me) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, useSafeArea: true,
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
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        _SettingsSection(title: 'صور الملف الشخصي', children: [
          _SettingsTile(icon: Icons.panorama_rounded, title: 'صورة الغلاف', subtitle: 'تظهر أعلى ملفك الشخصي', trailing: _uploadingBanner
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_left_rounded), onTap: _uploadingBanner ? null : () => _changeImage(banner: true)),
          const Divider(height: 1),
          _SettingsTile(icon: Icons.account_circle_outlined, title: 'الصورة الشخصية', subtitle: 'تغيير صورتك من المعرض', trailing: _uploadingAvatar
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_left_rounded), onTap: _uploadingAvatar ? null : () => _changeImage(banner: false)),
        ]),
        const SizedBox(height: 13),
        _SettingsSection(title: 'بيانات الحساب', children: [
          _SettingsTile(icon: Icons.edit_note_rounded, title: 'الاسم والنبذة', subtitle: 'الاسم واسم المستخدم والنبذة الشخصية', onTap: () => _editProfile(me)),
          const Divider(height: 1),
          _SettingsTile(icon: Icons.alternate_email_rounded, title: 'اسم المستخدم', subtitle: '@${me.username ?? me.name}', onTap: () => _editProfile(me)),
          const Divider(height: 1),
          _SettingsTile(icon: Icons.copy_rounded, title: 'معرّف الحساب UID', subtitle: 'اضغط لنسخ معرّفك', onTap: () async {
            await Clipboard.setData(ClipboardData(text: me.uid));
            if (context.mounted) toast(context, 'تم نسخ معرّف الحساب.');
          }),
        ]),
        StreamBuilder<bool>(
          stream: _isAdmin,
          builder: (context, snapshot) => snapshot.data == true
            ? Padding(padding: const EdgeInsets.only(top: 13), child: _SettingsSection(title: 'الإدارة', children: [
                _SettingsTile(icon: Icons.admin_panel_settings_rounded, color: AppColors.tea, title: 'مركز الإدارة', subtitle: 'الأعضاء والأوسمة والإيموجيات وسجل العمليات', onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AdminScreen(me: me)))),
              ]))
            : const SizedBox.shrink(),
        ),
        const SizedBox(height: 13),
        _SettingsSection(title: 'الجلسة', children: [
          _SettingsTile(icon: Icons.logout_rounded, color: AppColors.danger, title: 'تسجيل الخروج', subtitle: 'الخروج من حسابك على هذا الجهاز', onTap: () async {
            final confirmed = await confirmDialog(context, title: 'تسجيل الخروج؟', body: 'تقدر ترجع بأي وقت بنفس الحساب.', ok: 'خروج', danger: true);
            if (confirmed) await Svc.auth.signOut();
          }),
        ]),
      ]),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: Text(title,
      style: const TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w900))),
    Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.line)),
      child: Column(children: children)),
  ]);
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.trailing, this.color});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: (color ?? AppColors.lilac).withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color ?? AppColors.lilac, size: 19)),
    title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
    subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
    trailing: trailing ?? const Icon(Icons.chevron_left_rounded, color: AppColors.textDim),
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
  void dispose() { _name.dispose(); _username.dispose(); _bio.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Svc.users.updateProfile(widget.me.uid, name: _name.text, username: _username.text, bio: _bio.text);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('تم تحديث بيانات الملف الشخصي.')));
      }
    } catch (error) {
      if (mounted) { setState(() => _saving = false); toast(context, error is ArgumentError ? error.message.toString() : 'تعذّر حفظ البيانات: $error'); }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: 18, right: 18, top: 14, bottom: MediaQuery.viewInsetsOf(context).bottom + 18),
    child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('تعديل الملف الشخصي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 16),
      TextField(controller: _name, maxLength: 40, decoration: const InputDecoration(labelText: 'الاسم الظاهر')),
      const SizedBox(height: 10),
      TextField(controller: _username, maxLength: 24, decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixText: '@')),
      const SizedBox(height: 10),
      TextField(controller: _bio, maxLength: 120, minLines: 3, maxLines: 4, decoration: const InputDecoration(labelText: 'النبذة الشخصية', alignLabelWithHint: true)),
      const SizedBox(height: 13),
      FilledButton(onPressed: _saving ? null : _save, child: _saving
        ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
        : const Text('حفظ التغييرات')),
    ])),
  );
}
