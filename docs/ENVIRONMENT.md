# ENVIRONMENT — بيئة التطوير التي نُفّذ عليها العمل

تاريخ: 2026-10-21. حاوية Linux سحابية (Ubuntu 24.04، x86_64، 4 أنوية، 15GB RAM).

| الأداة | الإصدار | المصدر |
|---|---|---|
| Flutter | 3.47.7 (stable، revision abaf9c5237) | نُزّل إلى `/opt/sdk/flutter` |
| Dart | 3.13.5 | مع Flutter |
| Android SDK | platform 36 (+37.0 نزّلها Gradle)، build-tools 36.0.0، platform-tools، NDK 28.2.13676358 | `/opt/android` |
| Android Gradle Plugin | 8.13.2 (مثبّت يدوياً، انظر LICENSE_AUDIT §2) | `mobile/android/settings.gradle.kts` |
| Gradle / Kotlin | 8.14.3 / 2.2.21 | |
| Java | OpenJDK 21.0.12 (هدف البناء Java 17) | النظام |
| Node / npm | 22.22.0 / 10.9.4 | النظام |
| PostgreSQL | 16 (حاوية `postgres:16-alpine`) | Docker 29.9.1 |
| Playwright Chromium | 1194 (`@playwright/test` 1.56.1) | `/opt/pw-browsers` |
| ffmpeg | النظام | توليد وسائط الاختبار |

## العوائق

| العائق | الأثر |
|---|---|
| لا macOS/Xcode | **iOS لم يُبنَ ولم يُختبر.** المشروع والإعدادات جاهزة؛ CI يحتوي job على `macos-15` لم يُنفَّذ بعد. |
| لا `/dev/kvm` | لا محاكي Android ⇒ لم يُشغَّل التطبيق؛ كل اختبارات WebView الحقيقي/الإعلانات/الخلفية/PiP = BLOCKED. |
| `repo.maven.apache.org` يعيد 429 خلف بروكسي الحاوية | أُضيف `~/.gradle/init.d/maven-mirror.gradle` (خارج المستودع) يستعمل مرآة Google لـ Maven Central. لا يلزم على جهاز عادي. |
| `permission_handler` 13.x يتطلب compileSdk 37 غير المدعوم في AGP 8.13 | ثُبّت `permission_handler: ^12.0.3`. |
| بناء صورة Docker للخادم داخل الحاوية | `npm ci` داخل `docker build` لا يصل للإنترنت هنا ⇒ الصورة لم تُبنَ (يعمل `npm` مباشرة). |

## إعادة إنتاج البيئة على جهاز مطوّر

انظر `README.md`. الإصدارات مثبّتة في `mobile/pubspec.lock` و`admin/package-lock.json`، وأدوات Android في ملفات Gradle.
