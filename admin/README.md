# خادم Vela ولوحة الإدارة

تطبيق Next.js واحد (App Router + TypeScript صارم) يقدّم:

- **لوحة الإدارة** (اختصارات، إعلانات، قوائم حجب، محتوى، إشعارات، نشر/تراجع، بلاغات، سجل تدقيق، مستخدمون).
- **الواجهة العامة `/api/v1`** التي يقرأها تطبيق الموبايل: إعداد موقّع بـ Ed25519، قوائم الحجب، الأيقونات، البلاغات.

قاعدة بيانات واحدة: PostgreSQL 16 عبر Prisma 6. لا Redis ولا خدمات إضافية، ولا أي اتصال شبكي خارجي من الخادم وقت التشغيل.

- العقد الملزِم: [`../docs/CONFIG_CONTRACT.md`](../docs/CONFIG_CONTRACT.md)
- توثيق كل الواجهات: [`docs/API.md`](docs/API.md)

## البنية

```
admin/
  prisma/schema.prisma, prisma/migrations/   المخطط والترحيلات (SQL مُولّد + قيود إضافية)
  prisma/seed.ts, prisma/seed-data/           البيانات الافتراضية + قائمة الحجب الأولية (من تأليفنا)
  scripts/                                    keys:generate, admin:create-owner, config:verify
  src/lib/config-schema.ts                    مخطط zod الوحيد للحمولة (يُستخدم في الحفظ والمعاينة والنشر والتوقيع)
  src/lib/signing.ts                          توقيع/تحقق Ed25519 بـ node:crypto فقط
  src/lib/blocklist.ts                        التحقق من القواعد والتسلسل الثابت للبايتات
  src/lib/admin-route.ts                      فرض الجلسة + Origin + CSRF + الدور على كل مسار إداري
  src/middleware.ts                           CSP بـ nonce لكل طلب
  src/app/api/v1/**                           الواجهة العامة
  src/app/api/admin/**                        واجهة الإدارة
  src/app/(admin)/**, src/app/login           صفحات اللوحة
  tests/ (Vitest)   e2e/ (Playwright)
```

## المتطلبات

- Node.js 22 و npm
- PostgreSQL 16 (محلي أو عبر Docker)
- Docker + Docker Compose (اختياري للتشغيل الكامل)

## الإعداد المحلي — Linux / macOS

```bash
cd admin
npm ci                                   # يشغّل prisma generate تلقائياً

# 1) قاعدة بيانات للتطوير (أو استخدم Postgres موجوداً)
docker run -d --name vela-pg-dev -e POSTGRES_USER=vela -e POSTGRES_PASSWORD=vela_dev_pw \
  -e POSTGRES_DB=vela -p 54329:5432 postgres:16-alpine

# 2) ملف البيئة
cp .env.example .env
#   عدّل DATABASE_URL إلى: postgresql://vela:vela_dev_pw@localhost:54329/vela?schema=public

# 3) مفاتيح التوقيع (تُطبع فقط ولا تُكتب في أي ملف)
npm run keys:generate
#   انسخ CONFIG_SIGNING_PRIVATE_KEY إلى .env
#   واحتفظ بـ CONFIG_PUBLIC_KEY لبناء التطبيق: --dart-define=CONFIG_PUBLIC_KEY=<القيمة>

# 4) ملح عناوين IP للبلاغات
node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"
#   ضع الناتج في REPORT_IP_SALT داخل .env

# 5) الترحيل + البيانات الافتراضية + المالك الأول
npm run db:migrate
npm run db:seed
npm run admin:create-owner -- --email you@example.com     # يطلب كلمة المرور (12 حرفاً على الأقل)

# 6) التشغيل
npm run dev                              # http://localhost:3000
```

ثم: سجّل الدخول ← راجع الاختصارات/الإعلانات/المحتوى (غيّر روابط `example.invalid` الافتراضية) ← صفحة **Publish** ← انشر.

## الإعداد المحلي — Windows (PowerShell)

```powershell
cd admin
npm ci

docker run -d --name vela-pg-dev -e POSTGRES_USER=vela -e POSTGRES_PASSWORD=vela_dev_pw `
  -e POSTGRES_DB=vela -p 54329:5432 postgres:16-alpine

Copy-Item .env.example .env
#   عدّل DATABASE_URL في .env كما في الأعلى

npm run keys:generate
node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"

npm run db:migrate
npm run db:seed
npm run admin:create-owner -- --email you@example.com

