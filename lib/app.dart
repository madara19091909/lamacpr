import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/models/models.dart';
import 'core/services/services.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/gate_screens.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_shell.dart';

class LammaApp extends StatelessWidget {
  const LammaApp({super.key, required this.firebaseReady, this.error});

  final bool firebaseReady;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LAMMA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: firebaseReady ? const AuthGate() : SetupRequiredScreen(error: error),
    );
  }
}

/// يقرر شنو يعرض: تسجيل الدخول، أو التطبيق، أو شاشة الحظر.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: Svc.auth.authState,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const SplashScreen();
        final user = snap.data;
        if (user == null) return const LoginScreen();
        return _SignedIn(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class _SignedIn extends StatefulWidget {
  const _SignedIn({super.key, required this.user});
  final User user;

  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  late Future<void> _profile = Svc.users.ensureProfile(widget.user);
  late final Stream<AppUser?> _me = Svc.users.watch(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _profile,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SplashScreen();
        if (snap.hasError) {
          return ProfileErrorScreen(
            onRetry: () => setState(() => _profile = Svc.users.ensureProfile(widget.user)),
          );
        }
        return StreamBuilder<AppUser?>(
          stream: _me,
          builder: (context, s) {
            final me = s.data;
            if (me == null) return const SplashScreen();
            if (me.banned) return const BannedScreen();
            return Provider<AppUser>.value(value: me, child: HomeShell(uid: me.uid));
          },
        );
      },
    );
  }
}
