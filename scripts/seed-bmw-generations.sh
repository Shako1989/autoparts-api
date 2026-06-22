#!/usr/bin/env bash
# Seed real-world BMW generations into the local dev Postgres.
#
# Mirrors what's already in production:
#   3 Series   E36, E46, E90, F30, G20
#   5 Series   E34, E39, E60, F10, G30, G60
#   X5         E53, E70, F15, G05
#
# Requires:
#   - autoparts-postgres container running (the dev compose stack)
#   - V7 (vehicle_generations) already applied — confirm with:
#       docker exec autoparts-postgres psql -U autoparts -d autoparts \
#         -c "SELECT version FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 1;"
#
# Idempotency:
#   - INSERTs use ON CONFLICT (model_id, slug) DO NOTHING — safe to re-run.
#   - UPDATEs that rename "gen" → real chassis code are guarded by WHERE slug='gen',
#     so once renamed they won't be touched again.
#   - Existing variants are reassigned to the chassis code that actually fits
#     their year (2016 320i → F30, 2018 X5 xDrive40i → G05).
#
# Run:
#   ./scripts/seed-bmw-generations.sh

set -euo pipefail

CONTAINER="${CONTAINER:-autoparts-postgres}"

docker exec -i "$CONTAINER" psql -U autoparts -d autoparts -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- Helper: model IDs.
\set bmw_make_slug 'bmw'

WITH bmw AS (SELECT id FROM vehicle_makes WHERE slug = :'bmw_make_slug')
SELECT m.slug, m.id
  FROM vehicle_models m, bmw
 WHERE m.make_id = bmw.id AND m.slug IN ('3-series','5-series','x5');

-- ============================================================
-- 3 SERIES — add E36, E46, E90, F30, G20.
-- If the original backfill "gen" still exists, rename it to E90
-- (matches what we did in prod). Otherwise leave whatever's there.
-- ============================================================

UPDATE vehicle_generations g
   SET code = 'E90', name = '3 Series E90', slug = 'e90',
       year_from = 2005, year_to = 2011,
       updated_at = now(), updated_by = 'seed-bmw-generations'
  FROM vehicle_models m, vehicle_makes mk
 WHERE g.model_id = m.id AND m.slug = '3-series'
   AND m.make_id = mk.id AND mk.slug = 'bmw'
   AND g.slug = 'gen';

INSERT INTO vehicle_generations (id, model_id, code, name, slug, year_from, year_to, created_at, updated_at, created_by, updated_by)
SELECT gen_random_uuid(), m.id, v.code, v.name, v.slug, v.yf, v.yt,
       now(), now(), 'seed-bmw-generations', 'seed-bmw-generations'
  FROM vehicle_models m
  JOIN vehicle_makes mk ON mk.id = m.make_id
  CROSS JOIN (VALUES
    ('E36', '3 Series E36', 'e36', 1990::smallint, 2000::smallint),
    ('E46', '3 Series E46', 'e46', 1998::smallint, 2006::smallint),
    ('E90', '3 Series E90', 'e90', 2005::smallint, 2011::smallint),
    ('F30', '3 Series F30', 'f30', 2012::smallint, 2019::smallint),
    ('G20', '3 Series G20', 'g20', 2019::smallint, 2024::smallint)
  ) AS v(code, name, slug, yf, yt)
 WHERE mk.slug = 'bmw' AND m.slug = '3-series'
ON CONFLICT (model_id, slug) DO NOTHING;

-- 2016 320i belongs to F30 (2012-2019)
UPDATE vehicle_variants vv
   SET generation_id = (SELECT g.id FROM vehicle_generations g
                          JOIN vehicle_models m ON m.id = g.model_id
                          JOIN vehicle_makes mk ON mk.id = m.make_id
                         WHERE mk.slug = 'bmw' AND m.slug = '3-series' AND g.slug = 'f30'),
       updated_at = now(), updated_by = 'seed-bmw-generations'
 WHERE vv.year = 2016
   AND vv.generation_id IN (SELECT g.id FROM vehicle_generations g
                              JOIN vehicle_models m ON m.id = g.model_id
                              JOIN vehicle_makes mk ON mk.id = m.make_id
                             WHERE mk.slug = 'bmw' AND m.slug = '3-series');

-- ============================================================
-- 5 SERIES — add E34, E39, E60, F10, G30, G60.
-- Rename default "gen" → G30 if it still exists.
-- ============================================================

