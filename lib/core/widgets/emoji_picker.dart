import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';

Future<String?> showLammaEmojiPicker(
  BuildContext context,
  Stream<List<AppEmoji>> emojis,
) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surfaceHigh,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .42,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDim.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 15, 18, 10),
              child: Row(
                children: [
                  Icon(Icons.emoji_emotions_rounded, color: AppColors.lilac),
                  SizedBox(width: 9),
                  Text(
                    'إيموجيات لَمّة',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<AppEmoji>>(
                stream: emojis,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'تعذّر تحميل الإيموجيات',
                        style: TextStyle(color: AppColors.textDim),
                      ),
                    );
                  }
                  final items = snapshot.data;
                  if (items == null) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'ماكو إيموجيات مخصصة حالياً. يگدر المشرف يضيفها من لوحة الإدارة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textDim, height: 1.6),
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Tooltip(
                        message: item.label,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(sheetContext, item.emoji),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .055),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(item.emoji, style: const TextStyle(fontSize: 27)),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
