import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void> initialize() async {
    if (Firebase.apps.isNotEmpty) return;

    // Android Firebase configuration must be added before runtime:
    // use FlutterFire CLI and generate firebase_options.dart, then replace
    // this call with Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).
    await Firebase.initializeApp();
  }
}
