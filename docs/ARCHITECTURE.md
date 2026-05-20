# AutoParts.az — Architecture & Technical Notes

Cross-repo technical reference covering `autoparts-api`, `autoparts-web`, and `autoparts-infra`. This is the source of truth for the **marketplace v1** slice (identity + listings + Postgres search + diagram callouts). It also captures conventions, demo data, and known limitations so the work can be resumed cold.

Repos live under `/Users/shakirg/Projects/`:

- `autoparts-api` — Spring Boot 3.5 + Java 21 backend.
- `autoparts-web` — Vite + React 19 + Tailwind frontend.
- `autoparts-infra` — Docker Compose for local Postgres / Redis / MinIO / Meilisearch / MailHog.

---

## 1. Module layout (backend)

Top-level packages under `az.autoparts.api`:

- `catalog` — vehicles, categories, parts, part_numbers, fitments, diagrams.
- `identity` — users, seller profiles, OTP, auth.
- `listings` — listings + photos.
- `search` — Postgres-backed search.
- `common` — security, storage, auditing, locale, pagination, error handling.

**Module boundary rules** (see `package-info.java` in each module):

- Repositories are package-private.
- Other modules call only the public service interfaces (e.g. `CatalogService`, `IdentityService`, `ListingService`).
- **JPA entities never cross modules.** DTOs do. Where one module needs to reference another module's row, store a raw `UUID` column with no `@ManyToOne` (e.g. `Listing.sellerId`, `Listing.partId`). FK constraints are enforced in the DB; cross-module hydration goes through `CatalogService.getPartsSummary(...)` and `IdentityService.getSellerSummaries(...)`.

The catalog module is the most populated (~40+ files). identity/listings/search were built in the marketplace v1 effort.

---

## 2. Database

Migrations live under `autoparts-api/src/main/resources/db/migration/`.

| Version | Adds |
|---------|------|
| V1 | pgcrypto extension only |
| V2 | catalog: vehicle_makes/models/variants, categories, parts, part_numbers, cross_references, fitments |
| V3 | diagrams + diagram_callouts (pixel coords on a raster image) |
| V4 | marketplace v1: users, seller_profiles, listings, listing_photos, otp_codes + `pg_trgm` extension + trigram GIN indexes on `parts.name_*` and `part_numbers.number` |
| V5 | alters `listings.currency` from `CHAR(3)` to `VARCHAR(3)` so it validates against the JPA entity (Hibernate maps `String` → `VARCHAR`) |

**Audit columns** on most tables: `created_at`, `updated_at`, `created_by`, `updated_by`. The auditor is filled by `JpaAuditingConfig.CurrentAuditorProvider`, which pulls the user UUID from `SecurityContextHolder` (falls back to `"system"`).

**Entities that intentionally skip `AuditableEntity`:** `OtpCode` (write-once; only `created_at`).

### Key constraints / indexes worth remembering

- `users.phone` is unique and validated against E.164 (`^\+[1-9][0-9]{6,18}$`).
- `users.role` is a string check (`BUYER` / `SELLER` / `STAFF` / `ADMIN`).
- `seller_profiles.user_id` is unique (one-to-one with `users`).
- `listings`: `(part_id) WHERE status='ACTIVE'` partial index; `(seller_id, status)`; `(status, published_at DESC)`. Status is `DRAFT`/`ACTIVE`/`PAUSED`/`SOLD`/`ARCHIVED`. Condition is `NEW`/`USED`/`REFURBISHED`. `price_minor BIGINT > 0`. `currency VARCHAR(3) DEFAULT 'AZN'`.
- `listing_photos`: `UNIQUE (listing_id, position)`.
- `otp_codes`: `(phone, expires_at DESC) WHERE consumed_at IS NULL` partial index. Stored hash is BCrypt; **plaintext is never persisted**.
- `diagrams.image_url VARCHAR(512)`; one of `category_id` or `vehicle_variant_id` must be set (`ck_diagrams_scope`).
- `diagram_callouts (diagram_id, label)` unique.

---

## 3. Authentication

### Phone + OTP flow

