import 'admin_service.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'friend_service.dart';
import 'emoji_service.dart';
import 'user_service.dart';
import 'telegram_image_service.dart';

/// نقطة وصول واحدة للخدمات. كلها تستخدم Firebase بشكل كسول بعد التهيئة.
class Svc {
  Svc._();

  static final auth = AuthService();
  static final users = UserService();
  static final friends = FriendService();
  static final chats = ChatService();
  static final admin = AdminService();
  static final emojis = EmojiService();
  static final telegramImages = TelegramImageService();
}
