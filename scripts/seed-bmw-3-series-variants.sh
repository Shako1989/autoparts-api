#!/usr/bin/env bash
# Seed representative BMW 3 Series variants for E36, E46, E90, F30, G20.
#
# Market: European / CIS (Azerbaijan primary). M models excluded — they'll be
# seeded separately if needed.
#
# Requires:
#   - autoparts-postgres container running
#   - seed-bmw-generations.sh has been run (or prod state mirrored) so the 5
#     generations E36/E46/E90/F30/G20 exist under bmw 3-series.
#
# Idempotency: every INSERT uses ON CONFLICT (generation_id, year, trim,
# engine_code) DO NOTHING (matches uq_vehicle_variants). The pre-existing
# 2016 320i B48B20 sedan row under F30 is included in the F30 block and
# absorbed by ON CONFLICT.
#
# Sources cited per generation:
#   E36: https://en.wikipedia.org/wiki/BMW_3_Series_(E36)
#        https://www.auto-data.net/en/bmw-3-series-sedan-e36-320i-150hp-16654
#   E46: https://en.wikipedia.org/wiki/BMW_3_Series_(E46)
#        https://www.auto-data.net/en/bmw-3-series-sedan-e46-facelift-2001-320d-150hp-9981
#   E90: https://en.wikipedia.org/wiki/BMW_3_Series_(E90)
#        https://www.auto-data.net/en/bmw-3-series-sedan-e90-lci-facelift-2008-320d-177hp-27741
#   F30: https://en.wikipedia.org/wiki/BMW_3_Series_(F30)
#        https://www.auto-data.net/en/bmw-3-series-sedan-f30-lci-facelift-2015-320d-190hp-22886
#   G20: https://en.wikipedia.org/wiki/BMW_3_Series_(G20)
#        https://www.auto-data.net/en/bmw-3-series-sedan-g20-320d-190hp-34422
#
# Run:  ./scripts/seed-bmw-3-series-variants.sh
#       CONTAINER=autoparts-postgres ./scripts/seed-bmw-3-series-variants.sh

set -euo pipefail

CONTAINER="${CONTAINER:-autoparts-postgres}"

