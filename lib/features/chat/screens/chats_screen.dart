import 'package:flutter/material.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _SectionScreen(
        title: 'المحادثات',
        subtitle: 'هنا راح تظهر محادثاتك الخاصة والكروبات.',
        icon: Icons.chat_bubble_outline,
      );
}

class _SectionScreen extends StatelessWidget {
  const _SectionScreen({required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: const Color(0xFFB99AFF)),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFAAA3B5))),
          ]),
        ),
      );
}
