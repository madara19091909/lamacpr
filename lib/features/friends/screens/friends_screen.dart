import 'package:flutter/material.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.people_outline, size: 48, color: Color(0xFFB99AFF)),
            SizedBox(height: 14),
            Text('الأصدقاء', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('طلبات الصداقة وقائمة أصدقائك راح تكون هنا.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFAAA3B5))),
          ]),
        ),
      );
}
