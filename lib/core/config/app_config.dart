/// إعدادات يدوية صغيرة. القيم تنلصق من Firebase Console.
class AppConfig {
  AppConfig._();

  /// Web client ID: Authentication > Sign-in method > Google > Web SDK configuration.
  /// مطلوب فقط لزر "الدخول بجوجل". إذا خليته PASTE_ الزر ما يظهر.
  static const googleWebClientId = 'PASTE_WEB_CLIENT_ID';

  static bool get googleEnabled => !googleWebClientId.startsWith('PASTE_');
}
