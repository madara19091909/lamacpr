import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/state/app_bootstrap_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrapState = AppBootstrapState();
  await bootstrapState.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: bootstrapState,
      child: const LammaApp(),
    ),
  );
}
