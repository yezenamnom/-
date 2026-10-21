# LICENSE_AUDIT — تدقيق التراخيص

تاريخ التدقيق: 2026-10-21. هذا تقييم تقني وليس رأياً قانونياً؛ يُنصح بمراجعة محامٍ قبل النشر التجاري.

## 1. المشروع المرجعي `pichillilorenzo/flutter_browser_app`

| البند | النتيجة |
|---|---|
| الترخيص | Apache-2.0 (ملف `LICENSE` في جذر المستودع، فُحص من نسخة clone بتاريخ 2026-10-21) |
| آخر commit | `2377098d` بتاريخ 2024-10-25 |
| ملف NOTICE | غير موجود |
| الأصول | `assets/images/{google,yahoo,bing,duckduckgo,ecosia}_logo.png` = **علامات تجارية لأطراف ثالثة** (Apache-2.0 لا يمنح حقوق العلامات، القسم 6)؛ `assets/icon/icon.png` أيقونة المشروع الأصلي |
| التبعيات | flutter_downloader (BSD-3)، multi_window، window_manager_plus، context_menus، flutter_font_icons... |
| المعرّفات | `applicationId "com.pichillilorenzo.flutter_browser"`، روابط المطور داخل `project_info_popup.dart` |

**التوافق مع التوزيع المغلق:** Apache-2.0 يسمح بالاستخدام التجاري المغلق مع: إرفاق نسخة الترخيص، الإبقاء على إشعارات
حقوق المؤلف في الملفات المنقولة، ووضع إشعار بالتعديلات على الملفات المعدّلة.

**القرار: لم نتفرع منه ولم ننسخ ملفات منه.** الأسباب التقنية:

1. موجّه لسطح المكتب أيضاً (multi_window, window_manager_plus, desktop_app_bar ~600 سطر) ونمط واجهته يحاكي Chrome،
   بينما المطلوب نمط مختلف (رئيسية باختصارات، شبكة تبويبات بخلفية مختلفة).
2. إعدادات Android قديمة (Groovy، compileSdk 34، Java 1.8، `getDefaultProguardFile('proguard-android.txt')`)
   تتطلب إعادة كتابة مع AGP الحالي.
3. لا يعالج نقاطاً جوهرية في المطلوب: عزل حقيقي للتصفح الخاص على Android، إعدادات بعيدة موقّعة، AdMob/UMP، اشتراكات.
4. شاشات المطوّرين (JavaScript console، storage manager، network info) خارج النطاق وتوسّع سطح الهجوم.

ما استفدناه: **الدراسة فقط** لأنماط استخدام `flutter_inappwebview` (keep-alive، FindInteractionController، معالجة
onCreateWindow). الكود في `mobile/lib` مكتوب للمشروع. لذلك لا توجد ملفات منقولة تتطلب إشعار تعديل. إذا نُقل لاحقاً أي
ملف منه يجب: إبقاء ترويسة حقوق المؤلف + إضافة `Modified by <الشركة>, <التاريخ>: <الوصف>` + إضافة سطر في THIRD_PARTY_NOTICES.

## 2. المكتبة الأساسية `flutter_inappwebview`

| البند | النتيجة |
|---|---|
| الإصدار المستخدم | 6.1.5 (+ android 1.1.3، ios 1.1.2، platform_interface 1.3.0+1) — آخر **مستقر** (2024-10) |
| الترخيص | Apache-2.0 (لكل الحزم الفرعية)، بلا ملف NOTICE |
| لماذا ليس 6.2.0-beta.3 | إصدار تجريبي؛ لا نعتمد beta في منتج تجاري دون حاجة مثبتة |
| مشكلة توافق مكتشفة | `flutter_inappwebview_android` 1.1.3 يفشل مع AGP 9 (`proguard-android.txt` لم يعد مدعوماً). الحل: تثبيت AGP 8.13.2 + Gradle 8.14.3 + Kotlin 2.2.21 في `mobile/android` |
| عيوب موثّقة نتعامل معها | (أ) `incognito` على Android يحذف **كل** كوكيز التطبيق ولا يعزل ← لا نستخدمه، نستخدم WebView Profiles. (ب) Content blockers على Android: `ifDomain` يطابق مضيف الطلب لا الصفحة، أول قاعدة مطابقة للرابط بنوع مورد مختلف توقف التقييم، `ignore-previous-rules` غير منفّذ، و`css-display-none` يُدرج المحدد في JS بلا تهريب ← ضيّقنا مخطط القوائم ونطبّق القواعد التجميلية بسكربت خاص بنا (انظر CONFIG_CONTRACT.md) |