1. `POST /api/v1/auth/otp/request { phone, purpose }` — `purpose` is `REGISTER` or `LOGIN`. The service generates a 6-digit code, BCrypts it, inserts an `otp_codes` row with `expires_at = now + 10 min`, then calls `OtpSender.send(phone, code, purpose)`.
2. `POST /api/v1/auth/otp/verify { phone, code, fullName? }` — finds the latest non-consumed code, BCrypt-matches, on miss increments `attempts` (lock at 5), on hit marks consumed. Upserts `User` (defaults `role=BUYER`). Returns a signed JWT.

### Dev OTP sender

`DevOtpSender` (gated to `local`/`default` profiles) writes the code to stdout **and** stashes plaintext in a `ConcurrentHashMap<phone, Entry>` with a 15-minute TTL. The dev-only route reads from this map:

```
GET /api/v1/dev/otp/{phone}   → 200 { phone, code } or 404
```

This is what the LoginPage's "Fetch dev code" button calls in `import.meta.env.DEV`.

Real SMS is deferred. The interface lets you swap to a real `OtpSender` (Twilio / Vonage / local AZ gateway) without touching anything else.

### JWT

HS256, configured via `app.jwt.{secret, issuer, access-ttl}` in `application-local.yml`. Library is jjwt 0.12.x (added to `build.gradle.kts`). Claims: `sub=userId`, `role`, `phone`.

**`JwtAuthenticationFilter` reads the role from the DB each request** via `CurrentRoleResolver`. This means a `BUYER → SELLER` promotion (via `POST /my/seller`) takes effect on the next request without re-issuing the token. Role lives in `users.role`; the token's role claim is effectively a hint and is overridden if the DB has a fresher value.

### Spring Security

`SecurityConfig` filter chain:

- `permitAll`: `/api/v1/auth/**`, `/api/v1/catalog/**`, `/api/v1/search`, `GET /api/v1/parts/**`, `GET /api/v1/listings/*`, `/api/v1/dev/**`, `/v3/api-docs/**`, `/swagger-ui/**`, `/actuator/health`.
- `authenticated()`: everything else (notably `/api/v1/my/**` and listing write methods).
- `@PreAuthorize("hasRole('SELLER')")` on `MyListingsController` and listing-write endpoints (the resolved role from `JwtAuthenticationFilter` is what `hasRole` checks).
- `BCryptPasswordEncoder` is registered as a `@Bean` and used by `AuthServiceImpl` for code hashing.

---

## 4. Object storage (MinIO)

### Buckets

| Bucket | Purpose | Anonymous policy | Notes |
|--------|---------|------------------|-------|
| `autopart-diagrams` | Catalog diagrams (e.g. exploded engine views). Created manually by user. | `download` (anonymous-read) | Images referenced from `diagrams.image_url` directly. Browser fetches via `<img src>` straight from MinIO. |
| `autoparts-listings` | Per-listing photos. Bucket created via `mc mb` (or console). | `download` (anonymous-read) | Set the policy with: `mc anonymous set download local/autoparts-listings`. Without it the `<img>` returns 403 even though the file is uploaded. |

### Wiring

`common/storage/S3Config` builds `S3Client` and `S3Presigner` beans with MinIO's path-style addressing forced on. Credentials/endpoint live in `application-local.yml` under `app.s3`.

`S3StorageService` exposes:

- `presignPut(bucket, key, contentType, ttl)` → returns the upload URL + expiry (default TTL 10 min for listing photos).
- `publicUrlForListing(key)` → returns `app.s3.listings-public-base + "/" + key`.
- `deleteObject(bucket, key)`.

### Listing photo upload (frontend)

`autoparts-web/src/components/seller/PhotoUploader.tsx`:

1. Browser asks `POST /api/v1/listings/{id}/photos/presign { contentType }` (requires SELLER JWT, ownership-checked).
2. Server returns `{ uploadUrl, s3Key, publicUrl, expiresInSeconds }`. Key format: `listings/{listingId}/{randomUuid}.{ext}` in bucket `autoparts-listings`.
3. Browser does **bare** `axios.put(uploadUrl, file, { headers: { 'Content-Type': file.type }, transformRequest: [(d)=>d] })`. **Do not use `apiClient`** — it would inject `Accept-Language` and `Authorization`, which MinIO rejects.
4. Browser asks `POST /api/v1/listings/{id}/photos { s3Key, position }`. Server persists a `listing_photos` row with `url = publicUrl`.

