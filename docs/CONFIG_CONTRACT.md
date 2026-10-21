# عقد الإعدادات البعيدة وواجهات API (v1)

هذا الملف هو المرجع المشترك بين تطبيق الموبايل (`mobile/`) والخادم/لوحة الإدارة (`admin/`).
أي تغيير في المخطط يرفع `schemaVersion` ويُوثَّق هنا أولاً.

## المبادئ

- الإعدادات **بيانات** محددة المخطط فقط. لا JavaScript، ولا كود أصلي، ولا CSS حر يُحقن في المواقع.
- التطبيق يعمل بالكامل دون الخادم: إعدادات افتراضية مضمّنة + آخر إعداد صالح محفوظ محلياً.
- الإعداد موقّع بـ Ed25519. المفتاح الخاص على الخادم فقط (متغير بيئة). المفتاح العام يُضمَّن في
  التطبيق وقت البناء (`--dart-define=CONFIG_PUBLIC_KEY=<base64url>`)، ولا يُجلب من الشبكة.
- لا تُرسل أي بيانات تصفح (روابط، بحث، كوكيز، سجل) إلى الخادم في أي واجهة.

## الواجهات العامة (بدون مصادقة) — البادئة `/api/v1`

| الطريقة | المسار | الوصف |
|---|---|---|
| GET | `/api/v1/health` | `{ "status": "ok", "time": ISO }` |
| GET | `/api/v1/config?platform=android\|ios&appVersion=1.2.3` | المغلف الموقّع للإعداد الحالي المنشور |
| GET | `/api/v1/blocklists/{version}` | جسم قائمة الحجب كما خُزّن بالضبط (bytes ثابتة) |
| GET | `/api/v1/assets/{id}` | أيقونة اختصار مرفوعة (PNG/WebP فقط، أُعيد ترميزها على الخادم) |
| POST | `/api/v1/reports` | بلاغ اختياري من المستخدم |

### `GET /api/v1/config` — المغلف

```json
{
  "keyId": "k1",
  "payload": "<base64url(UTF-8 bytes of payloadJson)>",
  "signature": "<base64url(Ed25519(UTF-8 bytes of payloadJson))>"
}
```

- التوقيع على **البايتات نفسها** التي رُمّزت في `payload`؛ لا حاجة لأي توحيد JSON.
- إن لم يوجد إصدار منشور: HTTP 404 `{ "error": "no_published_config" }`.
- `platform` و`appVersion` اختياريان؛ يُستخدمان فقط لعدّاد يومي مجمّع (بدون IP أو معرّف جهاز).
- يُوقَّع المغلف عند كل طلب بطوابع زمنية جديدة (`issuedAt` الآن، `expiresAt` بعد 7 أيام).

### محتوى `payloadJson` (schemaVersion = 1)

```json
{
  "schemaVersion": 1,
  "configVersion": 12,
  "issuedAt": "2026-10-21T10:00:00.000Z",
  "expiresAt": "2026-10-28T10:00:00.000Z",
  "minAppVersion": "1.0.0",
  "maxAppVersion": null,
  "shortcuts": [
    {
      "id": "youtube",
      "title": { "en": "YouTube", "ar": "يوتيوب", "de": "YouTube" },
      "url": "https://m.youtube.com/",
      "iconKey": "youtube",
      "iconAssetId": null,
      "color": "#E53935",
      "order": 0
    }
  ],
  "ads": {
    "enabled": true,
    "placements": [
      {
        "id": "home_banner",
        "format": "banner",
        "enabled": true,
        "adUnitIdAndroid": "ca-app-pub-3940256099942544/9214589741",
        "adUnitIdIos": "ca-app-pub-3940256099942544/2435281174"
      }
    ],
    "frequency": {
      "interstitialMinIntervalSec": 600,
      "interstitialMaxPerSession": 1
    }
  },
  "blocking": {
    "enabledByDefault": true,
    "listVersion": 3,
    "listPath": "/api/v1/blocklists/3",
    "listSha256": "<hex sha256 of exact response body>",
    "ruleCount": 120
  },
  "content": {
    "privacyUrl": "https://example.invalid/privacy",
    "termsUrl": "https://example.invalid/terms",
    "supportUrl": "https://example.invalid/support",
    "helpText": { "en": "...", "ar": "...", "de": "..." }
  },
  "notices": [
    {
      "id": "update-1-2",
      "severity": "info",
      "message": { "en": "...", "ar": "...", "de": "..." },
      "minAppVersion": null,
      "maxAppVersion": "1.1.9"
    }
  ]
}
```

قيود التحقق (يطبّقها الخادم عند الحفظ/النشر، ويطبّقها التطبيق عند الاستلام بشكل مستقل):

- `shortcuts`: حتى 24 عنصراً. `url` يجب أن يكون `https://` فقط، مع مضيف عام (لا IP خاص، لا `localhost`).
  `title` لكل لغة حتى 40 حرفاً، ويجب وجود `en`. `iconKey` من القائمة المسموحة:
  `youtube, twitch, tiktok, rumble, facebook, instagram, x, reddit, vimeo, dailymotion, news, generic` أو `null`.
  `color` بصيغة `#RRGGBB`.
- `ads.placements[].id` من القائمة المعروفة فقط: `home_banner`, `downloads_banner`, `tabs_interstitial`.
  `format` يطابق الموضع (`banner` للأولين، `interstitial` للثالث).
  معرف الوحدة يطابق `^ca-app-pub-\d{16}/\d{10}$` أو فارغ.
