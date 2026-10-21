# TEST_REPORT

البيئة: حاوية Linux سحابية (انظر ENVIRONMENT.md) — Flutter 3.47.7، Node 22، Postgres 16 (Docker)، Chromium 1194.
التاريخ: 2026-10-21. الحالات: **PASS** · **FAIL** · **NOT_RUN** (لم يُنفّذ) · **BLOCKED** (لا يمكن تنفيذه في هذه البيئة).

> لا يوجد جهاز أو محاكي Android ولا macOS. لذلك **لم يُختبر التطبيق على Android حقيقي ولم يُختبر على iOS إطلاقاً**.
> نجاح البناء والاختبارات أدناه لا يعني أن WebView أو الإعلانات أو الخلفية تعمل على الأجهزة.

## 1. تطبيق الموبايل — فحوص ثابتة وبناء

| الفحص | الأمر | النتيجة |
|---|---|---|
| Static analysis | `cd mobile && flutter analyze` | PASS — No issues found |
| كل اختبارات الوحدات والواجهات | `flutter test` | PASS — 82 نجح، 2 متجاوز (اختبار العقد يحتاج خادماً، انظر §3) |
| بناء APK debug (كل الكود الأصلي: Profiles، PiP) | `flutter build apk --debug` | PASS — `build/app/outputs/flutter-apk/app-debug.apk` (≈150MB debug، موقّع بمفتاح debug، إعلانات تجريبية) |
| بناء AAB/APK release | — | NOT_RUN — لا مفتاح توقيع (عن قصد)؛ الأمر في README |
| بناء iOS | `flutter build ios --no-codesign` | BLOCKED — لا macOS. job جاهز في `.github/workflows/mobile.yml` ولم يُشغّل |
| `dart format` | — | NOT_RUN كفاحص إلزامي (تحذير فقط في CI) |

## 2. اختبارات الوحدات والواجهات (Flutter) — تفصيل

| المجموعة | الملف | ما يغطيه | النتيجة |
|---|---|---|---|
| الروابط والبحث | test/core/url_input_test.dart | رابط/بحث، https افتراضي، host:port، رفض javascript:/data:/file:/content:، user:pass@، mailto/tel تحتاج تأكيداً، محركات البحث، المضيفات الخاصة، punycode ظاهر | PASS (15) |
| أسماء الملفات والإصدارات | test/core/file_names_test.dart | traversal، محارف تحكم وbidi، امتدادات خطرة، أسماء Windows المحجوزة، Content-Disposition، تكرار الأسماء، مقارنة الإصدارات | PASS (9) |
| سياسة الوسائط | test/core/media_policy_test.dart | منع الخلفية/PiP على نطاقات YouTube | PASS (1) |
| الإعداد البعيد | test/config/config_service_test.dart | التحقق من المخطط والسقوف، رفض http/IP خاص/javascript، توقيع صحيح/معبث/مفتاح خاطئ، منع التراجع، الانتهاء، عدم التوافق مع النسخة، تعطل الخادم، تعطيل بدون مفتاح أو https | PASS (8) |
| الحجب | test/blocking/blocking_test.dart | صحة القائمة المضمّنة ومطابقة regex، رفض الأفعال/الـ regex/المحددات الخطرة، الحدود 5000/1MB، CSS حسب نطاق الصفحة، سكربت تجميلي بـ JSON فقط، تحديث بشرط SHA-256 والتراجع، رفض قائمة تالفة، المفتاح العام والاستثناءات | PASS (9) |
| الإعلانات والموافقة | test/ads/ads_policy_test.dart | معرفات تجريبية دائماً خارج الإنتاج، لا طلب بدون موافقة/في الخاص/للمشترك، المواضع المعطلة، بوابة Interstitial (إحماء، فاصل، سقف الجلسة، لا أثناء فيديو/ملء شاشة)، عدم تجاوز السقف من بعد | PASS (6) |
| البيانات المحلية | test/data/repositories_test.dart | السجل (http فقط، دمج التكرار، تهريب LIKE، الحذف بالفترة)، المفضلة والمجلدات والحذف المتسلسل، حفظ التبويبات، أذونات المواقع، الاختصارات لا تُمسح بتحديث الإدارة | PASS (8) |
| التبويبات | test/browser/tabs_controller_test.dart | فتح/إغلاق/جار من نفس النوع، انتهاء الجلسة الخاصة، **10 تبويبات** مع تجميد LRU دون تجميد تبويب الصوت، الترتيب والبحث، حفظ العادية فقط واستعادتها | PASS (5) |
| الاشتراك | test/billing/subscription_test.dart | الاستحقاق موقّع وغير منتهٍ، رفض Boolean من العميل، عدم الإعداد، إعادة التحقق قبل الانتهاء، رفض المتجر يزيل الرمز، 501 يبقي الإعلانات | PASS (5) |
| التنزيلات والبلاغات | test/downloads/downloads_test.dart | **خادم HTTP محلي حقيقي**: traversal، أسماء خطرة، أخطاء HTTP وإعادة المحاولة، الإلغاء وحذف الجزئي، رفض file:/data:، الحذف والاستعادة؛ تنقيح البلاغ | PASS (7) |
| الواجهات | test/ui/app_ui_test.dart | الرئيسية en/ar(RTL)/de، الخاص يعرض شرحاً صادقاً، شاشة التبويبات وإغلاق الكل بتأكيد، إضافة اختصار مع التحقق، تغيير اللغة فوراً، صفحة الاشتراك توضح النطاق وتخفي الشراء، تكبير النص ×2 بلا overflow | PASS (9) |