npm run dev
```

> بيئة غير تفاعلية (CI): `ADMIN_PASSWORD='...' npm run admin:create-owner -- --email you@example.com`
> (PowerShell: `$env:ADMIN_PASSWORD='...'; npm run admin:create-owner -- --email you@example.com`).
> الأمر يرفض إن وُجد OWNER مسبقاً إلا مع `--force`.

## Docker Compose (Postgres + الخادم)

ملف `docker-compose.yml` في جذر المستودع، ويقرأ المتغيرات من `admin/.env`، لذلك مرّر `--env-file` دائماً:

```bash
# من جذر المستودع. أضف إلى admin/.env: POSTGRES_PASSWORD (حروف/أرقام/-/_ فقط) و CONFIG_SIGNING_PRIVATE_KEY و REPORT_IP_SALT
docker compose --env-file admin/.env up -d --build          # db + migrate (prisma migrate deploy) + admin
docker compose --env-file admin/.env run --rm tools npm run db:seed
docker compose --env-file admin/.env run --rm tools npm run admin:create-owner -- --email you@example.com
docker compose --env-file admin/.env logs -f admin
docker compose --env-file admin/.env down                   # البيانات تبقى في الحجم vela_pgdata
```

- داخل Compose يُبنى `DATABASE_URL` تلقائياً من `POSTGRES_*` (المضيف `db`) ويتجاوز القيمة في `.env`.
- الخادم مربوط بـ `127.0.0.1:${ADMIN_PORT:-3000}` فقط. ضع أمامه وكيلاً عكسياً بـ TLS (Caddy/nginx).
- الصورة: متعددة المراحل، `node:22-bookworm-slim`، مستخدم غير جذر (`node`)، خرج Next.js `standalone`، مع HEALTHCHECK.

## الاختبارات

```bash
cd admin
# Vitest: ينشئ قاعدة vela_test من الصفر في كل تشغيل (DROP/CREATE) ثم prisma migrate deploy
#   الافتراضي: postgresql://vela:vela_dev_pw@localhost:54329/vela_test — غيّره بـ TEST_DATABASE_URL
npm test

# Playwright (Chromium): ينشئ قاعدة vela_e2e ويبذرها ويشغّل الخادم على المنفذ 3100
npm run build
npm run test:e2e                # أو E2E_DEV=1 npm run test:e2e لاستخدام next dev
#   E2E_DATABASE_URL / E2E_PORT لتغيير القاعدة/المنفذ. أول مرة على جهاز جديد: npx playwright install chromium

npm run lint
npm run typecheck
npm audit --omit=dev
```

اختبار يدوي للتوقيع على أي خادم:

```bash
CONFIG_PUBLIC_KEY=<المفتاح العام base64url> npm run config:verify -- https://admin.example.com
# PowerShell: $env:CONFIG_PUBLIC_KEY='...'; npm run config:verify -- https://admin.example.com
```

يتحقق من التوقيع والمخطط وتاريخ الانتهاء وتطابق SHA-256 لقائمة الحجب.

## النسخ الاحتياطي والاستعادة

```bash
# نسخ احتياطي (صيغة custom مضغوطة)
pg_dump -Fc -h localhost -p 54329 -U vela -d vela -f vela-$(date +%F).dump
# عبر Compose:
docker compose --env-file admin/.env exec -T db pg_dump -Fc -U vela -d vela > vela-$(date +%F).dump

# استعادة إلى قاعدة فارغة
createdb -h localhost -p 54329 -U vela vela_restore
pg_restore -h localhost -p 54329 -U vela -d vela_restore --no-owner --exit-on-error vela-2026-10-21.dump
# استعادة فوق القاعدة الحالية (يحذف الكائنات أولاً — احذر):
pg_restore -h localhost -p 54329 -U vela -d vela --clean --if-exists --no-owner vela-2026-10-21.dump
# عبر Compose:
docker compose --env-file admin/.env exec -T db pg_restore -U vela -d vela --clean --if-exists --no-owner < vela-2026-10-21.dump
```

PowerShell: استخدم `-f vela.dump` مع `pg_dump` بدلاً من إعادة التوجيه `>` (لأن PowerShell قد يغيّر ترميز البايتات).
احفظ النسخ مشفّرة وخارج الخادم، وجرّب الاستعادة دورياً. ملفات `*.dump` مستثناة في `.gitignore`.

## البيئات: development / staging / production

المتغير `APP_ENV`:

| | development | staging / production |
|---|---|---|
| كوكي الجلسة `Secure` | لا (http محلي) | نعم |
| HSTS | لا | نعم |
| `REPORT_IP_SALT` | اختياري (ملح عشوائي مؤقت) | إلزامي، وإلا `503` لواجهة البلاغات |

ملاحظات للنشر:

- استخدم **مفتاح توقيع مختلفاً** لكل بيئة (staging ≠ production) وبناءً مختلفاً للتطبيق بالمفتاح العام المناسب.
- `PUBLIC_BASE_URL` = الأصل العام الحقيقي (`https://admin.example.com`) — يُستخدم في فحص Origin.
- شغّل خلف وكيل عكسي يضيف/يكتب `X-Forwarded-For` (nginx `proxy_add_x_forwarded_for` أو Caddy).
  الخادم يأخذ **آخر** قيمة في الترويسة كعنوان العميل؛ بدون وكيل يمكن تزوير العنوان (يؤثر على حدود المعدل فقط).
