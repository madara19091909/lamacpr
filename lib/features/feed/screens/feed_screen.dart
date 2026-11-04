import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('LAMMA', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('هلا باللَمّة 👋', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: const Row(
            children: [
              CircleAvatar(backgroundColor: AppColors.surfaceElevated, child: Icon(Icons.person, color: AppColors.primaryLight)),
              SizedBox(width: 12),
              Expanded(child: Text('شنو أخباركم اليوم؟ شاركونا...')),
              Icon(Icons.add_circle, color: AppColors.primaryLight, size: 28),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('المنشورات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const _EmptyFeedCard(),
      ],
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  const _EmptyFeedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: const Column(
        children: [
          Icon(Icons.forum_outlined, size: 38, color: AppColors.primaryLight),
          SizedBox(height: 10),
          Text('بداية لَمّة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          Text('من تنشرون أول بوست راح يظهر هنا.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
