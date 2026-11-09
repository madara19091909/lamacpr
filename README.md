# لَمّة (LAMMA)

تطبيق دردشة خاص للأصدقاء: أصدقاء، محادثات فردية وكروبات، ولوحة إدارة للمالك فقط.
Flutter + Firebase Auth/Firestore, مع تخزين الصور عبر Cloudflare Workers + Telegram Bot + Telegram Channel.

## شنو بالتطبيق

- **تسجيل الدخول**: إيميل وكلمة سر (يشتغل مباشرة)، وجوجل (اختياري، شوف القسم 5).
- **الأصدقاء**: بحث بالاسم، إرسال/قبول/رفض طلبات، إزالة صديق.
- **المحادثات**: واجهة زجاجية داكنة، بحث وفلاتر للكل/غير المقروء/المجموعات، ومراسلة خاصة فورية.
- **الكروبات**: إنشاء مجموعة مع الأصدقاء، حتى 50 عضواً، ورسائل مباشرة مع اسم المرسل.
- **حسابي**: بروفايل مطوّر، تعديل الاسم والنبذة والصورة، عرض الأوسمة والألقاب والتوثيق.
- **لوحة الإدارة**: إحصائيات، إدارة الأعضاء والحظر، منح الأوسمة والألقاب بتصاميم وألوان وأيقونات قابلة للاختيار، والتحكم بعلامة التوثيق، وإدارة الإيموجيات.

## 1) مشروع Firebase

1. أنشئ مشروع بـ [Firebase Console](https://console.firebase.google.com).
2. أضف تطبيق **Android** باسم الحزمة `com.lamma.social`.
3. فعّل **Authentication ← Sign-in method ← Email/Password**.
4. أنشئ **Firestore Database** (Production mode). لا تحتاج إلى تفعيل Firebase Storage لرفع الصور؛ الرفع يمر عبر Cloudflare Worker إلى قناة Telegram.

## 2) ربط التطبيق (طريقتين، اختار وحدة)

**أ) يدوي (أبسط شي بالموبايل):** افتح `lib/firebase_options.dart` وحط القيم من
Project settings ← Your apps ← Android (أو من ملف google-services.json):

| الحقل | مكانه بـ google-services.json |
|---|---|
| apiKey | client[0].api_key[0].current_key |
| appId | client[0].client_info.mobilesdk_app_id |
| messagingSenderId | project_info.project_number |
| projectId | project_info.project_id |
| storageBucket | project_info.storage_bucket |

**ب) FlutterFire CLI:** `dart pub global activate flutterfire_cli` ثم `flutterfire configure`
(يستبدل نفس الملف تلقائياً).

إذا ما حطيت القيم، التطبيق يفتح على شاشة "باقي ربط Firebase" بدل ما ينهار.

## 3) نشر القواعد والفهارس (ضروري)

بدون هذي الخطوة الرئيسية والمحادثات ما تحمّل.

```bash
npm i -g firebase-tools
firebase login
firebase use --add            # اختار مشروعك
firebase deploy --only firestore:rules,firestore:indexes
```

أو يدوياً من Console: انسخ `firestore.rules` إلى Firestore ← Rules. لا تنشر `storage.rules` لهذا الإصدار لأن التطبيق لا يستخدم Firebase Storage للصور.
الفهارس (`firestore.indexes.json`) إذا ما نشرتها بالـ CLI، أول مرة يطلع خطأ فهرس بالـ logs
ومعه رابط ينشئه بضغطة وحدة.

## 4) تصير أنت المشرف

1. افتح التطبيق وسجّل حسابك.
2. من تبويب **حسابي** اضغط **معرّف الحساب (UID)** لنسخه.
3. Firebase Console ← Firestore ← **Start collection** باسم `admins`
   ← Document ID = الـ UID اللي نسخته (الحقول ما تهم، ضيف أي حقل).
4. ارجع للتطبيق: راح يطلع بحسابك خيار **لوحة الإدارة**.

الحماية من جهة السيرفر: قواعد Firestore تمنع أي كتابة على `admins` من التطبيق، وكل عمليات
الإدارة (قراءة كل المستخدمين، الحظر، حذف منشورات الغير) تتحقق منها القواعد نفسها.
يعني حتى لو أحد عدّل التطبيق وفتح الشاشة، السيرفر يرفضه.
المحادثات الخاصة ما تنقرأ من أحد حتى المشرف.

## 5) الدخول بجوجل (اختياري)

الدخول بالإيميل يشتغل بدونها. إذا تريد جوجل:

1. Authentication ← Sign-in method ← فعّل **Google**، وانسخ **Web client ID** وحطه بـ
   `lib/core/config/app_config.dart` (`googleWebClientId`). بعدها الزر يظهر تلقائياً.
2. لازم بصمة SHA-1 ثابتة. بناء GitHub Actions العادي يولّد مفتاح جديد كل مرة، فسوّي مفتاح ثابت:
   ```bash
   keytool -genkey -v -keystore debug.keystore -storepass android -alias androiddebugkey \
     -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
     -dname "CN=Android Debug,O=Android,C=US"
   base64 -w0 debug.keystore      # انسخ الناتج
   keytool -list -v -keystore debug.keystore -storepass android | grep SHA   # بصماتك
   ```
