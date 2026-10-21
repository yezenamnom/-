# Vela — متصفح Android وiOS مع لوحة إدارة (اسم عمل مؤقت)

متصفح عام مبني بـ Flutter فوق Android System WebView وWKWebView، مع تبويبات وتصفح خاص معزول، مفضلة وسجل، اختصارات
قابلة للتخصيص، حجب إعلانات ومتتبعات داخل المتصفح، مدير تنزيلات، إعلانات AdMob في واجهة التطبيق فقط، واشتراك
لإزالة إعلانات التطبيق. لوحة إدارة Next.js + PostgreSQL تنشر إعدادات موقّعة يقرؤها التطبيق.

> **الحالة:** نُفّذ واختُبر آلياً على Linux (وحدات، واجهات، بناء APK debug، خادم، E2E). **لم يُشغَّل على أي جهاز ولم يُبنَ لـ iOS.**
> التفاصيل الصادقة في `docs/TEST_REPORT.md` و`HANDOFF.md`.

## محتويات المستودع

| المسار | الوصف |
|---|---|
| `mobile/` | تطبيق Flutter (Android + iOS) |
| `admin/` | الخادم ولوحة الإدارة وواجهات API (توثيق: `admin/README.md`، `admin/docs/API.md`) |
| `docs/CONFIG_CONTRACT.md` | عقد الإعدادات الموقّعة وقوائم الحجب بين التطبيق والخادم |
| `docs/` | التقارير: TEST_REPORT، MEDIA_CAPABILITIES، STORE_READINESS، LICENSE_AUDIT، THIRD_PARTY_NOTICES، ENVIRONMENT، legal/، screenshots/ |
| `test-pages/` | صفحات اختبار محلية للأجهزة + `serve.py` |
| `tools/` | تقرير التراخيص، اختبار دخان الحجب على مواقع حقيقية |
| `PLAN.md`, `TASKS.md`, `HANDOFF.md` | الخطة والمهام وحالة التسليم |

## 1. المتطلبات

- Flutter **3.47.7** (stable) / Dart 3.13 — مثبّت في `mobile/pubspec.lock`.
- Android: JDK 17+، Android SDK 36، NDK يُنزّله Gradle. (AGP 8.13.2 مثبّت عمداً، انظر `docs/LICENSE_AUDIT.md` §2.)
- iOS: macOS + Xcode حديث + CocoaPods، iOS 15+.
- الخادم: Node 22، Docker (لـ Postgres) أو PostgreSQL 16.

## 2. تشغيل الخادم ولوحة الإدارة محلياً

التفاصيل الكاملة (Linux/macOS/Windows، Docker Compose، النسخ الاحتياطي) في `admin/README.md`. مختصر Linux/macOS:

```bash
cd admin
docker run -d --name vela-pg-dev -e POSTGRES_USER=vela -e POSTGRES_PASSWORD=vela_dev_pw \
  -e POSTGRES_DB=vela -p 54329:5432 postgres:16-alpine
cp .env.example .env     # ثم عدّل DATABASE_URL إلى postgresql://vela:vela_dev_pw@localhost:54329/vela?schema=public
npm ci
npm run keys:generate     # انسخ المفتاح الخاص إلى .env (CONFIG_SIGNING_PRIVATE_KEY) واحتفظ بالعام للتطبيق
npm run db:migrate && npm run db:seed
npm run admin:create-owner -- --email you@example.com
npm run dev               # http://localhost:3000
```

ثم من اللوحة: راجع الاختصارات والإعلانات وقائمة الحجب ← **Publish** لنشر أول إعداد موقّع.

Windows (PowerShell): نفس الخطوات مع `Copy-Item .env.example .env`، وانظر `admin/README.md` للفروق.

النسخ الاحتياطي والاستعادة:

```bash
pg_dump -Fc "postgresql://vela:<pw>@localhost:54329/vela" -f vela-$(date +%F).dump
pg_restore --no-owner -d "postgresql://vela:<pw>@localhost:54329/vela_restored" vela-YYYY-MM-DD.dump
```

