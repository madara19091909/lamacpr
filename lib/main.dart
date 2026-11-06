import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var ready = false;
  String? error;
  if (FirebaseBootstrap.isConfigured) {
    try {
      await FirebaseBootstrap.initialize();
      ready = true;
    } catch (e) {
      error = e.toString();
    }
  }

  runApp(LammaApp(firebaseReady: ready, error: error));
}
