import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

class AuthService {
  /// الاسم اللي كتبه المستخدم أثناء إنشاء الحساب، يستخدمه UserService
  /// لحظة إنشاء الملف الشخصي (قبل ما يوصل displayName من Firebase).
  static String? pendingName;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> get authState => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signUp(String name, String email, String password) async {
    pendingName = name.trim();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      try {
        await cred.user?.updateDisplayName(name.trim());
      } catch (_) {
        // الحساب انفتح فعلاً؛ الاسم محفوظ أصلاً عبر pendingName بملف Firestore.
      }
    } finally {
      // ensureProfile يشتغل مباشرة بعد الإنشاء؛ نمسح الاسم بعد فترة قصيرة.
      Future<void>.delayed(const Duration(seconds: 5), () => pendingName = null);
    }
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// يرجع false إذا المستخدم لغى النافذة.
  Future<bool> signInWithGoogle() async {
    final google = GoogleSignIn(serverClientId: AppConfig.googleWebClientId);
    final account = await google.signIn();
    if (account == null) return false;
    final tokens = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
    await _auth.signInWithCredential(credential);
    return true;
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  static String message(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'صيغة الإيميل غير صحيحة.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'الإيميل أو كلمة السر غلط.';
        case 'email-already-in-use':
          return 'هذا الإيميل مسجّل من قبل.';
        case 'weak-password':
          return 'كلمة السر ضعيفة، استخدم 6 أحرف على الأقل.';
        case 'network-request-failed':
          return 'ما كو اتصال بالإنترنت.';
        case 'too-many-requests':
          return 'محاولات كثيرة، انتظر شوية وجرّب.';
        case 'operation-not-allowed':
          return 'هذي الطريقة غير مفعّلة بمشروع Firebase.';
        case 'user-disabled':
          return 'هذا الحساب موقوف.';
      }
    }
    return 'صار خطأ غير متوقع، حاول مرة ثانية.';
  }
}
