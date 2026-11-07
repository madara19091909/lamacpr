import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// إدارة إيموجيات LAMMA التي يضيفها المشرف وتظهر داخل منتقي الإيموجي.
class EmojiService {
  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('app_emojis');

  Stream<List<AppEmoji>> watchActive() => _collection
      .where('enabled', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(AppEmoji.fromDoc).toList());

  Stream<List<AppEmoji>> watchAll() => _collection
      .snapshots()
      .map((snapshot) => snapshot.docs.map(AppEmoji.fromDoc).toList());

  Future<void> add({required String emoji, required String label}) async {
    final value = emoji.trim();
    final title = label.trim();
    if (value.isEmpty || value.runes.length > 8) {
      throw ArgumentError('أدخل إيموجي واحداً صالحاً.');
    }
    if (title.length > 30) {
      throw ArgumentError('اسم الإيموجي يجب ألا يتجاوز 30 حرفاً.');
    }
    await _collection.add({
      'emoji': value,
      'label': title,
      'enabled': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setEnabled(String id, bool enabled) =>
      _collection.doc(id).update({'enabled': enabled});

  Future<void> delete(String id) => _collection.doc(id).delete();
}