ملاحظة: اختبارات الواجهة تستخدم خدمات حقيقية بتخزين في الذاكرة، ولا تعرض WebView (لا منصة في اختبارات الويدجت).

## 3. اختبار العقد بين التطبيق والخادم (بدون mocks)

| الاختبار | الأمر | النتيجة |
|---|---|---|
| التطبيق يقبل إعداداً موقّعاً من الخادم الفعلي ويحمّل قائمة الحجب v2 ويتحقق من SHA-256 | `VELA_SERVER_URL=http://localhost:3005 VELA_PUBLIC_KEY=<key> flutter test test/contract` (الخادم `npm run dev`، نُشرت قائمة v2 والإعداد v2 عبر Admin API مع CSRF) | PASS |
| مفتاح عام خاطئ ← رفض والعودة للافتراضي | نفسه | PASS |
| طلب نشر بدون رمز CSRF ← `csrf_failed` | curl | PASS |

## 4. الخادم ولوحة الإدارة

| الفحص | الأمر | النتيجة |
|---|---|---|
| Lint | `cd admin && npm run lint` | PASS |
| Typecheck (strict) | `npm run typecheck` | PASS |
| Vitest على Postgres حقيقي | `npm test` | PASS — 10 ملفات، 54 اختباراً |
| Playwright E2E (بناء إنتاج) | `npm run build && npm run test:e2e` | PASS — 5/5 (أُعيد تشغيله بنفسي بعد تسليم الوكيل) |
| Build | `npm run build` | PASS |
| `npm audit --omit=dev` | | PASS — 0 ثغرات |
| `npm audit` (مع dev) | | 8 ثغرات في أدوات الاختبار (vitest 3.x)؛ الإصلاح يتطلب vitest 4 — لا تُشحن |
| Docker image build | `docker compose --env-file admin/.env up -d --build` | BLOCKED — `npm ci` داخل docker build لا يصل للشبكة في هذه البيئة |
| compose db + نسخ احتياطي/استعادة | `pg_dump -Fc` / `pg_restore` | PASS (نفّذه وكيل الخادم) |

تفصيل Vitest: config-schema، blocklist، signing (round-trip + عبث)، auth (argon2id، قفل بعد 5 محاولات، انتهاء الجلسات، تدوير الجلسة، Secure في الإنتاج)،
RBAC (READONLY لا يعدّل، ADMIN لا يدير المستخدمين، 401)، CSRF/Origin ← 403، النشر والتراجع كإصدار جديد، البلاغات وحد المعدل،
المهاجرات على قاعدة فارغة، إعادة ترميز الأيقونات ورفض SVG/GIF، **entitlements** (7): سقف 7 أيام، Google Play (نشط/ملغى/منتهٍ،
منتج خاطئ، شراء تجريبي في الإنتاج، رمز مشوّه)، App Store JWS بسلسلة شهادات حقيقية مولّدة (توقيع صحيح، عبث بالحمولة، جذر غير
موثوق، مفتاح آخر، سلسلة ناقصة، bundle/منتج/بيئة خاطئة، ملغى/منتهٍ).

