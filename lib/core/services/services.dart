import 'admin_service.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'friend_service.dart';
import 'post_service.dart';
import 'user_service.dart';

/// نقطة وصول واحدة للخدمات. كلها تستخدم Firebase بشكل كسول بعد التهيئة.
class Svc {
  Svc._();

  static final auth = AuthService();
  static final users = UserService();
  static final friends = FriendService();
  static final posts = PostService();
  static final chats = ChatService();
  static final admin = AdminService();
}