3. GitHub ← Settings ← Secrets ← Actions ← سرّ جديد `DEBUG_KEYSTORE_BASE64` وقيمته الناتج.
4. حط بصمتي SHA-1 و SHA-256 بتطبيق Android داخل Firebase (Project settings).

## 6) بناء الـ APK

Actions ← **Build LAMMA APK** ← Run workflow، وبعدها نزّل `lamma-release-apk`.
الـ workflow يرفع minSdk إلى 23 تلقائياً (مطلوب لـ Firebase).

## الهوية والأوسمة والكروبات

- من لوحة الإدارة ← المستخدمون ← زر التاج بجانب العضو: أضف حتى 8 أوسمة لكل عضو.
- كل وسام يدعم اسماً مخصصاً، أيقونة، نمطاً بصرياً (متدرّج، إطار، توهّج، زجاجي، درع، شريط، كبسولة)، ولوناً من اللوحة أو قيمة HEX مخصصة.
- يمكن تشغيل التوثيق واختيار لونه/هيئته، وإضافة لقب رئيسي مثل «المؤسس» أو «المشرف العام».
- الأوسمة والتوثيق لا يستطيع العضو تعديلهما من حسابه؛ قواعد Firestore تسمح بذلك للمشرف فقط.
- إنشاء المجموعة متاح من تبويب المحادثات. يلزم اختيار صديق واحد على الأقل بالإضافة إلى المنشئ، والحد الأقصى 50 عضواً.
- المحادثات الخاصة تبقى خاصة بأعضائها فقط، حتى حسابات الإدارة لا تستطيع قراءة الرسائل.

## ملاحظات تصميمية

- إذا حذفت صديقاً تتوقف المراسلة بينكما في المحادثة المباشرة (تفرضه قواعد Firestore).
- الحساب المحظور لا يستطيع قراءة المحادثات أو الرسائل حتى لو عدّل التطبيق.
- الرسالة: من 1 إلى 2000 حرف، والخادم يتحقق من المرسل ووقت الإرسال.
- ما كو إشعارات Push: تحتاج Cloud Functions (خطة Blaze). تنضاف لاحقاً.


## Cloudflare + Telegram media uploads

All gallery uploads in the app (profile avatar, banner, custom badge, verification mark,
and custom chat emoji) use the same path:

`Flutter -> Cloudflare Worker -> Telegram Bot -> Telegram Channel`.

Keep `TELEGRAM_BOT_TOKEN` as a Cloudflare Secret, `TELEGRAM_CHANNEL_ID` as a Worker
binding, and `FIREBASE_API_KEY` as a Worker binding. The bot must be an administrator
in the channel with permission to post. The Worker validates Firebase ID tokens and
checks `admins/{uid}` before accepting badge, verification, or emoji artwork.

The companion Worker source is `cloudflare-worker/worker.js`; deployment steps and
binding names are in `TELEGRAM_WORKER_SETUP.txt`. Back up the currently deployed Worker
before replacing its source. Do not commit bot tokens or other secrets to GitHub.

The app accepts JPG, PNG, WEBP and GIF image files up to 9 MB. Custom emojis may also
use a public direct HTTP/HTTPS image URL; gallery-selected emoji images are uploaded
to the Telegram channel through the Worker.

## تحديثات لَمّة (واجهة الملف الشخصي والكروبات والإيموجيات)

- صفحة الملف الشخصي للعضو أصبحت صفحة عرض مستقلة، بينما تغيير الاسم والنبذة والصورة والغلاف وخيارات الحساب موجودة في شاشة إعدادات منفصلة.
- الضغط على صورة العضو في قائمة المحادثات أو الأصدقاء أو داخل المحادثة يفتح ملفه العام. معلومات الأعضاء والأوسمة تُقرأ من Firestore عبر streams مباشرة حتى تظهر التعديلات دون الاعتماد على Cache قديم.
- إنشاء المجموعة يحمّل الأصدقاء مرة واحدة قبل عرض الاختيارات، حتى لا يعيد دوران قائمة الأعضاء عند كل اختيار.
- معلومات المجموعة تتيح تغيير الاسم والوصف وإضافة الأعضاء وإزالة الأعضاء وإدارة المشرفين ومغادرة المجموعة. منشئ المجموعة وحده يعيّن أو يسحب صلاحية المشرف، ولا يمكن إخراجه.
- لوحة الإدارة ← الإيموجيات تقبل رمز Unicode، أو صورة من المعرض، أو رابط صورة مباشر. الصور المرفوعة من الجهاز تُرسل عبر Cloudflare Worker إلى قناة Telegram، ويمكن أيضاً استخدام رابط HTTPS مباشر.
- تظهر الإيموجيات المصورة داخل منتقي الإيموجي والرسائل عند جميع المشاركين عبر رابط الصورة؛ يجب أن يكون الرابط عاماً وقابلاً للقراءة.

بعد رفع التحديث، انشر قواعد Firestore الجديدة:

```bash
firebase deploy --only firestore:rules
```

**ملاحظة:** رفع الصور من المعرض يحتاج نشر نسخة Worker المحدّثة في Cloudflare، ولا يحتاج Firebase Storage. الرابط المباشر يعتمد على بقاء الصورة متاحة للعامة.