### Cache busting

Re-uploading a file under the **same key** keeps the same URL, so browsers serve the cached copy. Two options handled today:

- Append `?v=<ts>` to the stored URL (one-off DB UPDATE).
- Hard-refresh in the browser.

For long-term we want either versioned keys or `Cache-Control: no-cache` on the bucket. Not done.

### Demo data already loaded

- `bmw-3-2016-engine` — engine diagram. Image: `http://localhost:9000/autopart-diagrams/3lct.png`. 1 callout (`"1"`) → part "N20 2000 engine N47D20D", OEM `11002223006` (BMW).
- `carrier-wheel-bearing-front` — diagram under category `Front Axle → Carrier/wheel bearing, front`. Image: `http://localhost:9000/autopart-diagrams/Carrier_left.png` (currently with a `?v=…` cache-buster). 3 callouts:
  - `"1"` → DSC pulse generator, front — OEM `34526782099`
  - `"2"` → Carrier, left — OEM `31216775769`
  - `"3"` → Wheel hub with bearing, front — OEM `31204081309`

The standalone diagram pages live at `/d/{slug}` and the category page (`/c/carrier-wheel-bearing-front`) embeds the diagram inline because of the category→diagrams relationship.

### Seed scripts

- `autoparts-api/scripts/seed-bmw-engine-diagram.sh` — uploads a BMW engine image to MinIO and inserts the matching part + part_number + diagram + callout rows. Idempotent re-runs fail (slug unique); delete the diagram first if you want to re-run.
- `autoparts-api/src/main/java/az/autoparts/api/catalog/dev/DevSeedService.java` — wipes and reseeds the demo catalog (makes/models/variants, categories, parts, fitments, part_numbers). Triggered via `POST /api/v1/dev/catalog/seed` (local profile only).

---

## 5. REST endpoints

| Method | Path | Auth | Role | Notes |
|---|---|---|---|---|
| POST | `/api/v1/auth/otp/request` | none | — | Sends OTP |
| POST | `/api/v1/auth/otp/verify` | none | — | Returns JWT + MeResponse |
| GET  | `/api/v1/auth/me` | JWT | any | Current user summary |
| GET  | `/api/v1/dev/otp/{phone}` | none (local) | — | Dev-only OTP read-back |
| POST | `/api/v1/dev/catalog/seed` | none (local) | — | Wipe + reseed demo catalog |
| GET  | `/api/v1/catalog/makes` | none | — | |
| GET  | `/api/v1/catalog/makes/{slug}/models` | none | — | |
| GET  | `/api/v1/catalog/models/{id}/years` | none | — | |
| GET  | `/api/v1/catalog/variants?model=…&year=…` | none | — | |
| GET  | `/api/v1/catalog/categories` | none | — | Tree |
| GET  | `/api/v1/catalog/categories/{slug}` | none | — | Detail |
| GET  | `/api/v1/catalog/categories/{slug}/parts` | none | — | Paginated |
| GET  | `/api/v1/catalog/categories/{slug}/diagrams` | none | — | List for inline embed |
| GET  | `/api/v1/catalog/parts/{id}` | none | — | |
| GET  | `/api/v1/catalog/parts/{id}/fitments` | none | — | |
| GET  | `/api/v1/catalog/diagrams/{slug}` | none | — | Full diagram + callouts |
| POST | `/api/v1/my/seller` | JWT | any | Promote to SELLER + create profile |
| GET  | `/api/v1/my/seller` | JWT | SELLER | |
| PATCH | `/api/v1/my/seller` | JWT | SELLER | |
| POST | `/api/v1/listings` | JWT | SELLER | Create |
| GET  | `/api/v1/listings/{id}` | none | — | Detail (public) |
| PATCH | `/api/v1/listings/{id}` | JWT | SELLER (owner) | |
| POST | `/api/v1/listings/{id}/photos/presign` | JWT | SELLER (owner) | Returns presigned PUT URL |
| POST | `/api/v1/listings/{id}/photos` | JWT | SELLER (owner) | Confirm upload |
| DELETE | `/api/v1/listings/{id}/photos/{photoId}` | JWT | SELLER (owner) | |
| GET  | `/api/v1/my/listings?status=` | JWT | SELLER | |
| GET  | `/api/v1/parts/{partId}/listings` | none | — | Active offers for a part |
| GET  | `/api/v1/parts/{partId}/listings/summary` | none | — | `{count, minPriceMinor, currency}` |
| GET  | `/api/v1/search?q=&page=&size=` | none | — | Postgres trigram + exact part-number |