- الترحيل في الإنتاج: `npx prisma migrate deploy` فقط (لا `migrate dev` ولا `reset`). خدمة `migrate` في Compose تفعل ذلك.
- تدوير المفاتيح: ولّد زوجاً جديداً، غيّر `CONFIG_SIGNING_KEY_ID` (k2)، انشر بناء تطبيق يعرف المفتاح الجديد أولاً، ثم بدّل المفتاح في الخادم.
- يُفضّل تقييد الوصول إلى مسارات اللوحة (`/`, `/api/admin/*`) على مستوى الوكيل (VPN/قائمة IP) مع إبقاء `/api/v1/*` عاماً.

## ملاحظات أمنية

- **كلمات المرور:** Argon2id (19 MiB، t=2). الحد الأدنى 12 حرفاً. رسائل خطأ موحّدة لا تكشف وجود الحساب.
- **حدود الدخول:** 5 محاولات فاشلة لكل (IP + بريد) خلال 15 دقيقة ← `429`؛ 5 إخفاقات متتالية للحساب ← قفل 15 دقيقة.
- **الجلسات:** رمز عشوائي 256-bit في كوكي `vela_admin` (`HttpOnly`, `SameSite=Strict`, `Secure` خارج التطوير).
  القاعدة تحفظ SHA-256 للرمز فقط. انتهاء بعد 12 ساعة خمول أو 7 أيام مطلقاً. رمز جديد عند كل دخول (تدوير).
- **CSRF:** رمز لكل جلسة في الترويسة `x-csrf-token` لكل طلب إداري غير GET + فحص `Origin`.
- **الأدوار تُفرض في الخادم** على كل مسار (`READONLY` قراءة فقط، `ADMIN` تعديل ونشر، `OWNER` + إدارة المستخدمين)، وليس بإخفاء الأزرار فقط.
  لا يمكن إزالة آخر OWNER. تعطيل مستخدم أو تغيير دوره/كلمة مروره يلغي جلساته.
- **الترويسات:** CSP بـ nonce و`strict-dynamic` (بدون `unsafe-inline` للسكربتات)، `X-Frame-Options: DENY`،
  `frame-ancestors 'none'`، `nosniff`، `Referrer-Policy: no-referrer`، `Permissions-Policy`، HSTS في الإنتاج.
- **لا SSRF:** لا توجد أي ميزة تجلب رابطاً من الخادم. الأيقونات رفع فقط (PNG/JPEG/WebP ≤ 512KB، فحص البايتات السحرية،
  رفض SVG) وتُعاد ترميزها بـ sharp إلى PNG 128×128.
- **الإعداد بيانات فقط:** لا JavaScript ولا CSS حر. محددات CSS في قوائم الحجب مقيدة بقائمة أحرف مسموحة (حسب العقد).
- **روابط:** `https://` فقط؛ روابط الاختصارات ترفض localhost وعناوين IP الخاصة/المحجوزة وIPv6 الحرفية والأسماء الداخلية.
- **الخصوصية:** عدّاد الجلب اليومي مجمّع (تاريخ + منصة) بلا IP ولا معرّف جهاز. البلاغات تحفظ HMAC مملّحاً لعنوان IP
  لغرض حد المعدل فقط ويُحذف بعد 24 ساعة. سجل التدقيق يحفظ IP **المشرفين** فقط.
- **الأسرار:** لا أسرار في المستودع؛ `.env` مستثنى. لا تُطبع المفاتيح في السجلات. `keys:generate` يطبع فقط.
- **AdMob:** لا يوجد ربط بتقارير AdMob؛ بطاقة الأرباح تعرض «Not connected» ولا أرقام وهمية.
  البذرة تستخدم معرفات Google التجريبية الرسمية فقط — استبدلها بمعرفاتك الحقيقية قبل الإنتاج.
- **قائمة الحجب الأولية** من تأليف صاحب المشروع (أسماء نطاقات معروفة + أنماط ومحددات خاصة بنا)، وليست منسوخة من EasyList أو غيرها.
