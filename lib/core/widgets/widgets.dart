import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';

/// شعار لَمّة: ثلاث دوائر متداخلة (ناس مجتمعين).
class LammaMark extends StatelessWidget {
  const LammaMark({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _MarkPainter()),
      );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width * 0.27;
    final centers = [
      Offset(s.width * 0.36, s.height * 0.38),
      Offset(s.width * 0.64, s.height * 0.38),
      Offset(s.width * 0.50, s.height * 0.64),
    ];
    final colors = [AppColors.lilac, AppColors.tea, AppColors.violet];
    for (var i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = colors[i].withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.08;
      canvas.drawCircle(centers[i], r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.photoUrl, this.size = 44});

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first);
    final hue = (name.hashCode.abs() % 360).toDouble();
    final bg = HSLColor.fromAHSL(1, hue, 0.35, 0.26).toColor();
    final fg = HSLColor.fromAHSL(1, hue, 0.7, 0.8).toColor();

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: bg,
      child: Text(
        initial,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: size * 0.42),
      ),
    );

    final url = photoUrl;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: (url == null || url.isEmpty)
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                ),
                child: Icon(icon, size: 30, color: AppColors.lilac),
              ),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(body!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textDim, height: 1.6)),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      );
}

/// عنوان قسم صغير داخل القوائم.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppColors.textDim, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// صف شخص موحّد (أصدقاء، بحث، طلبات).
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.name,
    this.photoUrl,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.verified = false,
    this.verificationStyle = 'classic',
    this.verificationImageUrl,
    this.badges = const [],
  });

  final String name;
  final String? photoUrl;
  final String? subtitle;
  final Widget? trailing;
  final bool verified;
  final String verificationStyle;
  final String? verificationImageUrl;
  final List<AppBadge> badges;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              UserAvatar(name: name, photoUrl: photoUrl, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 5),
                          VerificationMark(style: verificationStyle, imageUrl: verificationImageUrl, size: 16),
                        ],
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                      ),
                    if (badges.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [for (final badge in badges.take(2)) AppIdentityBadge(badge: badge, compact: true)],
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      );
}

String timeAgo(DateTime? t) {
  if (t == null) return 'الآن';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'الآن';
  if (d.inMinutes < 60) return 'قبل ${d.inMinutes} د';
  if (d.inHours < 24) return 'قبل ${d.inHours} س';
  if (d.inDays < 7) return 'قبل ${d.inDays} يوم';
  return '${t.day}/${t.month}/${t.year}';
}

String clock(DateTime? t) {
  if (t == null) return '';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'ص' : 'م'}';
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String ok = 'تأكيد',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      content: Text(body, style: const TextStyle(color: AppColors.textDim, height: 1.6)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء', style: TextStyle(color: AppColors.textDim)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok,
              style: TextStyle(
                  color: danger ? AppColors.danger : AppColors.lilac,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result == true;
}

/// شارة العضوية/اللقب التي يمنحها المشرف.
class AppIdentityBadge extends StatelessWidget {
  const AppIdentityBadge({super.key, required this.badge, this.compact = false});
  final AppBadge badge;
  final bool compact;

  IconData get _icon => switch (badge.icon) {
        'crown' => Icons.workspace_premium_rounded,
        'bolt' => Icons.bolt_rounded,
        'diamond' => Icons.diamond_rounded,
        'heart' => Icons.favorite_rounded,
        'shield' => Icons.shield_rounded,
        'fire' => Icons.local_fire_department_rounded,
        'leaf' => Icons.eco_rounded,
        'star' => Icons.star_rounded,
        _ => Icons.auto_awesome_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = Color(badge.color);
    final dark = Color.lerp(color, Colors.black, .32)!;
    final radius = switch (badge.style) {
      'shield' => 9.0,
      'ribbon' => 7.0,
      'capsule' => 30.0,
      _ => 14.0,
    };
    final decoration = BoxDecoration(
      color: badge.style == 'outline'
          ? color.withValues(alpha: .07)
          : badge.style == 'glass'
              ? color.withValues(alpha: .13)
              : badge.style == 'glow'
                  ? color.withValues(alpha: .17)
                  : null,
      gradient: badge.style == 'gradient'
          ? LinearGradient(colors: [color, dark], begin: Alignment.topLeft, end: Alignment.bottomRight)
          : null,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: badge.style == 'outline' || badge.style == 'glass'
            ? color.withValues(alpha: .75)
            : color.withValues(alpha: .36),
        width: badge.style == 'outline' ? 1.3 : 1,
      ),
      boxShadow: badge.style == 'glow'
          ? [BoxShadow(color: color.withValues(alpha: .24), blurRadius: 12, spreadRadius: 1)]
          : null,
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11, vertical: compact ? 5 : 7),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge.imageUrl != null && badge.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 4 : 6),
              child: CachedNetworkImage(
                imageUrl: badge.imageUrl!,
                width: compact ? 15 : 21,
                height: compact ? 15 : 21,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(_icon, size: compact ? 12 : 14, color: badge.style == 'gradient' ? Colors.white : color),
              ),
            )
          else
            Icon(_icon, size: compact ? 12 : 14, color: badge.style == 'gradient' ? Colors.white : color),
          const SizedBox(width: 5),
          Text(
            badge.label,
            style: TextStyle(
              color: badge.style == 'gradient' ? Colors.white : color,
              fontSize: compact ? 10 : 11,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// علامة التوثيق؛ أكثر من هيئة بصرية يحددها المشرف.
class VerificationMark extends StatelessWidget {
  const VerificationMark({super.key, this.style = 'classic', this.imageUrl, this.size = 20});
  final String style;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = switch (style) {
      'gold' => const Color(0xFFFFC45C),
      'purple' => const Color(0xFFC3A0FF),
      'cyan' => const Color(0xFF69D9E8),
      'rose' => const Color(0xFFFF91B8),
      _ => const Color(0xFF62B7FF),
    };
    final icon = switch (style) {
      'star' => Icons.stars_rounded,
      'diamond' => Icons.diamond_rounded,
      'shield' => Icons.verified_user_rounded,
      'seal' => Icons.workspace_premium_rounded,
      _ => Icons.verified_rounded,
    };
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: .65), width: 1.2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .22), blurRadius: 7)],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Icon(Icons.verified_rounded, size: size * .7, color: color),
            errorWidget: (_, __, ___) => Icon(Icons.verified_rounded, size: size * .7, color: color),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        shape: style == 'diamond' ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: style == 'diamond' ? BorderRadius.circular(size * .22) : null,
        boxShadow: [BoxShadow(color: color.withValues(alpha: .18), blurRadius: 8)],
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}
