import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 38, backgroundColor: Color(0xFF292234), child: Icon(Icons.person, size: 38, color: Color(0xFFB99AFF))),
            SizedBox(height: 14),
            Text('ملفك الشخصي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('راح نربط الحساب وبيانات المستخدم بالمرحلة التالية.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFAAA3B5))),
          ]),
        ),
      );
}
