# TODO — Ford Fusion first

Working list for the current product goal: a buyer with a Ford Fusion picks the
exact car (or enters the VIN), lands on parts that really fit it, and finds
offers from Baku sellers. One task at a time, top to bottom; tick it off in the
same commit that finishes it. Decisions already taken are recorded under each
task so they don't get re-asked.

## Now

- [x] **1. Variant-level fitments in the admin.** Code-complete in api PR #1 and
  web PR #4 (branch `feat/variant-fitments` in both); live once merged and the
  VM is updated. The "seed scripts attach fitments per variant" part has no
  script to change yet: the first part seed (task 4) inserts fitments per
  variant directly in SQL. Original note: Today a fitment is
  make + model + year and attaches the part to *every* variant of that model
  year, so an oil filter for the 2.0 EcoBoost would also show for 2.5 Duratec
  cars and the new Trim/Engine picker would filter nothing. Extend
  `FitmentInput` with optional trim / engine (or explicit variant ids), give
  the admin `FitmentPicker` the same Trim and Engine selects the buyer picker
  has, and make the seed scripts attach fitments per variant. Prerequisite for
  tasks 4–6.

- [x] **2. Fusion I (CD338, MY2006–2012) generation + variants, US market.**
  Done in `scripts/seed-ford-fusion-i-variants.sh` (branch `feat/fusion-i-variants`):
  41 variants, sources in the header; MY2020 SE 1.5 EcoBoost added, SEL 2.0 AWD
  confirmed not sold. Run the extracted SQL on prod after merge. Original note:
  Second generation under the `fusion` model, so the picker starts showing the
  Generation step for Fusion. Trims and engines per year with sources (Ford
  press kits / owner's manuals / vPIC), delivered as a SQL seed like
  `scripts/seed-ford-fusion-variants.sh` that is run on prod from the DB
  client, not the VM. Also settle the two unverified MY2020 CD391 rows noted at
  the bottom of that script (SE 1.5 EcoBoost, SEL 2.0 EcoBoost).
  *Decision: yes, gen 1 is in scope (2026-11-09).*

- [x] **3. Category tree for Fusion, az / ru / en.** Done in
  `scripts/seed-category-tree.sh` (api branch `feat/category-tree`): 11 roots,
  75 leaves, upsert by slug, nothing deleted; prod's `engine` and
  `exhaust-system` stay roots, `radiator` moves under Cooling, `front-axle`
  under Suspension & steering. Lucide icons for the new slugs in web branch
  `feat/category-icons`. Run the extracted SQL on prod (seed-only, no VM
  rebuild). Original note: Prod has four placeholder
  roots (engine, exhaust-system, radiator, front-axle) and two parts. Proposed
  roots, to confirm before seeding: Maintenance (filters, oil, spark plugs,
  belts, wipers), Brakes, Suspension & steering, Engine, Cooling, Electrical &
  lighting, Body (bumpers, fenders, hood, grille, mirrors), Interior,
  Transmission, Exhaust, HVAC. Merge into the existing tree; do not wipe the
  categories that already hold parts.
  *Decision: the 11 roots confirmed as proposed (2026-11-09).*

- [x] **4. Service parts, batch 1 — Fusion II (CD391), per engine.** Done in
  `scripts/seed-ford-fusion-service-parts.sh` (branch `feat/fusion-service-parts`):
  80 parts, 325 numbers (164 Ford service, 128 Motorcraft, 33 aftermarket) and
  2,250 fitments per variant; every CD391 variant gets 19–32 parts (Energi the
  fewest). Sources per claim and the LEFT OUT list are in the script header.
  Below the 90% bar and therefore not seeded: front lower control arms (two
  parallel Ford families, no deciding factor), 2017–2020 rear shocks for I4 and
  hybrids (split by assembly plant), everything AWD-specific at the rear (link,
  hub, non-Sport pad), Energi and Sport rear rotors, the 2.7 V6 plug for
  MY2018–2019, and aftermarket numbers for plugs, coils, belts, cooling and hubs
  (catalog sites block fetches). Wheel size (16–18 vs 19 in) and keyless /
  start-stop splits live in `fitments.notes`, since the variant key has no
  such attribute. Run the extracted SQL on prod after merge. Original note: The
  ~40 most-demanded wear and service parts for each engine (2.5 Duratec,
  1.5 / 1.6 / 2.0 EcoBoost, 2.7 EcoBoost V6, 2.0 Atkinson HEV/PHEV): oil / air /
  cabin / fuel filters, spark plugs, ignition coils, serpentine belt, thermostat,
  water pump, front and rear pads and rotors, wiper blades, battery, struts,
  control arms, sway bar links, wheel bearings. Motorcraft OEM numbers plus
  common aftermarket cross-references, every number with a cited source, no
  guessed numbers. Fitments per variant. Delivered as a SQL seed.
  *Decision: service parts before body parts (2026-11-09).*

- [ ] **5. Service parts, batch 2 — Fusion I (CD338).** Same approach for the
  2.3 Duratec, 3.0 Duratec V6, 2.5 Duratec, 3.5 V6 and 2.5 Atkinson Hybrid.

- [ ] **6. Body and lighting.** Headlights, taillights, bumpers, fenders, hood,
  grille, mirrors, radiator support. Split by facelift: CD391 2013–2016 vs
  2017–2020, CD338 2006–2009 vs 2010–2012.

- [ ] **7. Diagrams.** Ford's exploded views are copyrighted, so this needs
  images we own (photos or drawn schematics). Parked until the image source is
  decided; the diagram model, editor and category embed already exist.

- [ ] **8. Sellers and offers.** After batch 1, onboard two or three Fusion
  parts sellers in Baku and create listings against those parts. This is the
  first real test of the marketplace flow.

## Housekeeping (whenever convenient)

- [ ] `DevSeedService` still seeds its own five-root tree; after
  `POST /api/v1/dev/catalog/seed` run `scripts/seed-category-tree.sh` to get
  the canonical tree locally, or make the dev seed run the same SQL.
- [ ] README still says Spring Boot 3.3 + Meilisearch; it is 3.5 + Postgres
  full-text search + Redis.
- [ ] Six pre-existing `react-hooks/set-state-in-effect` warnings in
  autoparts-web (downgraded from errors on 2026-11-08).
- [ ] Decide whether `management.health.redis` should be excluded from the
  health endpoint (the VIN cache degrades gracefully without Redis).
- [ ] Consider making Trim / Engine mandatory in the picker once the parts are
  per engine (one-line change: `canSubmit` requires a resolved variant).

## Done

- [x] Vehicle page redesign (web `feat/vehicle-page-redesign`, api
  `feat/vehicle-page-data`): hero with spec chips and the car render, category
  photo cards with per-car part counts, parts strip with lowest offer price,
  vehicle info sidebar. All 11 roots have a bundled photo (web PR #8 added
  the last three); hp / transmission / drivetrain chips need columns the
  variant table does not have.
- [x] VIN lookup: NHTSA vPIC decode + catalog match, cached in Redis
  (`GET /api/v1/catalog/vin/{vin}`), VIN row in the buyer picker.
- [x] Fusion II (CD391, MY2013–2020) generation + 89 US-market variants in prod.
- [x] Buyer picker: Trim and Engine selects; the exact variant travels through
  the garage, the vehicle page URL (`?variant=`) and the category filters.
- [x] API: `variant=` filter on category parts and diagrams.
- [x] Production: Hetzner VM (api / cdn via Caddy), Cloudflare Workers Builds
  for the web app, Redis in the prod compose.
