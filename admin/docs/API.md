# Vela server API

Binding contract: [`docs/CONFIG_CONTRACT.md`](../../docs/CONFIG_CONTRACT.md). This file documents every
endpoint implemented in `admin/src/app/api/**`. All bodies are JSON (UTF-8) unless stated otherwise.

Error shape (all endpoints): `{ "error": "<code>", "message"?: "<human text>", "details"?: [...] }`.
`details` for validation errors is a list of `{ "path": "a.b[0].c", "message": "..." }` (blocklist errors: strings).

---

## Public API — `/api/v1` (no authentication)

No browsing data is accepted or stored by any public endpoint. Only `POST /reports` accepts data.

### `GET /api/v1/health`
`200 { "status": "ok", "time": "<ISO>" }` — liveness only (does not touch the DB). `Cache-Control: no-store`.

### `GET /api/v1/config?platform=android|ios&appVersion=1.2.3`
Signed envelope of the current published release, signed **per request**:

```json
{ "keyId": "k1", "payload": "<base64url(UTF-8 payloadJson)>", "signature": "<base64url(Ed25519 over those bytes)>" }
```

- `payloadJson` = stored release content + `issuedAt` (now) + `expiresAt` (now + 7 days), validated with
  `src/lib/config-schema.ts#configPayloadSchema` right before signing. Key order: `schemaVersion, configVersion,
  issuedAt, expiresAt, minAppVersion, maxAppVersion, shortcuts, ads, blocking, content, notices`.
- `keyId` from `CONFIG_SIGNING_KEY_ID` (default `k1`).
- `platform` (`android`/`ios`, anything else → `unknown`) only increments the aggregated `DailyStat`
  counter for (UTC date, platform). `appVersion` is accepted and ignored. No IP or device id is stored.
- Headers: `Cache-Control: public, max-age=60`, `X-Config-Version: <n>`.

| Status | Body |
|---|---|
| 200 | envelope |
| 404 | `{ "error": "no_published_config" }` |
| 503 | `{ "error": "signing_key_unavailable" }` (`CONFIG_SIGNING_PRIVATE_KEY` missing/invalid) |
| 500 | `{ "error": "stored_config_invalid" }` / `{ "error": "internal_error" }` |

### `GET /api/v1/blocklists/{version}`
Exact stored body bytes (`Content-Type: application/json`), byte-identical to what `listSha256` hashes.
Headers: `Cache-Control: public, max-age=31536000, immutable`, `ETag: "<sha256>"`, `X-Content-SHA256`.
Only lists that were activated at least once (`ACTIVE`, or `ARCHIVED` after being active) are served —
older releases may still reference archived lists. `DRAFT` and unknown versions → `404 { "error": "not_found" }`.

Body format (`vela-blocklist`, formatVersion 1) and rule constraints: see the contract. Server-side validation
(`src/lib/blocklist.ts`) enforces: actions `block | css-display-none` only; `block` rules without
`ifDomain`/`unlessDomain`; `css-display-none` with `urlFilter: ".*"`, a whitelisted `selector`, optional
`ifDomain` (page hosts, `*`+suffix allowed), no `resourceTypes`/`unlessDomain`; `urlFilter` ≤ 512 printable
ASCII, no `|`, `{`, `}`, `(?`, `\d \w \s \b` (nor upper-case variants or back-references), must compile;
`resourceTypes` ⊆ `document, image, style-sheet, script, font, raw, svg-document, media`; ≤ 5000 rules; body ≤ 1 MB.

### `GET /api/v1/assets/{id}`
Uploaded shortcut icon, always `image/png` 128×128 (re-encoded server-side). Immutable cache headers,
`Content-Security-Policy: default-src 'none'; sandbox`. Unknown/invalid id → `404`.

### `POST /api/v1/reports`
Request (`Content-Type: application/json`, ≤ 16 KB, unknown keys rejected):

```json
{ "category": "site_broken|blocking_issue|video_issue|ads_issue|other", "message": "≤ 2000 chars",
  "appVersion": "1.0.0", "platform": "android|ios", "locale": "ar", "siteHost": "example.com" }
```

`siteHost` optional/nullable, bare hostname only (no scheme/port/path/query), stored lower-cased.

| Status | Body |
|---|---|
| 201 | `{ "id": "<report id>" }` |
| 400 | `invalid_json` / `validation_failed` (+details) |
| 413 | `payload_too_large` · 415 `unsupported_media_type` |
| 429 | `{ "error": "rate_limited" }` + `Retry-After: 3600` — 5 reports / clock hour per IP |
| 503 | `reports_unavailable` (no `REPORT_IP_SALT` outside development) |

Rate limiting stores only `HMAC-SHA256(REPORT_IP_SALT, ip)` per hour window; rows older than 24 h are purged
on every request. Client IP = right-most `X-Forwarded-For` entry (see README: run behind a reverse proxy).

---

### `POST /api/v1/entitlements/verify`

