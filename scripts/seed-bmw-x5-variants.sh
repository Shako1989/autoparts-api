#!/usr/bin/env bash
# Seed representative BMW X5 variants for E53, E70, F15, G05.
#
# Market: European / CIS (Azerbaijan primary). X5 M / M50d excluded.
#
# Requires:
#   - autoparts-postgres container running
#   - seed-bmw-generations.sh already run (the 4 generations must exist)
#
# Idempotent: ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING.
# The pre-existing 2018 xDrive40i B58B30 SUV PETROL row under G05 is the first
# tuple in the G05 block and is absorbed by ON CONFLICT.
#
# Sources cited per generation:
#   E53: Wikipedia BMW_X5_(E53) + bimmerarchive.org/e-code/e53.html
#   E70: Wikipedia BMW_X5_(E70) + auto-data.net
#   F15: Wikipedia BMW_X5_(F15)
#   G05: Wikipedia BMW_X5_(G05)
#
# Run:  ./scripts/seed-bmw-x5-variants.sh

set -euo pipefail

CONTAINER="${CONTAINER:-autoparts-postgres}"

docker exec -i "$CONTAINER" psql -U autoparts -d autoparts -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- E53 (1999-2006) — SUV only. Pre-xDrive naming.
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-x5', 'auto-tech-bmw-x5'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2002::smallint, '3.0i',  'M54B30',     'SUV', 'PETROL'),
    (2005::smallint, '3.0i',  'M54B30',     'SUV', 'PETROL'),
    (2002::smallint, '4.4i',  'M62B44TU',   'SUV', 'PETROL'),
    (2005::smallint, '4.4i',  'N62B44',     'SUV', 'PETROL'),
    (2005::smallint, '4.8is', 'N62B48',     'SUV', 'PETROL'),
    (2002::smallint, '3.0d',  'M57D30',     'SUV', 'DIESEL'),
    (2005::smallint, '3.0d',  'M57TUD30',   'SUV', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = 'x5' AND g.slug = 'e53'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- E70 (2006-2013) — SUV only. 2010 LCI: N62→N63 V8, M57→N57 I6 diesel, N52→N55.
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-x5', 'auto-tech-bmw-x5'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2008::smallint, 'xDrive30i',  'N52B30',     'SUV', 'PETROL'),
    (2011::smallint, 'xDrive35i',  'N55B30',     'SUV', 'PETROL'),
    (2009::smallint, 'xDrive48i',  'N62B48',     'SUV', 'PETROL'),
    (2012::smallint, 'xDrive50i',  'N63B44',     'SUV', 'PETROL'),
    (2008::smallint, 'xDrive30d',  'M57TU2D30',  'SUV', 'DIESEL'),
    (2012::smallint, 'xDrive30d',  'N57D30',     'SUV', 'DIESEL'),
    (2011::smallint, 'xDrive40d',  'N57D30',     'SUV', 'DIESEL'),
    (2010::smallint, 'xDrive35d',  'M57TU2D30',  'SUV', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = 'x5' AND g.slug = 'e70'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- F15 (2013-2018) — SUV only. 2015 LCI: N47→B47 for 25d.
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-x5', 'auto-tech-bmw-x5'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2015::smallint, 'xDrive35i',  'N55B30',  'SUV', 'PETROL'),
    (2015::smallint, 'xDrive50i',  'N63B44',  'SUV', 'PETROL'),
    (2016::smallint, 'xDrive40e',  'N20B20',  'SUV', 'HYBRID'),
    (2014::smallint, 'xDrive25d',  'N47D20',  'SUV', 'DIESEL'),
    (2017::smallint, 'xDrive25d',  'B47D20',  'SUV', 'DIESEL'),
    (2014::smallint, 'xDrive30d',  'N57D30',  'SUV', 'DIESEL'),
    (2014::smallint, 'xDrive40d',  'N57D30',  'SUV', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = 'x5' AND g.slug = 'f15'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- G05 (2018-2024) — SUV only. The pre-existing 2018 xDrive40i B58B30 row is
-- the first tuple here; ON CONFLICT absorbs it.
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-x5', 'auto-tech-bmw-x5'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2018::smallint, 'xDrive40i',  'B58B30',  'SUV', 'PETROL'),  -- already seeded; ON CONFLICT skips
    (2020::smallint, 'xDrive40i',  'B58B30',  'SUV', 'PETROL'),
    (2019::smallint, 'xDrive50i',  'N63B44',  'SUV', 'PETROL'),
    (2020::smallint, 'xDrive45e',  'B58B30',  'SUV', 'HYBRID'),
    (2019::smallint, 'xDrive25d',  'B47D20',  'SUV', 'DIESEL'),
    (2019::smallint, 'xDrive30d',  'B57D30',  'SUV', 'DIESEL'),
    (2021::smallint, 'xDrive30d',  'B57D30',  'SUV', 'DIESEL'),
    (2019::smallint, 'xDrive40d',  'B57D30',  'SUV', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = 'x5' AND g.slug = 'g05'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

COMMIT;

-- Verification
SELECT g.code, COUNT(vv.*) AS variants
  FROM vehicle_generations g
  LEFT JOIN vehicle_variants vv ON vv.generation_id = g.id
 WHERE g.model_id = (
       SELECT m.id FROM vehicle_models m
         JOIN vehicle_makes mk ON mk.id = m.make_id
        WHERE mk.slug = 'bmw' AND m.slug = 'x5')
 GROUP BY g.code, g.year_from
 ORDER BY g.year_from;
SQL
