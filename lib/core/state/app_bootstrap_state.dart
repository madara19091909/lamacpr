import 'package:flutter/foundation.dart';
import '../services/firebase_bootstrap.dart';

class AppBootstrapState extends ChangeNotifier {
  bool isInitializing = true;
  bool firebaseReady = false;
  String? initializationMessage;

  Future<void> initialize() async {
    isInitializing = true;
    notifyListeners();

    try {
      await FirebaseBootstrap.initialize();
      firebaseReady = true;
      initializationMessage = null;
    } catch (error) {
      firebaseReady = false;
      initializationMessage =
          'Firebase is not configured yet. Run FlutterFire configuration.';
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }
}