docker exec -i "$CONTAINER" psql -U autoparts -d autoparts -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- ============================================================
-- E36 (1990-2000)
-- ============================================================
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-3-series', 'auto-tech-bmw-3-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (1992::smallint, '318i',  'M40B18',   'sedan',     'PETROL'),
    (1995::smallint, '316i',  'M43B16',   'sedan',     'PETROL'),
    (1996::smallint, '318i',  'M43B18',   'sedan',     'PETROL'),
    (1995::smallint, '320i',  'M52B20',   'sedan',     'PETROL'),
    (1996::smallint, '320i',  'M52B20',   'wagon',     'PETROL'),
    (1994::smallint, '325i',  'M50B25TU', 'coupe',     'PETROL'),
    (1997::smallint, '328i',  'M52B28',   'sedan',     'PETROL'),
    (1996::smallint, '318tds','M41D17',   'hatchback', 'DIESEL'),
    (1996::smallint, '325tds','M51D25',   'sedan',     'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '3-series' AND g.slug = 'e36'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- ============================================================
-- E46 (1998-2006) — sedan / wagon / coupe / convertible / compact
-- ============================================================
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-3-series', 'auto-tech-bmw-3-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (1999::smallint, '320i', 'M52TUB20', 'sedan',       'PETROL'),
    (2003::smallint, '318i', 'N42B20',   'sedan',       'PETROL'),
    (2003::smallint, '320i', 'M54B22',   'sedan',       'PETROL'),
    (2004::smallint, '320i', 'M54B22',   'wagon',       'PETROL'),
    (2004::smallint, '325i', 'M54B25',   'coupe',       'PETROL'),
    (2003::smallint, '330i', 'M54B30',   'sedan',       'PETROL'),
    (2004::smallint, '330i', 'M54B30',   'convertible', 'PETROL'),
    (2000::smallint, '320d', 'M47D20',   'sedan',       'DIESEL'),
    (2004::smallint, '320d', 'M47TUD20', 'sedan',       'DIESEL'),
    (2004::smallint, '320d', 'M47TUD20', 'wagon',       'DIESEL'),
    (2004::smallint, '320d', 'M47TUD20', 'hatchback',   'DIESEL'),
    (2002::smallint, '330d', 'M57D30',   'sedan',       'DIESEL'),
    (2004::smallint, '330d', 'M57TUD30', 'sedan',       'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '3-series' AND g.slug = 'e46'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- ============================================================
-- E90/E91/E92/E93 (2005-2011) — sedan / wagon / coupe / convertible
-- ============================================================
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-3-series', 'auto-tech-bmw-3-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2006::smallint, '320i', 'N46B20',   'sedan',       'PETROL'),
    (2009::smallint, '318i', 'N43B20',   'sedan',       'PETROL'),
    (2009::smallint, '320i', 'N43B20',   'sedan',       'PETROL'),
    (2009::smallint, '320i', 'N43B20',   'wagon',       'PETROL'),
    (2007::smallint, '325i', 'N52B25',   'sedan',       'PETROL'),
    (2010::smallint, '325i', 'N53B30',   'sedan',       'PETROL'),
    (2007::smallint, '330i', 'N52B30',   'coupe',       'PETROL'),
    (2008::smallint, '335i', 'N54B30',   'coupe',       'PETROL'),
    (2007::smallint, '320d', 'M47D20TU2','sedan',       'DIESEL'),
    (2009::smallint, '320d', 'N47D20',   'sedan',       'DIESEL'),
    (2010::smallint, '320d', 'N47D20',   'wagon',       'DIESEL'),
    (2010::smallint, '318d', 'N47D20',   'sedan',       'DIESEL'),
    (2007::smallint, '330d', 'M57D30TU2','sedan',       'DIESEL'),
    (2010::smallint, '330d', 'N57D30',   'sedan',       'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '3-series' AND g.slug = 'e90'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- ============================================================
-- F30/F31/F32/F33/F34 (2012-2019) — sedan / wagon / coupe / convertible / GT
-- The pre-existing 2016 320i B48B20 sedan row is in the VALUES list and will
-- be absorbed by ON CONFLICT (generation_id, year, trim, engine_code).
-- ============================================================
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-3-series', 'auto-tech-bmw-3-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2014::smallint, '316i', 'N13B16',    'sedan',         'PETROL'),
    (2014::smallint, '320i', 'N20B20',    'sedan',         'PETROL'),
    (2014::smallint, '320i', 'N20B20',    'wagon',         'PETROL'),
    (2014::smallint, '320i', 'N20B20',    'gran-turismo',  'PETROL'),
    (2016::smallint, '320i', 'B48B20',    'sedan',         'PETROL'),  -- already seeded; ON CONFLICT skips
    (2017::smallint, '320i', 'B48B20',    'wagon',         'PETROL'),
    (2017::smallint, '330i', 'B48B20',    'sedan',         'PETROL'),
    (2017::smallint, '340i', 'B58B30M0',  'sedan',         'PETROL'),
    (2013::smallint, '316d', 'N47D20',    'sedan',         'DIESEL'),
    (2014::smallint, '318d', 'N47D20',    'sedan',         'DIESEL'),
    (2014::smallint, '320d', 'N47D20',    'sedan',         'DIESEL'),
    (2014::smallint, '320d', 'N47D20',    'wagon',         'DIESEL'),
    (2016::smallint, '320d', 'B47D20',    'sedan',         'DIESEL'),
    (2017::smallint, '320d', 'B47D20',    'wagon',         'DIESEL'),
    (2017::smallint, '320d', 'B47D20',    'gran-turismo',  'DIESEL'),
    (2017::smallint, '330d', 'N57D30',    'sedan',         'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '3-series' AND g.slug = 'f30'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- ============================================================
-- G20/G21 (2019-2024) — sedan + wagon, M variants excluded
-- ============================================================
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-3-series', 'auto-tech-bmw-3-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2020::smallint, '318i', 'B48B20', 'sedan', 'PETROL'),
    (2020::smallint, '320i', 'B48B20', 'sedan', 'PETROL'),
    (2021::smallint, '320i', 'B48B20', 'wagon', 'PETROL'),
    (2020::smallint, '330i', 'B48B20', 'sedan', 'PETROL'),
    (2021::smallint, '330i', 'B48B20', 'wagon', 'PETROL'),
    (2020::smallint, '318d', 'B47D20', 'sedan', 'DIESEL'),
    (2020::smallint, '320d', 'B47D20', 'sedan', 'DIESEL'),
    (2021::smallint, '320d', 'B47D20', 'wagon', 'DIESEL'),
    (2020::smallint, '330d', 'B57D30', 'sedan', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '3-series' AND g.slug = 'g20'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

COMMIT;

-- Verification
SELECT g.code, COUNT(vv.*) AS variants
  FROM vehicle_generations g
  LEFT JOIN vehicle_variants vv ON vv.generation_id = g.id
 WHERE g.model_id = (
       SELECT m.id FROM vehicle_models m
         JOIN vehicle_makes mk ON mk.id = m.make_id
        WHERE mk.slug = 'bmw' AND m.slug = '3-series')
 GROUP BY g.code, g.year_from
 ORDER BY g.year_from;
SQL