## 5. أمان

| الفحص | الأداة | النتيجة |
|---|---|---|
| أسرار في سجل git | gitleaks v8.24.2 (Docker) | PASS — لا تسريب؛ نتيجة واحدة إيجابية كاذبة (مفتاح يولَّد أثناء الاختبار) مُدرجة في `.gitleaksignore` |
| أسرار (فحص ثانٍ) | detect-secrets | لا أسرار حقيقية؛ الإشارات كلمات مرور تجريبية محلية/عناصر نائبة |
| تراخيص | `tools/license_report.py` | لا GPL في التطبيق؛ 3 حزم خادم تحتاج إسناداً (LGPL libvips، CC-BY caniuse) |

## 6. اختبارات الجهاز والتكامل — BLOCKED

صفحات الاختبار جاهزة في `test-pages/` (`python3 test-pages/serve.py`). كلها **BLOCKED** هنا (لا جهاز/محاكي):

| الحالة | Android | iOS |
|---|---|---|
| تحميل صفحة، رجوع/تقدم/تحديث/إيقاف، خطأ وإعادة محاولة | BLOCKED | BLOCKED |
| شهادة منتهية تُوقف بدون تجاوز (`links.html`) | BLOCKED | BLOCKED |
| حفظ جلسة موقع بعد إعادة التشغيل (`cookies.html`) | BLOCKED | BLOCKED |
| **عزل الخاص**: لا تسرب كوكيز/تخزين بين العادي والخاص، وحذفها عند إغلاق آخر خاص | BLOCKED (يعتمد على MULTI_PROFILE) | BLOCKED |
| النوافذ المنبثقة: حجب التلقائي، فتح المستخدم، window.opener (`popups.html`) | BLOCKED | BLOCKED |
| رفع الملفات والكاميرا (`upload.html`) | BLOCKED | BLOCKED |
| التنزيلات مع الكوكيز/بدونها في الخاص (`downloads.html`) | BLOCKED | BLOCKED |
| الحجب الشبكي والتجميلي والاستثناء (`blocking.html`) | BLOCKED | BLOCKED |
| أذونات الكاميرا/الميكروفون/الموقع (`permissions.html`) | BLOCKED | BLOCKED |
| روابط خارجية وmyapp:// التلقائي لا يُطلق (`links.html`) | BLOCKED | BLOCKED |
| فيديو: ملء شاشة، تدوير، PiP، خلفية، قفل شاشة، مكالمة، سماعة، تبويبان (`media.html`) | BLOCKED | BLOCKED |
| AdMob: إعلان تجريبي يظهر، رفض الموافقة لا يطلب، no-fill، انقطاع الشبكة | BLOCKED | BLOCKED |
| الاشتراك Sandbox (شراء/استعادة/إلغاء/استرداد) | BLOCKED (يحتاج حسابات ومنتجات) | BLOCKED |
| 10 تبويبات: الذاكرة والاستجابة على جهاز | BLOCKED — **لا أرقام أداء** (منطق التجميد مختبر وحدوياً فقط) | BLOCKED |
| تعطل الخادم / انتهاء الإعداد / تغيير الشبكة / الخروج والعودة | منطقها مختبر وحدوياً (PASS)؛ على جهاز BLOCKED | BLOCKED |

## 7. Smoke tests على مواقع حقيقية

| الاختبار | البيئة | النتيجة |
|---|---|---|
| قائمة الحجب على YouTube/Twitch/TikTok/Rumble/BBC/Wikipedia | Chromium سطح مكتب بمحاكاة Pixel 7، `tools/smoke/blocklist-smoke.mjs`، 2026-10-21 | الصفحات تعمل مع الحجب (Rumble محجوب ببوابة Cloudflare للمتصفح الآلي بغض النظر عن الحجب). التفاصيل في MEDIA_CAPABILITIES §3 |
| نفس المواقع داخل التطبيق | جهاز | BLOCKED |

تغيّر موقع خارجي لا يُعدّ تلقائياً خطأً في كودنا؛ أعد الاختبار وسجّل التاريخ.

## 8. CI

`.github/workflows/admin.yml` و`.github/workflows/mobile.yml` (Android + iOS على macOS + gitleaks): **NOT_RUN** — لم تُشغَّل على GitHub بعد؛
وجودها ليس دليلاً على نجاحها.