---

## 6. Search (v1)

**Postgres only.** No Meilisearch indexer in v1.

`SearchServiceImpl.search`:

1. Normalize `q`. If `q.replaceAll("\\s+","").length() >= 3`, run exact match on `part_numbers.number` (whitespace stripped + uppercase) → set of `part_id` UUIDs.
2. Run trigram match on the locale's `parts.name_*` column ordered by `similarity DESC`, capped at 500 candidates.
3. Merge: exact hits first, then trigram hits, dedup, then page-slice in app code.
4. Enrich each part via `CatalogService.getPartsSummary` and `ListingService.countActiveForParts`.

If you want unified ranking with a single score across the two strategies later, that's a v2 SQL refactor; the candidate cap should change with it.

---

## 7. Frontend

### Routes (`autoparts-web/src/App.tsx`)

- `/` HomePage, `/c/:slug` CategoryPage, `/v/:make/:model/:year` VehiclePage, `/d/:slug` DiagramPage.
- `/p/:partId` PartPage (part info + offers list).
- `/listings/:listingId` ListingPage (photo carousel + seller card + `tel:` / `wa.me` CTAs).
- `/search` SearchPage (debounced).
- `/login` LoginPage (phone → OTP, with dev-mode "Fetch dev code" button).
- `/sell` SellerDashboardPage (wrapped in `<RequireSeller>`).
- `/sell/onboarding` SellerOnboardingPage (`<RequireAuth>`).
- `/sell/listings/new` and `/sell/listings/:listingId` ListingEditorPage (`<RequireSeller>`).

### State

- `useAuthStore` (Zustand persist) holds `accessToken`, `refreshToken` (unused in v1, kept as `""` for shape stability), and `user { id, phone, fullName?, role }`. Persisted to `localStorage` under `autoparts-auth`.
- `useCartStore`, `useGarageStore`, `useUiStore` exist but aren't load-bearing for the marketplace flows yet.

**Watch out:** Zustand selectors that return new objects (e.g. `(s) => ({ token: s.accessToken, user: s.user })`) trigger infinite re-renders. Use one selector per primitive, or `useShallow`. The marketplace components all use single-value selectors.

### Axios client (`src/api/client.ts`)

Two interceptors on the request side:

- Inject `Accept-Language` from `i18n.resolvedLanguage`.
- Inject `Authorization: Bearer …` from `useAuthStore.getState().accessToken` if present.

Response interceptor:

- On 401 (when a token was actually set), `clear()` the store and `window.location.assign('/login')` unless already there.

### React Query hooks

- `api/auth.ts` — `useRequestOtp`, `useVerifyOtp` (calls `setSession` on success), `useMe`, `useDevOtp` (only fired in `import.meta.env.DEV`).
- `api/sellers.ts` — `useMySellerProfile`, `useBecomeSeller` (also mutates local auth user role to `SELLER`), `useUpdateMySellerProfile`.
- `api/listings.ts` — `useListing`, `usePartListings`, `usePartListingsSummary`, `useMyListings`, `useCreateListing`, `useUpdateListing`, `usePresignPhoto`, `useConfirmPhoto`, `useRemovePhoto`, plus the bare-axios helper `uploadFileToPresignedUrl`.
- `api/search.ts` — `useSearch(q, page, size)` keyed by query + locale.

### Diagram callout panel

`components/catalog/DiagramBlock.tsx` is shared between the standalone DiagramPage and the inline category embed. The `CalloutDetail` sub-component shows part name, brand, OEM/aftermarket numbers, and now a `PartListingsBadge` ("3 offers from … AZN") + a "View offers" link to the part page.

`PartListingsBadge` uses `usePartListingsSummary(partId)` so the cache is keyed by part ID and shared across PartPage, search results, and the diagram callout panel.

---

## 8. Local dev setup

