import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: LammaMark(size: 76)),
      );
}

/// تظهر إذا قيم Firebase ما انحطت بعد (أو فشلت التهيئة).
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key, this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    Widget step(String n, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
                child: Text(n, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(t, style: const TextStyle(height: 1.6))),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 24),
            const LammaMark(size: 60),
            const SizedBox(height: 22),
            const Text('باقي ربط Firebase',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('التطبيق جاهز، بس لازم تحط قيم مشروعك مرة وحدة.',
                style: TextStyle(color: AppColors.textDim, height: 1.6)),
            const SizedBox(height: 28),
            step('1', 'افتح Firebase Console ← Project settings ← Your apps ← تطبيق Android (com.lamma.social).'),
            step('2', 'انسخ القيم (apiKey, appId, messagingSenderId, projectId, storageBucket) وحطها بالملف lib/firebase_options.dart.'),
            step('3', 'ابنِ التطبيق من جديد. تفاصيل كاملة بملف README.md.'),
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(error!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyState(
          icon: Icons.block_rounded,
          title: 'حسابك موقوف',
          body: 'تم إيقاف حسابك من قبل الإدارة. إذا تعتقد انو خطأ تواصل ويانا.',
          action: OutlinedButton(
            onPressed: Svc.auth.signOut,
            child: const Text('تسجيل الخروج'),
          ),
        ),
      );
}

class ProfileErrorScreen extends StatelessWidget {
  const ProfileErrorScreen({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'ما كدرنا نحمّل حسابك',
          body: 'تأكد من الإنترنت ومن نشر قواعد Firestore، وبعدين جرّب مرة ثانية.',
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
              const SizedBox(height: 10),
              TextButton(onPressed: Svc.auth.signOut, child: const Text('تسجيل الخروج')),
            ],
          ),
        ),
      );
}
