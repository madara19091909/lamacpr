import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool get isConfigured =>
      !DefaultFirebaseOptions.currentPlatform.apiKey.startsWith('PASTE_');

  static Future<void> initialize() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}