```
# 1. Infra
cd autoparts-infra && docker compose up -d

# 2. Buckets (one-time)
docker exec autoparts-minio sh -c '
  mc alias set local http://localhost:9000 minioadmin minioadmin
  mc mb --ignore-existing local/autopart-diagrams
  mc anonymous set download local/autopart-diagrams
  mc mb --ignore-existing local/autoparts-listings
  mc anonymous set download local/autoparts-listings
'

# 3. API
cd autoparts-api && ./gradlew bootRun --args='--spring.profiles.active=local'

# 4. Web
cd autoparts-web && npm run dev
```

Then visit http://localhost:5173.

**Demo flow:**

```
# OTP for register
curl -X POST http://localhost:8080/api/v1/auth/otp/request \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+994501234567","purpose":"REGISTER"}'

# Read back the dev code
curl http://localhost:8080/api/v1/dev/otp/+994501234567

# Verify and grab JWT
curl -X POST http://localhost:8080/api/v1/auth/otp/verify \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+994501234567","code":"123456","fullName":"Test User"}'
```

Or from the UI: `/login` → enter phone → "Fetch dev code" → verify. Then `/sell/onboarding` → become seller → `/sell/listings/new` → fill form, save, edit, upload photo.

---

## 9. Conventions worth respecting

- **Postgres-first design.** Schema validation is on (`ddl-auto: validate`). The DB type must match what the JPA entity maps to. We hit this once with `CHAR(3)` vs `VARCHAR(3)` (V5 fix).
- **Migrations are append-only.** Never edit a checked-in `Vn__…sql` after it's been applied to any DB; add a new `Vn+1__…sql`.
- **Cross-module access only through public service interfaces.** No reaching into another module's `repo` or `domain`. The compiler can't enforce this — code review does.
- **Locales are `AZ` (default), `RU`, `EN`.** Set via `Accept-Language`. All localized columns (`name_az/_ru/_en`, `title_az/_ru/_en`) are NOT NULL. Seed data fills all three.
- **Money is stored as `BIGINT price_minor` in qəpik** (AZN minor units, 1 AZN = 100 qəpik). Currency is `VARCHAR(3)` defaulting to `'AZN'`.
- **Phones are E.164** with check constraint `^\+[1-9][0-9]{6,18}$`. The frontend `PhoneInput` normalizes input.
- **OTP plaintext is never stored.** Only BCrypt hash. The dev sender's in-memory map exists purely for `/dev/otp/{phone}`.
- **Front-end mutation invalidation:** after `useCreateListing`/`useUpdateListing`, invalidate `['my','listings']` and update the detail cache. After `useConfirmPhoto`, invalidate the listing detail.

---

## 10. Known limitations / things deferred to v2+

- **Real SMS provider** — `OtpSender` interface is stable but only `DevOtpSender` is wired. Need to integrate Twilio / Vonage / a local AZ gateway when launching.
- **Refresh tokens / token rotation** — v1 issues only an access token (TTL 24h). `authStore.refreshToken` field exists and is set to `""` for forward-compat. Plan a httpOnly cookie + rotation flow in v2.
- **JWT in localStorage** — XSS-exposed. Acceptable for dev; revisit when going public.
- **KYC / admin** — `seller_profiles.kyc_status` column exists but no UI or workflow.
- **Ratings** — `rating_avg`/`rating_count` columns exist but nothing writes to them.
- **Orders / payments / shipping** — entirely out of scope for v1.
- **MinIO bucket policies** — set to anonymous-read for dev. Production needs CDN + tighter policies + bucket CORS for browser uploads.
- **Search ranking** — exact-then-trigram dedup, not a unified score. Acceptable for ~10–50k parts. Switch to Meilisearch if relevance becomes a problem.
- **Currency is locked to AZN** — column allows others, UI does not.
- **Image cache busting** — manual `?v=…` bump on re-upload. Long-term: versioned keys or `Cache-Control: no-cache` on the bucket.

---

## 11. Pointers

- Plan file (full implementation plan as approved): `/Users/shakirg/.claude/plans/now-we-need-create-ethereal-sprout.md`
- Brief: `/Users/shakirg/Projects/AutoParts_az_MVP_Developer_Brief.md`
- Contributing guide: `autoparts-api/CONTRIBUTING.md`