## 3. تبعيات التطبيق والخادم

القائمة الكاملة بالإصدارات في `docs/THIRD_PARTY_NOTICES.md`. ملخص (من `tools/license_report.py`):

| المجموعة | العدد | التراخيص |
|---|---|---|
| حزم Dart/Flutter (شاملة الانتقالية) | 129 | BSD-3-Clause 90، MIT 15، Apache-2.0 13، BSD-2-Clause 6، SDK 5 |
| npm للخادم (إنتاج فقط) | 68 | MIT 43، Apache-2.0 16، ISC 2، BSD 3، 0BSD 1، **LGPL-3.0 (libvips) 2**، **CC-BY-4.0 1** |

- **لا يوجد GPL/AGPL أو ترخيص copyleft قوي** في ما يُشحن داخل التطبيق.
- LGPL-3.0 في `sharp`/libvips على الخادم فقط (لا يُوزَّع). CC-BY-4.0 في بيانات `caniuse-lite` (إسناد في THIRD_PARTY_NOTICES).
- SDKs مملوكة: Google Mobile Ads SDK وUMP (شروط Google/AdMob)، Play Billing (Android SDK License). تُقبل ضمن حساب المطوّر.

## 4. قوائم الحجب

| القائمة | الترخيص | القرار |
|---|---|---|
| EasyList / EasyPrivacy | GPLv3 **أو** CC BY-SA 3.0 (مزدوج) | **غير مستخدمة.** CC BY-SA يفرض مشاركة أي اشتقاق من القائمة بنفس الترخيص؛ مقبول تقنياً للقائمة وحدها لكنه يحتاج قراراً قانونياً وإدارة إسناد. مؤجَّل. |
| Peter Lowe's list | شروط استخدام خاصة (ليست ترخيصاً مفتوحاً قياسياً) | غير مستخدمة |
| AdGuard filters | GPLv3 | غير مستخدمة |
| **قائمة Vela Starter** | تأليف أصلي (أنماط لأسماء مضيفات إعلانية/تتبع معروفة، وهي حقائق) | **مستخدمة** (مضمّنة في التطبيق وبذرة الخادم) |

لإضافة قائمة طرف ثالث لاحقاً: حدّد ترخيصها في حقل `license` عند رفعها في اللوحة، احتفظ بالإسناد المطلوب، وتأكد قانونياً.

## 5. الأيقونات والخطوط والشعارات

- أيقونات Material (Apache-2.0) مضمّنة في Flutter.
- **لا** نستخدم شعارات YouTube/Twitch/TikTok/Rumble/Facebook أو محركات البحث. الاختصارات تعرض أيقونة عامة + لون + حرف.
  الأسماء النصية للمواقع استخدام وصفي (nominative) فقط.
- لا خطوط مضمّنة (خطوط النظام).
- أيقونة التطبيق الحالية = أيقونة قالب Flutter المؤقتة؛ يجب استبدالها بهوية مملوكة.

## 6. ما يجب فعله قبل النشر

- [ ] مراجعة قانونية لهذا الملف.
- [ ] تشغيل `python3 tools/license_report.py` بعد آخر تحديث تبعيات، ومراجعة أي سطر `REVIEW`.
- [ ] استبدال اسم «Vela» والأيقونة والمعرفات `dev.vela.browser` بهوية نملك حقوقها (فحص العلامات التجارية).
