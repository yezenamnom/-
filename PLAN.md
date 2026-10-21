# PLAN — متصفح Vela (اسم داخلي مؤقت)

> «Vela» اسم عمل مؤقت قابل للتغيير. المعرّفات `dev.vela.browser` مؤقتة أيضاً ويجب استبدالها قبل النشر.

## البنية

```
mobile/        تطبيق Flutter (Android + iOS) — المتصفح
admin/         Next.js + TypeScript + Prisma + PostgreSQL — لوحة الإدارة + API العام v1
test-pages/    صفحات اختبار محلية ثابتة (كوكيز، نوافذ، رفع، تنزيل، حجب، وسائط)
docs/          العقد والتقارير (ترخيص، اختبارات، قدرات الوسائط، جاهزية المتاجر، الخصوصية)
.github/       CI
docker-compose.yml  Postgres + الخادم للتشغيل المحلي
```

## القرارات التقنية (موثّقة)

| القرار | السبب |
|---|---|
| مشروع Flutter جديد بدلاً من تفرع `flutter_browser_app` | المرجع (Apache-2.0، آخر commit 2024-10) موجّه لسطح المكتب (multi_window, window_manager_plus)، بنمط Chrome وليس نمط المرجع المطلوب، وبإعدادات Gradle قديمة (Groovy, compileSdk 34, Java 1.8). نستخدم نفس المحرك `flutter_inappwebview` ونقتبس أنماطاً محددة فقط مع الإسناد. انظر `docs/LICENSE_AUDIT.md`. |
| `flutter_inappwebview` 6.1.5 | Apache-2.0، يغلّف Android System WebView وWKWebView، يدعم Content Blockers، المحرك المطلوب. |
| Riverpod لإدارة الحالة | مشروع جديد بلا نمط سابق صالح؛ حسب البرومبت. |
| sqflite للسجل/المفضلة/التبويبات | SQLite محلي، لا خادم. |
| flutter_secure_storage | Keychain/Keystore لأي قيم حساسة محلية. |
| توقيع Ed25519 للإعدادات | مفتاح خاص على الخادم فقط، تحقق في التطبيق بمكتبة `cryptography` (Apache-2.0). |
| Next.js 15.5.x (فرع backport المدعوم) بدلاً من 16 | تجنّب كسر واجهات حديثة (middleware→proxy)؛ إصدار مدعوم أمنياً. |
| Prisma 6.19.x بدلاً من 7/8 | 8 ما زال RC، و7 غيّر طريقة الإعداد جذرياً؛ 6 مستقر ومجرّب. |
| TypeScript 5.9 | TS 7 (المترجم الجديد) قد لا يتوافق مع أدوات Next الحالية. |
| قائمة حجب أصلية من تأليفنا | EasyList بترخيص GPLv3/CC BY-SA؛ نتجنب الالتزامات حتى مراجعة قانونية. أسماء النطاقات حقائق. |
| لا Proxy للتصفح | الفيديو والمواقع تذهب مباشرة من المصدر للجهاز. |

## المراحل

1. فحص البيئة والترخيص واختبار جدوى الحجب/الفيديو/الخلفية ← `docs/ENVIRONMENT.md`, `docs/LICENSE_AUDIT.md`, `docs/MEDIA_CAPABILITIES.md`.
2. متصفح يعمل: واجهة رئيسية، شريط عنوان، تبويبات، مفضلة، سجل، إعدادات، خاص، لغات.
3. حجب المحتوى + الوسائط (ملء الشاشة، PiP حيث يُدعم، الخلفية حسب القيود الموثقة) + التنزيلات.
4. الخادم ولوحة الإدارة + ربط الإعداد الموقّع بالتطبيق.
5. AdMob تجريبي + UMP + ATT.
6. أساس الاشتراك + اختبارات + CI + وثائق النشر.

## حدود البيئة الحالية

- حاوية Linux سحابية: لا macOS/Xcode ⇒ iOS **لم يُبنَ ولم يُختبر**.
- لا KVM ⇒ لا محاكي Android ⇒ اختبارات الجهاز (WebView حقيقي، إعلانات، خلفية، PiP) **BLOCKED**.
- المتاح: Flutter analyze + unit/widget tests + بناء APK debug، Node + Postgres (Docker) + Playwright Chromium للوحة الإدارة.
