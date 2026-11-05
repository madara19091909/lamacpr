import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/models.dart';

class PostService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');

  Stream<List<Post>> watchFeed(String uid) => _posts
      .where('visibleTo', arrayContains: uid)
      .orderBy('createdAt', descending: true)
      .limit(60)
      .snapshots()
      .map((s) => s.docs.map(Post.fromDoc).toList());

  Future<void> create({required AppUser me, required String text, File? image}) async {
    final ref = _posts.doc();
    String? url;
    if (image != null) {
      final file = FirebaseStorage.instance.ref('posts/${me.uid}/${ref.id}.jpg');
      await file.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
      url = await file.getDownloadURL();
    }
    final friends = await _db.collection('users').doc(me.uid).collection('friends').get();
    await ref.set({
      'authorId': me.uid,
      'authorName': me.name,
      'authorPhoto': me.photoUrl,
      'text': text,
      'imageUrl': url,
      'visibleTo': [me.uid, ...friends.docs.map((d) => d.id)],
      'likedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleLike(String postId, String uid, bool currentlyLiked) {
    return _posts.doc(postId).update({
      'likedBy': currentlyLiked ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> delete(Post p) async {
    await _posts.doc(p.id).delete();
    final url = p.imageUrl;
    if (url != null && url.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (_) {
        // المشرف ما عنده صلاحية حذف ملفات Storage؛ المنشور انحذف وهذا يكفي.
      }
    }
  }
}
