# تحديث إصلاحات لَمّة (LAMMA)

## ما الذي تغيّر؟

### الواجهات والملفات الشخصية
- إعادة بناء صفحة الملف الشخصي لتعرض الغلاف والصورة والاسم واسم المستخدم والنبذة والأوسمة ومعلومات العضوية.
- فصل تعديل البيانات والصور وإعدادات الحساب ولوحة الإدارة في شاشة إعدادات مستقلة.
- إضافة صفحة ملف عام مستقلة لأي عضو.
- ربط صور الأعضاء في الأصدقاء وطلبات الصداقة والبحث وقائمة المحادثات ورأس المحادثة بفتح الملف العام.
- تكبير شرائح تصفية المحادثات وتحسين تباعدها وإتاحة تمريرها أفقياً.

### الكروبات والمحادثات
- تحميل الأصدقاء مرة واحدة في نافذة إنشاء المجموعة بدلاً من إعادة تحميل القائمة عند كل اختيار.
- السماح بإنشاء مجموعة من المنشئ وصديق واحد على الأقل، مع حد أقصى 50 عضواً.
- إضافة معلومات المجموعة ووصفها، وتغيير الاسم والوصف، وإضافة الأعضاء وإزالتهم، وإدارة المشرفين، ومغادرة المجموعة.
- جعل اسم وصورة ووسام المرسل في رسائل المجموعة محدثة عبر Firestore streams.
- إظهار اسم المرسل ووسامه بجانب رسائله داخل المجموعة.

### الأوسمة والإيموجيات
- إزالة التخزين المؤقت الدائم لملفات المستخدمين حتى لا تبقى الأوسمة والصور والأسماء القديمة ظاهرة.
- دعم الإيموجيات النصية وصور الإيموجي المخصصة من معرض الجهاز أو من رابط صورة HTTP/HTTPS مباشر. صور المعرض تمر عبر Cloudflare Worker إلى قناة Telegram، مثل صور البروفايل والبنرات.
- عرض صور الإيموجيات في المنتقي وداخل نص الرسالة عند جميع المشاركين، واستبدال رمز التخزين الطويل في معاينة المحادثة بعبارة مفهومة.
- تحسين شاشة إدارة الإيموجيات لتعرض الصورة والحالة، وتدعم التفعيل والتعطيل والحذف.
- الإبقاء على أدوات إدارة الحسابات والأوسمة والتوثيق الموجودة وتحسين إشعار نجاح حفظ هوية العضو.

## الملفات المعدّلة

- `lib/core/models/models.dart`
- `lib/core/services/chat_service.dart`
- `lib/core/services/emoji_service.dart`
- `lib/core/services/user_service.dart`
- `lib/core/services/services.dart`
- `lib/core/services/telegram_image_service.dart`
- `lib/core/widgets/emoji_picker.dart`
- `lib/core/widgets/widgets.dart`
- `lib/features/admin/screens/admin_screen.dart`
- `lib/features/chat/screens/chat_screen.dart`
- `lib/features/chat/screens/chats_screen.dart`
- `lib/features/chat/screens/group_chat_screen.dart`
- `lib/features/chat/widgets/chat_message_bubble.dart`
- `lib/features/friends/screens/friends_screen.dart`
- `lib/features/profile/screens/profile_screen.dart`
- `firestore.rules`
- `storage.rules`
- `README.md`
- `TELEGRAM_WORKER_SETUP.txt`
- `cloudflare-worker/worker.js`
- `pubspec.yaml`
- `firebase.json`

## إعداد Cloudflare وFirebase المطلوب قبل اختبار كل شيء

1. انشر ملف `cloudflare-worker/worker.js` على Worker الحالي بعد أخذ نسخة احتياطية، مع الإبقاء على أسرار وبايندنگز Telegram/Firebase الحالية.
2. انشر قواعد Firestore من مجلد المشروع:

   ```bash
   firebase deploy --only firestore:rules
   ```

3. أعد بناء التطبيق وارفع النسخة الجديدة إلى أجهزتك.
4. من لوحة الإدارة ← الإيموجيات، اختر صورة من المعرض أو ألصق رابط صورة مباشر. يجب أن يكون الرابط عاماً ومباشراً إلى ملف صورة.

رفع صور البروفايل والبنرات والأوسمة والتوثيق والإيموجيات من المعرض يمر عبر Worker؛ يجب نشر `cloudflare-worker/worker.js` على Worker الحالي أولاً. لا يحتاج هذا الإصدار إلى Firebase Storage لرفع الصور.

## حدود الاختبار في بيئة إعداد الحزمة

تم فحص ملفات Worker بجافاسكربت والتحقق من مساري رفع الملف واسترجاعه باختبار محلي محاكى، والتحقق من ملفات YAML وJSON والاستيرادات المحلية وعدم بقاء استدعاءات Firebase Storage في كود Dart التشغيلي. لم يتوفر Flutter SDK أو Dart SDK في بيئة إعداد هذه الحزمة، لذلك لم أتمكن من تشغيل `flutter analyze` أو بناء APK فعلياً. يلزم تنفيذ فحص البناء من بيئة Flutter قبل نشر نسخة الإنتاج.
