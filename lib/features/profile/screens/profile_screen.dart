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
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await Svc.users.updateAvatar(_uid, File(image.path));
    } catch (_) {
      if (mounted) toast(context, 'ما كدرنا نحدّث صورة الحساب.');
    } finally {
      if (mounted) setState(() => _uploading = false);
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
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceHigh,
                foregroundColor: AppColors.lilac,
              ),
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ),
        const SizedBox(height: 13),
        _IdentityCard(
          me: me,
          uploading: _uploading,
          friends: _friends,
          onChangePhoto: _changePhoto,
          onEdit: () => _editProfile(me),
          onCopyId: () {
            Clipboard.setData(ClipboardData(text: me.uid));
            toast(context, 'تم نسخ معرّف LAMMA.');
          },
        ),
        const SizedBox(height: 14),
        _ProfileSection(
          title: 'نبذة شخصية',
          icon: Icons.person_pin_circle_outlined,
          child: Text(
            me.bio.trim().isEmpty ? 'ما كتبت نبذة عنك لحد الآن.' : me.bio,
            style: const TextStyle(color: AppColors.textDim, height: 1.75, fontSize: 13),
          ),
        ),
        if (me.badges.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'أوسمتك',
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
                icon: Icons.fingerprint_rounded,
                title: 'معرّف LAMMA',
                subtitle: 'معرّفك الخاص للعثور على حسابك',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: me.uid));
                  toast(context, 'تم نسخ المعرّف.');
                },
              ),
              const Divider(height: 19),
              _ProfileAction(
                icon: Icons.edit_note_rounded,
                title: 'تعديل بياناتي',
                subtitle: 'تغيير الاسم والنبذة الشخصية',
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

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.me,
    required this.uploading,
    required this.friends,
    required this.onChangePhoto,
    required this.onEdit,
    required this.onCopyId,
  });

  final AppUser me;
  final bool uploading;
  final Stream<Set<String>> friends;
  final VoidCallback onChangePhoto;
  final VoidCallback onEdit;
  final VoidCallback onCopyId;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.lilac.withValues(alpha: .19)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 112,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF7656C8), Color(0xFF342A55), Color(0xFF1B1A2B)],
                  ),
                ),
              ),
              PositionedDirectional(
                top: -48,
                end: -25,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .08), width: 20),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: 12,
                start: 18,
                child: Row(
                  children: const [
                    Icon(Icons.auto_awesome_rounded, color: AppColors.lilac, size: 13),
                    SizedBox(width: 6),
                    Text('LAMMA IDENTITY', style: TextStyle(fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              PositionedDirectional(
                top: 10,
                end: 11,
                child: IconButton(
                  onPressed: onEdit,
                  tooltip: 'تعديل الملف',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .1),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                ),
              ),
            ],
          ),
          Transform.translate(
            offset: const Offset(0, -39),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: uploading ? null : onChangePhoto,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 94,
                          height: 94,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const SweepGradient(
                              colors: [AppColors.lilac, AppColors.tea, Color(0xFF64D7E6), AppColors.violet, AppColors.lilac],
                            ),
                            boxShadow: [
                              BoxShadow(color: AppColors.lilac.withValues(alpha: .2), blurRadius: 22),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                          child: UserAvatar(name: me.name, photoUrl: me.photoUrl, size: 86),
                        ),
                        if (uploading)
                          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
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
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          me.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (me.verified) ...[
                        const SizedBox(width: 7),
                        VerificationMark(
                          style: me.verificationStyle,
                          imageUrl: me.verificationImageUrl,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                  if (me.title.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(me.title, style: const TextStyle(color: AppColors.tea, fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                  const SizedBox(height: 13),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onCopyId,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fingerprint_rounded, color: AppColors.lilac, size: 16),
                          const SizedBox(width: 7),
                          Text(
                            'LAMMA ID  ${_shortId(me.uid)}',
                            style: const TextStyle(color: AppColors.textDim, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 7),
                          const Icon(Icons.copy_rounded, color: AppColors.textDim, size: 13),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  StreamBuilder<Set<String>>(
                    stream: friends,
                    builder: (context, snapshot) {
                      return Row(
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
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('تعديل الملف الشخصي'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 0),
        ],
      ),
    );
  }

  String _shortId(String uid) {
    if (uid.length <= 18) return uid;
    return '${uid.substring(0, 8)}…${uid.substring(uid.length - 6)}';
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
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
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                    ),
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
