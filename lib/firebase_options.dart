import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// ضع قيم مشروعك هنا (Firebase Console > Project settings > Your apps > Android).
/// أو شغّل `flutterfire configure` وهو راح يستبدل هذا الملف تلقائياً.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PASTE_API_KEY', // current_key
    appId: 'PASTE_APP_ID', // mobilesdk_app_id
    messagingSenderId: 'PASTE_SENDER_ID', // project_number
    projectId: 'PASTE_PROJECT_ID', // project_id
    storageBucket: 'PASTE_STORAGE_BUCKET', // storage_bucket
  );

  static FirebaseOptions get currentPlatform => android;
}