Verifies a "remove app ads" subscription with the store and returns a signed, short-lived entitlement.
Nothing about the user or purchase is stored.

Request (`application/json`, ≤ 32 KB):

```json
{ "platform": "android|ios", "productId": "remove_ads_monthly", "verificationData": "<Play purchase token | StoreKit 2 JWS transaction>", "source": "google_play|app_store" }
```

- Android: `verificationData` is the Play purchase token; checked with `purchases.subscriptionsv2.get` using the service account.
- iOS: `verificationData` is the StoreKit 2 signed transaction (JWS); its x5c chain must end in Apple Root CA - G3
  (pinned SHA-256), every certificate must be valid and signed by the next, and the ES256 signature must verify.
  `bundleId`, `productId`, `type` and `environment` (Sandbox only outside production) are checked.

Response `200`: an envelope in the same format and key as `/config`, whose payload is

```json
{ "type": "ad_free_entitlement", "platform": "android", "productId": "remove_ads_monthly",
  "status": "active|grace|canceled|expired|revoked|pending", "issuedAt": "ISO", "expiresAt": "ISO" }
```

`expiresAt` = min(store expiry, now + 7 days), so the app re-verifies at least weekly and cancellations/refunds propagate.
The app grants ad-free only for `active|grace|canceled` with `expiresAt` in the future.

Errors: `400 unknown_product | invalid_purchase | product_mismatch | environment_mismatch | validation_failed`,
`501 not_configured` (store credentials missing), `503 store_unavailable | signing_key_unavailable`.

## Admin API — `/api/admin` (session required)

**Auth model** (enforced server-side in `src/lib/admin-route.ts` for every route):

1. Non-GET: `Origin` must equal `PUBLIC_BASE_URL`'s origin or match the `Host` header → else `403 bad_origin`.
2. Cookie `vela_admin` (opaque 256-bit token; DB stores SHA-256 only; `HttpOnly; SameSite=Strict; Path=/`,
   `Secure` when `APP_ENV` ≠ development). Idle timeout 12 h, absolute 7 days → else `401 unauthenticated`.
3. Non-GET: header `x-csrf-token` must equal the session's CSRF token → else `403 csrf_failed`.
   Get it from `GET /api/admin/auth/me` (or the login response).
4. Role check → else `403 forbidden`. Roles: `READONLY` (view) < `ADMIN` (edit + publish) < `OWNER` (+ users).

Every mutation writes an `AuditLog` row (actor, action, entity, before/after, admin IP).
Common errors: `400 validation_failed|invalid_json`, `404 not_found`, `409 conflict` (unique key),
`413 payload_too_large`, `415 unsupported_media_type`, `500 internal_error`. All responses `Cache-Control: no-store`.

### Auth
| Method | Path | Role | Body → Response |
|---|---|---|---|
| POST | `/auth/login` | — (Origin check only) | `{email, password}` → `200 {ok, csrfToken}` + `Set-Cookie`. Failures: `401 login_failed` (generic, same for unknown user / wrong password / disabled / locked), `429 rate_limited` (≥ 5 failures per ip+email in 15 min). 5 consecutive failures lock the account for 15 min. Any session cookie sent along is destroyed (rotation). |
| POST | `/auth/logout` | READONLY | → `200 {ok}`; deletes session, clears cookie |
| GET | `/auth/me` | READONLY | → `{user:{id,email,role}, csrfToken, session:{expiresAt,lastSeenAt}}` |
| POST | `/auth/password` | READONLY | `{currentPassword, newPassword(≥12)}` → `200`; other sessions of the user are revoked. `400 wrong_password` |
| GET | `/status` | READONLY | dashboard data: `dbOk, signingKeyConfigured, keyId, current{version,createdAt,note}, fetches{days[],total}, openReports, activeBlocklist, admob:{connected:false}` |

### Shortcuts
| Method | Path | Role | Notes |
|---|---|---|---|
| GET | `/shortcuts` | READONLY | `{items:[{id,key,titles{en,ar?,de?},url,iconKey,iconAssetId,color,order,enabled}]}` |
| POST | `/shortcuts` | ADMIN | `{key, titles{en,ar,de}, url, iconKey\|null, iconAssetId\|null, color, enabled}` → `201 {item}`. `key` = payload `id` (`^[a-z0-9][a-z0-9_-]{0,39}$`); `url` https + public host; titles ≤ 40 chars, `en` required (blank `ar`/`de` are dropped); `iconKey` ∈ contract allowlist; ≤ 24 enabled |
| PUT | `/shortcuts/{id}` | ADMIN | same body → `{item}` |
| DELETE | `/shortcuts/{id}` | ADMIN | → `{ok}` |
| POST | `/shortcuts/reorder` | ADMIN | `{ids:[...all shortcut ids in order]}` → `{ok}` |
| POST | `/assets` | ADMIN | `multipart/form-data` field `file`: PNG/JPEG/WebP (magic-byte sniffed), ≤ 512 KB; SVG/GIF/others rejected (`400 invalid_image`). Re-encoded with sharp to PNG 128×128 (metadata stripped), deduplicated by SHA-256 → `201 {id, url, sha256, width, height, mime}`. There is no fetch-by-URL feature. |