## 3. تشغيل تطبيق الموبايل

```bash
cd mobile
flutter pub get
cp env/dev.example.json env/dev.json     # ضع CONFIG_PUBLIC_KEY؛ الملف مستثنى من git
flutter run --dart-define-from-file=env/dev.json
```

- بدون `CONFIG_BASE_URL`/`CONFIG_PUBLIC_KEY` يعمل التطبيق كاملاً بالإعدادات المضمّنة (لا خادم).
- من محاكي Android الخادم المحلي هو `http://10.0.2.2:3000` (http مسموح في بيئة `dev` فقط؛ staging/production تتطلب https).
- الإعلانات: كل بناء غير `release` + `APP_ENV=production` يستخدم **معرفات Google التجريبية** تلقائياً.

### اختبارات وفحوص

```bash
flutter analyze
flutter test                                  # وحدات + واجهات (82)
# عقد التطبيق مع خادم يعمل فعلاً:
VELA_SERVER_URL=http://localhost:3000 VELA_PUBLIC_KEY=<public key> flutter test test/contract
flutter test test_screenshots --update-goldens  # لقطات توثيقية → test_screenshots/out
```

### بناء Android

```bash
flutter build apk --debug                                   # للتجربة (مفتاح debug، إعلانات تجريبية)
# إصدار المتجر: أنشئ مفتاح رفع وملف android/key.properties (مستثنى من git):
#   storeFile=/path/upload.jks  storePassword=...  keyAlias=upload  keyPassword=...
ADMOB_APP_ID_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY \
  flutter build appbundle --release --dart-define-from-file=env/production.json
```

بدون `key.properties` يُوقَّع الـ release بمفتاح debug المحلي: صالح للتجربة فقط وغير قابل للرفع إلى Play.

### بناء iOS (على macOS)

```bash
cd mobile && flutter pub get && cd ios && pod install && cd ..
# معرف AdMob الإنتاجي (اختياري؛ الافتراضي تجريبي) في ios/Flutter/Local.xcconfig (مستثنى من git):
#   ADMOB_APP_ID_IOS = ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
flutter build ios --release --dart-define-from-file=env/production.json
open ios/Runner.xcworkspace   # Signing & Capabilities: اختر فريقك، Bundle ID النهائي، ثم Product > Archive
```

اختبار على محاكي: `flutter run -d "iPhone 16"`. التوقيع والرفع عبر Xcode Organizer أو Transporter. لم يُنفّذ أي من ذلك بعد.

## 4. اختبار على جهاز بصفحات محلية

```bash
python3 test-pages/serve.py          # http://0.0.0.0:8765
adb reverse tcp:8765 tcp:8765        # ثم افتح http://localhost:8765 في التطبيق
```

## 5. ما تحتاج إضافته بنفسك (لا تضع أسراراً في المحادثة أو في git)

1. **الهوية:** الاسم النهائي، الأيقونة، Bundle/Application ID بدل `dev.vela.browser`، فحص العلامة التجارية.
2. **النطاق:** نطاق للخادم (HTTPS عبر reverse proxy) وصفحات الخصوصية/الشروط/الدعم و`app-ads.txt`.
3. **حسابات المتاجر:** Apple Developer وGoogle Play Console، صفحات المتجر، استبيانات الخصوصية (`docs/STORE_READINESS.md` §5).
4. **AdMob:** App IDs للنظامين (متغيرات البناء)، وحدات الإعلانات (تُدخل في اللوحة)، رسائل الموافقة في Privacy & messaging.
5. **الاشتراك:** منتجات شهرية/سنوية في المتجرين، `ENTITLEMENT_PRODUCT_IDS`، حساب خدمة Google Play (`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`)، `APPLE_BUNDLE_ID`، ومعرّفات المنتجات في `env/production.json`.
6. **مفاتيح التوقيع:** مفتاح رفع Android (`key.properties`)، شهادات Apple، ومفتاح توقيع الإعدادات Ed25519 للإنتاج (`npm run keys:generate`).
7. **قانوني:** مراجعة `docs/legal/*` وملء بيانات الشركة.