UPDATE vehicle_generations g
   SET code = 'G30', name = '5 Series G30', slug = 'g30',
       year_from = 2017, year_to = 2023,
       updated_at = now(), updated_by = 'seed-bmw-generations'
  FROM vehicle_models m, vehicle_makes mk
 WHERE g.model_id = m.id AND m.slug = '5-series'
   AND m.make_id = mk.id AND mk.slug = 'bmw'
   AND g.slug = 'gen';

INSERT INTO vehicle_generations (id, model_id, code, name, slug, year_from, year_to, created_at, updated_at, created_by, updated_by)
SELECT gen_random_uuid(), m.id, v.code, v.name, v.slug, v.yf, v.yt,
       now(), now(), 'seed-bmw-generations', 'seed-bmw-generations'
  FROM vehicle_models m
  JOIN vehicle_makes mk ON mk.id = m.make_id
  CROSS JOIN (VALUES
    ('E34', '5 Series E34', 'e34', 1988::smallint, 1996::smallint),
    ('E39', '5 Series E39', 'e39', 1995::smallint, 2004::smallint),
    ('E60', '5 Series E60', 'e60', 2003::smallint, 2010::smallint),
    ('F10', '5 Series F10', 'f10', 2010::smallint, 2017::smallint),
    ('G30', '5 Series G30', 'g30', 2017::smallint, 2023::smallint),
    ('G60', '5 Series G60', 'g60', 2023::smallint, NULL::smallint)
  ) AS v(code, name, slug, yf, yt)
 WHERE mk.slug = 'bmw' AND m.slug = '5-series'
ON CONFLICT (model_id, slug) DO NOTHING;

-- ============================================================
-- X5 — add E53, E70, F15, G05.
-- Rename default "gen" → G05 if still exists. The 2018 xDrive40i
-- belongs to G05 — reassigning gets it onto the right chassis code
-- even if the default has already been renamed in a prior run.
-- ============================================================

UPDATE vehicle_generations g
   SET code = 'G05', name = 'X5 G05', slug = 'g05',
       year_from = 2018, year_to = 2024,
       updated_at = now(), updated_by = 'seed-bmw-generations'
  FROM vehicle_models m, vehicle_makes mk
 WHERE g.model_id = m.id AND m.slug = 'x5'
   AND m.make_id = mk.id AND mk.slug = 'bmw'
   AND g.slug = 'gen';

INSERT INTO vehicle_generations (id, model_id, code, name, slug, year_from, year_to, created_at, updated_at, created_by, updated_by)
SELECT gen_random_uuid(), m.id, v.code, v.name, v.slug, v.yf, v.yt,
       now(), now(), 'seed-bmw-generations', 'seed-bmw-generations'
  FROM vehicle_models m
  JOIN vehicle_makes mk ON mk.id = m.make_id
  CROSS JOIN (VALUES
    ('E53', 'X5 E53', 'e53', 1999::smallint, 2006::smallint),
    ('E70', 'X5 E70', 'e70', 2006::smallint, 2013::smallint),
    ('F15', 'X5 F15', 'f15', 2013::smallint, 2018::smallint),
    ('G05', 'X5 G05', 'g05', 2018::smallint, 2024::smallint)
  ) AS v(code, name, slug, yf, yt)
 WHERE mk.slug = 'bmw' AND m.slug = 'x5'
ON CONFLICT (model_id, slug) DO NOTHING;

UPDATE vehicle_variants vv
   SET generation_id = (SELECT g.id FROM vehicle_generations g
                          JOIN vehicle_models m ON m.id = g.model_id
                          JOIN vehicle_makes mk ON mk.id = m.make_id
                         WHERE mk.slug = 'bmw' AND m.slug = 'x5' AND g.slug = 'g05'),
       updated_at = now(), updated_by = 'seed-bmw-generations'
 WHERE vv.year = 2018
   AND vv.generation_id IN (SELECT g.id FROM vehicle_generations g
                              JOIN vehicle_models m ON m.id = g.model_id
                              JOIN vehicle_makes mk ON mk.id = m.make_id
                             WHERE mk.slug = 'bmw' AND m.slug = 'x5');

COMMIT;

-- ============================================================
-- Verify
-- ============================================================
SELECT m.slug AS model,
       g.slug AS gen_slug,
       g.code,
       g.year_from,
       g.year_to,
       (SELECT COUNT(*) FROM vehicle_variants v WHERE v.generation_id = g.id) AS variants
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id  = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 WHERE mk.slug = 'bmw' AND m.slug IN ('3-series','5-series','x5')
 ORDER BY m.slug, g.year_from;
SQL