- `ads.frequency` ضمن السقف الآمن المبرمج في التطبيق والخادم:
  `interstitialMinIntervalSec` ≥ 300، `interstitialMaxPerSession` بين 0 و3. التطبيق يقصّ أي قيمة خارج المدى.
- `notices[].severity` ∈ `info | update`. الرسالة حتى 280 حرفاً لكل لغة.
- `content.*Url`: `https://` فقط.

سلوك التطبيق عند الاستلام:

1. فشل التوقيع أو المخطط ← يُرفض الإعداد ويبقى آخر إعداد صالح.
2. `configVersion` أقل من آخر إصدار مقبول ← يُرفض (منع إعادة تشغيل إصدار قديم).
   لذلك التراجع في اللوحة ينشئ **إصداراً جديداً** بمحتوى قديم.
3. `expiresAt` منتهٍ ← يُتجاهل الإعداد البعيد كاملاً ويُستخدم الافتراضي المضمّن.
4. نسخة التطبيق خارج `[minAppVersion, maxAppVersion]` ← يُتجاهل الإعداد البعيد.
5. تحديث الاختصارات الافتراضية **لا يمسح** تخصيص المستخدم: المستخدم الذي عدّل اختصاراته يرى إشعاراً
   بوجود اختصارات مقترحة جديدة فقط.
6. في الإصدارات debug يستخدم التطبيق دائماً معرفات Google التجريبية بغض النظر عن الإعداد.

### `GET /api/v1/blocklists/{version}`

الجسم (`application/json`)، ويطابق `listSha256` بايتاً ببايت:

```json
{
  "format": "vela-blocklist",
  "formatVersion": 1,
  "version": 3,
  "name": "Vela Starter",
  "license": "Original work, (c) project owner",
  "rules": [
    {
      "action": "block",
      "urlFilter": ".*\\.doubleclick\\.net/.*",
      "resourceTypes": ["script", "image", "raw"],
      "ifDomain": [],
      "unlessDomain": []
    },
    {
      "action": "css-display-none",
      "urlFilter": ".*",
      "selector": ".ad-banner, .sponsored",
      "ifDomain": ["*example.com"]
    }
  ]
}
```

- `action` ∈ `block | css-display-none` فقط. (`ignore-previous-rules` غير مدعوم في v1 لأن تنفيذ
  flutter_inappwebview على Android لا يطبّقه، ولا نريد سلوكاً مختلفاً بين النظامين.)
- قواعد `block`: `ifDomain` و`unlessDomain` يجب أن تكونا فارغتين أو غائبتين، لأن Android يطابقهما مع
  مضيف **الطلب** بينما WebKit يطابقهما مع مضيف **الصفحة**. الاستثناء لكل موقع يطبّقه التطبيق نفسه.
- قواعد `css-display-none`: `urlFilter` يُتجاهل (يُكتب `.*`)، و`ifDomain` تعني نطاق **الصفحة**
  ويطبّقها التطبيق عبر حقن CSS آمن (نفس الكود على النظامين). عنصر `ifDomain` اسم مضيف أو `*` + لاحقة.
- `urlFilter`: مجموعة فرعية من regex متوافقة مع WebKit Content Rules وJava regex معاً:
  ممنوع `|` و`{` و`}` و`(?` و`\d` و`\w` و`\s` و`\b`؛ الطول ≤ 512.
  النمط الموصى به لحجب مضيف: `^https?://([^/]+\.)?doubleclick\.net[/:]`.
- `resourceTypes` ⊆ `document, image, style-sheet, script, font, raw, svg-document, media` (لا `popup`: غير مدعوم في flutter_inappwebview).
  الأفضل تركها فارغة لقواعد المضيفات الإعلانية.
- `selector` ≤ 1000 حرف، ويسمح فقط بالأحرف: حروف/أرقام ASCII ومسافة و`. # _ - [ ] = ^ $ * ~ : ( ) , > + "`.
  ممنوع `'` و`\` و`{` و`}` و`<` و`@` و`;` و`/` ونص `url(` و`expression(`.
- الحد الأقصى 5000 قاعدة، وحجم الجسم ≤ 1MB. التطبيق يرفض ما يتجاوز ذلك ويحتفظ بالإصدار السابق.

### `POST /api/v1/reports`

```json
{
  "category": "site_broken | blocking_issue | video_issue | ads_issue | other",
  "message": "نص حر حتى 2000 حرف",
  "appVersion": "1.0.0",
  "platform": "android | ios",
  "locale": "ar",
  "siteHost": "example.com"
}
```

- `siteHost` اختياري، اسم المضيف فقط (يُرفض أي مسار أو استعلام). التطبيق يعرض للمستخدم ما سيُرسل قبل الإرسال.
- حد معدل: 5 بلاغات/ساعة لكل IP (يُحفظ تجزئة IP مملّحة مؤقتاً لغرض الحد فقط، تُحذف بعد 24 ساعة).
- الاستجابة `201 { "id": "..." }` أو `400/429`.

## واجهات الإدارة — البادئة `/api/admin`

محمية بجلسة (كوكي `HttpOnly; Secure; SameSite=Strict`) + رمز CSRF في الترويسة `x-csrf-token`
لكل طلب غير GET، + فحص `Origin`. الأدوار: `OWNER`, `ADMIN`, `READONLY`.
كل تعديل يُسجَّل في سجل التدقيق. التفاصيل الكاملة في `admin/README.md`.
