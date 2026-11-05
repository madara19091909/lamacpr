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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final String _uid = context.read<AppUser>().uid;
  late final Stream<bool> _isAdmin = Svc.users.isAdmin(_uid);
  late final Stream<Set<String>> _friends = Svc.friends.watchFriendIds(_uid);
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 88,
    );
    if (x == null) return;
    setState(() => _uploading = true);
    try {
      await Svc.users.updateAvatar(_uid, File(x.path));
    } catch (_) {
      if (mounted) toast(context, 'ما كدرنا نرفع الصورة.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppUser>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('ملفي الشخصي',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.4)),
            ),
            IconButton.filledTonal(
              onPressed: () => _editProfile(context, me),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceHigh,
                foregroundColor: AppColors.lilac,
              ),
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileHero(
          me: me,
          uploading: _uploading,
          onChangePhoto: _changePhoto,
          friends: _friends,
        ),
        const SizedBox(height: 16),
        _ProfileInfoCard(
          title: 'نبذة عني',
          child: Text(
            me.bio.trim().isEmpty ? 'اكتب نبذة بسيطة تعرّف بيها عن نفسك.' : me.bio,
            style: const TextStyle(color: AppColors.textDim, height: 1.7, fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),
        _ProfileInfoCard(
          title: 'الحساب',
          child: Column(
            children: [
              _ProfileAction(
                icon: Icons.fingerprint_rounded,
                title: 'معرّف الحساب',
                subtitle: me.uid,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: me.uid));
                  toast(context, 'تم نسخ المعرّف.');
                },
              ),
              const Divider(height: 20),
              _ProfileAction(
                icon: Icons.edit_note_rounded,
                title: 'تعديل بياناتي',
                subtitle: 'الاسم والنبذة الشخصية',
                onTap: () => _editProfile(context, me),
              ),
              StreamBuilder<bool>(
                stream: _isAdmin,
                builder: (context, s) {
                  if (s.data != true) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const Divider(height: 20),
                      _ProfileAction(
                        icon: Icons.admin_panel_settings_rounded,
                        iconColor: AppColors.tea,
                        title: 'مركز الإدارة',
                        subtitle: 'إدارة الأعضاء والأوسمة والتوثيق',
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
        _ProfileInfoCard(
          title: 'الجلسة',
          child: _ProfileAction(
            icon: Icons.logout_rounded,
            iconColor: AppColors.danger,
            title: 'تسجيل الخروج',
            subtitle: 'الخروج من حسابك على هذا الجهاز',
            textColor: AppColors.danger,
            onTap: () async {
              final ok = await confirmDialog(
                context,
                title: 'تسجيل الخروج؟',
                body: 'تقدر ترجع بأي وقت بنفس الحساب.',
                ok: 'خروج',
                danger: true,
              );
              if (ok) await Svc.auth.signOut();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext context, AppUser me) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditProfileSheet(me: me),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.me,
    required this.uploading,
    required this.onChangePhoto,
    required this.friends,
  });

  final AppUser me;
  final bool uploading;
  final VoidCallback onChangePhoto;
  final Stream<Set<String>> friends;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.violet.withValues(alpha: .46),
            AppColors.surfaceHigh.withValues(alpha: .96),
            const Color(0xFF151B2B),
          ],
        ),
        border: Border.all(color: AppColors.lilac.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(color: AppColors.violet.withValues(alpha: .12), blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: .1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.lilac),
                  SizedBox(width: 5),
                  Text('LAMMA IDENTITY',
                      style: TextStyle(fontSize: 9, letterSpacing: 1.15, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: uploading ? null : onChangePhoto,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(colors: [
                      AppColors.lilac,
                      AppColors.tea,
                      Color(0xFF64D7E6),
                      AppColors.violet,
                      AppColors.lilac,
                    ]),
                    boxShadow: [BoxShadow(color: AppColors.lilac.withValues(alpha: .18), blurRadius: 24)],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
                  child: UserAvatar(name: me.name, photoUrl: me.photoUrl, size: 112),
                ),
                if (uploading)
                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
                else
                  PositionedDirectional(
                    bottom: 2,
                    end: 2,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.lilac,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceHigh, width: 3),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.ink),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(me.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.3)),
              ),
              if (me.verified) ...[
                const SizedBox(width: 7),
                VerificationMark(style: me.verificationStyle, imageUrl: me.verificationImageUrl, size: 22),
              ],
            ],
          ),
          if (me.title.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(me.title,
                style: const TextStyle(color: AppColors.tea, fontWeight: FontWeight.w800, fontSize: 13)),
          ],
          const SizedBox(height: 13),
          StreamBuilder<Set<String>>(
            stream: friends,
            builder: (context, snap) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .055),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: .08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_rounded, size: 15, color: AppColors.lilac),
                    const SizedBox(width: 6),
                    Text('${snap.data?.length ?? 0} صديق',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.textDim, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Text('عضو منذ ${me.createdAt == null ? 'حديثاً' : '${me.createdAt!.month}/${me.createdAt!.year}'}',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
          if (me.badges.isNotEmpty) ...[
            const SizedBox(height: 17),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('الأوسمة والألقاب', style: TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 9),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [for (final badge in me.badges) AppIdentityBadge(badge: badge)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line.withValues(alpha: .8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
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
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: textColor, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
  late final _bio = TextEditingController(text: widget.me.bio);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      toast(context, 'الاسم لازم حرفين على الأقل.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Svc.users.updateProfile(widget.me.uid, name: _name.text, bio: _bio.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'ما كدرنا نحفظ التعديلات.');
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
            TextField(controller: _name, maxLength: 40, decoration: const InputDecoration(hintText: 'الاسم', counterText: '')),
            const SizedBox(height: 14),
            TextField(
              controller: _bio,
              maxLength: 120,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'نبذة عنك'),
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