### Ads
| GET | `/ads` | READONLY | `{globalEnabled, frequency{interstitialMinIntervalSec, interstitialMaxPerSession}, placements[{key,format,enabled,adUnitIdAndroid,adUnitIdIos}]}` |
|---|---|---|---|
| PUT | `/ads` | ADMIN | same shape (without `format`, derived from key). `minInterval` 300–86400, `maxPerSession` 0–3 (also a DB CHECK constraint); unit ids `^ca-app-pub-\d{16}/\d{10}$` or `""`; keys `home_banner|downloads_banner|tabs_interstitial` |

### Blocklists
| GET | `/blocklists` | READONLY | `{items:[{version,name,license,sha256,ruleCount,status,createdAt,activatedAt,createdBy}]}` |
|---|---|---|---|
| POST | `/blocklists` | ADMIN | `{name, license, rulesText}` (`rulesText` = JSON array of rules or `{rules:[...]}`; ≤ 1 MB) → `201 {item:{version,sha256,ruleCount,status:"DRAFT"}}`; version = max + 1. `400 invalid_blocklist` with `details: string[]` |
| GET | `/blocklists/{version}` | READONLY | `{item:{..., body}}` |
| POST | `/blocklists/{version}/activate` | ADMIN | makes it the single ACTIVE list (previous ACTIVE → ARCHIVED). Takes effect on next publish |
| POST | `/blocklists/{version}/archive` | ADMIN | DRAFT/ACTIVE → ARCHIVED |

### Content & notices
| GET | `/content` | READONLY | `{privacyUrl, termsUrl, supportUrl, helpText{en,ar?,de?}, minAppVersion, maxAppVersion, blockingEnabledByDefault}` |
|---|---|---|---|
| PUT | `/content` | ADMIN | same; URLs https-only; help text ≤ 4000/locale; versions `x.y.z` or `""`/null; min ≤ max |
| GET | `/notices` | READONLY | `{items:[{id,key,severity,message,minAppVersion,maxAppVersion,active}]}` |
| POST | `/notices` | ADMIN | `{key, severity: info\|update, message{en,ar,de} (≤ 280), minAppVersion, maxAppVersion, active}` → `201`; ≤ 20 active |
| PUT/DELETE | `/notices/{id}` | ADMIN | update / delete |

### Publish & releases
| GET | `/publish` | READONLY | draft preview: `{nextVersion, valid, issues[], draft, current{version,createdAt,content}\|null, diff[{path,kind:added\|removed\|changed,before,after}]}` (diff ignores `configVersion`) |
|---|---|---|---|
| POST | `/publish` | ADMIN | `{note?}` (≤ 500) → `201 {version, createdAt}`. Builds the draft inside a SERIALIZABLE transaction, validates with the same schema used for signing (`422 draft_invalid` + issues otherwise), stores `ConfigRelease(version = max+1, isCurrent = true)` |
| GET | `/releases` | READONLY | `{items:[{version,note,createdAt,createdBy,rolledBackFromVersion,isCurrent}]}` |
| GET | `/releases/{version}` | READONLY | `{item:{..., content}}` |
| POST | `/releases/{version}/rollback` | ADMIN | `{note?}` → `201 {version: max+1, rolledBackFromVersion}` — a NEW release with the old content (apps reject lower `configVersion`). `404 release_not_found`, `422 release_invalid` |

Draft assembly: enabled shortcuts by `order` (payload `order` re-numbered 0..n-1), ad settings + placements,
the ACTIVE blocklist (`listPath = /api/v1/blocklists/{v}`, its `sha256`, `ruleCount`), content settings
(incl. `minAppVersion`/`maxAppVersion`/`blockingEnabledByDefault`), active notices.

### Reports, audit, users
| GET | `/reports?status=NEW\|TRIAGED\|CLOSED&page=1&pageSize=50` | READONLY | `{total,page,pageSize,items[]}` |
|---|---|---|---|
| PATCH | `/reports/{id}` | ADMIN | `{status}` → `{item}` |
| GET | `/audit?page=1&pageSize=50` | READONLY | `{total,page,pageSize,items[{at,actor,action,entity,entityId,before,after,ip}]}` |
| GET | `/users` | OWNER | `{items:[{id,email,role,disabled,lockedUntil,createdAt,lastLoginAt}]}` |
| POST | `/users` | OWNER | `{email, role, password(≥12)}` → `201 {item}` |
| PATCH | `/users/{id}` | OWNER | any of `{role, disabled, password, unlock:true}`. Role/disabled/password changes revoke that user's sessions. `409 last_owner` (cannot demote/disable the last active OWNER), `409 self_disable` |
