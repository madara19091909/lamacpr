import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../admin/screens/admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final String _uid = context.read<AppUser>().uid;
  late final Stream<bool> _isAdmin = Svc.users.isAdmin(_uid);
  late final Stream<Set<String>> _friends = Svc.friends.watchFriendIds(_uid);
  bool _uploadingAvatar = false;
  bool _uploadingBanner = false;

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
      if (mounted) {
        toast(context, banner
            ? 'ما كدرنا نرفع الغلاف. تأكد من قواعد Firebase Storage.'
            : 'ما كدرنا نحدّث صورة الحساب. تأكد من قواعد Firebase Storage.');
      }
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
    final me = context.watch<AppUser>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 30),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('ملفي الشخصي', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            ),
            IconButton.filledTonal(
              tooltip: 'تعديل الملف الشخصي',
              onPressed: () => _editProfile(me),
              style: IconButton.styleFrom(backgroundColor: AppColors.surfaceHigh, foregroundColor: AppColors.lilac),
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ),
        const SizedBox(height: 13),
        _ProfileHero(
          me: me,
          friends: _friends,
          uploadingAvatar: _uploadingAvatar,
          uploadingBanner: _uploadingBanner,
          onChangeAvatar: () => _changeImage(banner: false),
          onChangeBanner: () => _changeImage(banner: true),
          onEdit: () => _editProfile(me),
        ),
        const SizedBox(height: 14),
        _ProfileSection(
          title: 'نبذة عني',
          icon: Icons.auto_awesome_rounded,
          child: Text(
            me.bio.trim().isEmpty ? 'اكتب نبذة قصيرة تعرّف بيها عن نفسك.' : me.bio,
            style: const TextStyle(color: AppColors.textDim, height: 1.75, fontSize: 13),
          ),
        ),
        if (me.badges.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'أوسمتي',
            icon: Icons.workspace_premium_outlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final badge in me.badges) AppIdentityBadge(badge: badge)],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _ProfileSection(
          title: 'الحساب والخصوصية',
          icon: Icons.shield_outlined,
          child: Column(
            children: [
              _ProfileAction(
                icon: Icons.alternate_email_rounded,
                title: 'اسم المستخدم',
                subtitle: '@${me.username ?? me.name}',
                onTap: () => _editProfile(me),
              ),
              const Divider(height: 19),
              _ProfileAction(
                icon: Icons.edit_note_rounded,
                title: 'تعديل بياناتي',
                subtitle: 'تغيير الاسم واسم المستخدم والنبذة',
                onTap: () => _editProfile(me),
              ),
              StreamBuilder<bool>(
                stream: _isAdmin,
                builder: (context, snapshot) {
                  if (snapshot.data != true) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const Divider(height: 19),
                      _ProfileAction(
                        icon: Icons.admin_panel_settings_rounded,
                        iconColor: AppColors.tea,
                        title: 'مركز الإدارة',
                        subtitle: 'إدارة الأعضاء والأوسمة وإيموجيات التطبيق',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => AdminScreen(me: me)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ProfileSection(
          title: 'الجلسة',
          icon: Icons.devices_outlined,
          child: _ProfileAction(
            icon: Icons.logout_rounded,
            iconColor: AppColors.danger,
            title: 'تسجيل الخروج',
            subtitle: 'الخروج من حسابك على هذا الجهاز',
            textColor: AppColors.danger,
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
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'LAMMA  •  قريبين، حتى لو بعيدين',
            style: TextStyle(color: AppColors.textDim, fontSize: 10, letterSpacing: .3),
          ),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.me,
    required this.friends,
    required this.uploadingAvatar,
    required this.uploadingBanner,
    required this.onChangeAvatar,
    required this.onChangeBanner,
    required this.onEdit,
  });

  final AppUser me;
  final Stream<Set<String>> friends;
  final bool uploadingAvatar;
  final bool uploadingBanner;
  final VoidCallback onChangeAvatar;
  final VoidCallback onChangeBanner;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final username = (me.username ?? me.name).replaceFirst(RegExp(r'^@'), '').replaceAll(' ', '_');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: AppColors.lilac.withValues(alpha: .2)),
        boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: .10), blurRadius: 25, offset: const Offset(0, 9))],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 158,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (me.bannerUrl != null && me.bannerUrl!.isNotEmpty)
                  Image.network(
                    me.bannerUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _DefaultBanner(),
                  )
                else
                  const _DefaultBanner(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: .03), Colors.black.withValues(alpha: .55)],
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: OutlinedButton.icon(
                    onPressed: uploadingBanner ? null : onChangeBanner,
                    icon: uploadingBanner
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image_outlined, size: 16),
                    label: const Text('تغيير الغلاف'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: .26),
                      side: BorderSide(color: Colors.white.withValues(alpha: .35)),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const PositionedDirectional(
                  bottom: 14,
                  start: 17,
                  child: Text('LAMMA MEMBER',
                      style: TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -42),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: uploadingAvatar ? null : onChangeAvatar,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 94,
                              height: 94,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(colors: [AppColors.lilac, AppColors.tea, Color(0xFF64D7E6), AppColors.violet, AppColors.lilac]),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                              child: UserAvatar(name: me.name, photoUrl: me.photoUrl, size: 86),
                            ),
                            if (uploadingAvatar)
                              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.2))
                            else
                              PositionedDirectional(
                                bottom: 1,
                                end: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: AppColors.lilac, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.ink, size: 13),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: FilledButton.tonalIcon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('تعديل الحساب'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.lilac.withValues(alpha: .14),
                            foregroundColor: AppColors.lilac,
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -31),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(me.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          ),
                          if (me.verified) ...[
                            const SizedBox(width: 6),
                            VerificationMark(style: me.verificationStyle, imageUrl: me.verificationImageUrl, size: 19),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('@$username', style: const TextStyle(color: AppColors.lilac, fontSize: 12, fontWeight: FontWeight.w800)),
                      if (me.title.trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(me.title, style: const TextStyle(color: AppColors.tea, fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                      const SizedBox(height: 17),
                      Container(height: 1, color: AppColors.line),
                      const SizedBox(height: 15),
                      StreamBuilder<Set<String>>(
                        stream: friends,
                        builder: (context, snapshot) => Row(
                          children: [
                            Expanded(
                              child: _ProfileStat(
                                icon: Icons.people_alt_rounded,
                                value: '${snapshot.data?.length ?? 0}',
                                label: 'أصدقاء',
                              ),
                            ),
                            Container(width: 1, height: 34, color: AppColors.line),
                            Expanded(
                              child: _ProfileStat(
                                icon: Icons.calendar_month_rounded,
                                value: me.createdAt == null ? '—' : '${me.createdAt!.month}/${me.createdAt!.year}',
                                label: 'تاريخ الانضمام',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultBanner extends StatelessWidget {
  const _DefaultBanner();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF8768E4), Color(0xFF362953), Color(0xFF171522)],
          ),
        ),
        child: Stack(
          children: [
            PositionedDirectional(top: -48, end: -16, child: _BannerOrb(size: 170)),
            PositionedDirectional(bottom: -66, start: 90, child: _BannerOrb(size: 140)),
          ],
        ),
      );
}

class _BannerOrb extends StatelessWidget {
  const _BannerOrb({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .09), width: 19),
        ),
      );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppColors.lilac),
              const SizedBox(width: 5),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
        ],
      );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.lilac, size: 17),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 13),
            child,
          ],
        ),
      );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.lilac,
    this.textColor = AppColors.text,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: textColor, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: AppColors.textDim, size: 19),
            ],
          ),
        ),
      );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.me});
  final AppUser me;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.me.name);
  late final _username = TextEditingController(text: (widget.me.username ?? widget.me.name.replaceAll(' ', '_')).replaceFirst(RegExp(r'^@'), ''));
  late final _bio = TextEditingController(text: widget.me.bio);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      toast(context, 'الاسم لازم حرفين على الأقل.');
      return;
    }
    if (_username.text.trim().replaceAll(' ', '_').length < 3) {
      toast(context, 'اسم المستخدم لازم 3 أحرف على الأقل.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Svc.users.updateProfile(
        widget.me.uid,
        name: _name.text,
        username: _username.text,
        bio: _bio.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, error is ArgumentError ? error.message.toString() : 'ما كدرنا نحفظ التعديلات.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تعديل الملف الشخصي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            TextField(controller: _name, maxLength: 40, decoration: const InputDecoration(labelText: 'الاسم الظاهر', counterText: '')),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              maxLength: 24,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                prefixText: '@',
                helperText: 'تقدر تستخدمه حتى يعرفك أصدقاؤك بالبحث.',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLength: 120,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'نبذة عنك'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.ink))
                    : const Text('حفظ التغييرات'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
