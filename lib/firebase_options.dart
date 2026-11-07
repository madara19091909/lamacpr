import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBzUbFda4UbmgPN-V3nmMsREfHgtJFDOFI',
    appId: '1:367651984174:android:e68ba5a74b937120dc60bf',
    messagingSenderId: '367651984174',
    projectId: 'lamma-9a231',
    storageBucket: 'lamma-9a231.firebasestorage.app',
  );
}
