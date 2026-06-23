#!/usr/bin/env bash
# Seed representative BMW 5 Series variants for E34, E39, E60, F10, G30, G60.
#
# Market: European / CIS (Azerbaijan primary). M5 excluded.
#
# Requires:
#   - autoparts-postgres container running
#   - seed-bmw-generations.sh already run (the 6 generations must exist)
#
# Idempotent: ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING.
#
# Sources cited per generation (full list inline below):
#   E34: Wikipedia BMW_5_Series_(E34) + bimmerarchive.org/e-code/e34.html
#   E39: Wikipedia BMW_5_Series_(E39) + auto-data.net
#   E60: Wikipedia BMW_5_Series_(E60) + bimmerarchive N53
#   F10: Wikipedia BMW_5_Series_(F10) + bimmerarchive N57 (no B57 mid-F10)
#   G30: Wikipedia BMW_5_Series_(G30)
#   G60: Wikipedia BMW_5_Series_(G60)
#
# Run:  ./scripts/seed-bmw-5-series-variants.sh

set -euo pipefail

CONTAINER="${CONTAINER:-autoparts-postgres}"

docker exec -i "$CONTAINER" psql -U autoparts -d autoparts -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- E34 (1988-1996) — sedan + wagon. M5 excluded.
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-5-series', 'auto-tech-bmw-5-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (1991::smallint, '520i',   'M50B20',    'sedan', 'PETROL'),
    (1994::smallint, '520i',   'M50B20TU',  'sedan', 'PETROL'),
    (1995::smallint, '525i',   'M50B25TU',  'sedan', 'PETROL'),
    (1995::smallint, '525i',   'M50B25TU',  'wagon', 'PETROL'),
    (1994::smallint, '530i',   'M60B30',    'sedan', 'PETROL'),
    (1994::smallint, '540i',   'M60B40',    'sedan', 'PETROL'),
    (1994::smallint, '525tds', 'M51D25',    'sedan', 'DIESEL'),
    (1995::smallint, '525tds', 'M51D25',    'wagon', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '5-series' AND g.slug = 'e34'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- E39 (1995-2004) — sedan + wagon. M5 excluded.
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-5-series', 'auto-tech-bmw-5-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (1997::smallint, '520i',  'M52B20',    'sedan', 'PETROL'),
    (1999::smallint, '520i',  'M52TUB20',  'sedan', 'PETROL'),
    (2002::smallint, '520i',  'M54B22',    'sedan', 'PETROL'),
    (1999::smallint, '523i',  'M52TUB25',  'sedan', 'PETROL'),
    (2001::smallint, '525i',  'M54B25',    'sedan', 'PETROL'),
    (2002::smallint, '530i',  'M54B30',    'sedan', 'PETROL'),
    (2002::smallint, '530i',  'M54B30',    'wagon', 'PETROL'),
    (2001::smallint, '540i',  'M62TUB44',  'sedan', 'PETROL'),
    (2001::smallint, '520d',  'M47D20',    'sedan', 'DIESEL'),
    (2002::smallint, '525d',  'M57D25',    'sedan', 'DIESEL'),
    (2000::smallint, '530d',  'M57D30',    'sedan', 'DIESEL'),
    (2002::smallint, '530d',  'M57D30',    'wagon', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '5-series' AND g.slug = 'e39'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- E60/E61 (2003-2010) — sedan + wagon. M5 excluded.
-- 2007 LCI transitions: M54→N52/N53 petrol, M47→N47 diesel, M57TU→M57TU2.
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-5-series', 'auto-tech-bmw-5-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2004::smallint, '520i',  'M54B22',     'sedan', 'PETROL'),
    (2008::smallint, '520i',  'N43B20',     'sedan', 'PETROL'),
    (2004::smallint, '525i',  'M54B25',     'sedan', 'PETROL'),
    (2006::smallint, '525i',  'N52B25',     'sedan', 'PETROL'),
    (2008::smallint, '525i',  'N53B30',     'sedan', 'PETROL'),
    (2009::smallint, '528i',  'N52B30',     'sedan', 'PETROL'),
    (2004::smallint, '530i',  'M54B30',     'sedan', 'PETROL'),
    (2008::smallint, '530i',  'N53B30',     'sedan', 'PETROL'),
    (2008::smallint, '530i',  'N53B30',     'wagon', 'PETROL'),
    (2008::smallint, '550i',  'N62B48',     'sedan', 'PETROL'),
    (2006::smallint, '520d',  'M47TU2D20',  'sedan', 'DIESEL'),
    (2009::smallint, '520d',  'N47D20',     'sedan', 'DIESEL'),
    (2009::smallint, '520d',  'N47D20',     'wagon', 'DIESEL'),
    (2005::smallint, '525d',  'M57D25TU',   'sedan', 'DIESEL'),
    (2008::smallint, '525d',  'M57D30TU2',  'sedan', 'DIESEL'),
    (2005::smallint, '530d',  'M57D30TU',   'sedan', 'DIESEL'),
    (2008::smallint, '530d',  'M57D30TU2',  'sedan', 'DIESEL'),
    (2008::smallint, '530d',  'M57D30TU2',  'wagon', 'DIESEL'),
    (2008::smallint, '535d',  'M57D30TU2',  'sedan', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '5-series' AND g.slug = 'e60'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- F10/F11 (2010-2017) — sedan + wagon. M5 excluded.
-- 2014 LCI: N47→B47 (4-cyl diesel), N20→B48 enters in 2015 for some 520i.
-- 530d stayed on N57D30A through the entire F10 run (no B57 in F10).
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-5-series', 'auto-tech-bmw-5-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2012::smallint, '520i',  'N20B20',    'sedan', 'PETROL'),
    (2015::smallint, '520i',  'N20B20',    'sedan', 'PETROL'),
    (2011::smallint, '523i',  'N53B30',    'sedan', 'PETROL'),
    (2012::smallint, '528i',  'N20B20',    'sedan', 'PETROL'),
    (2012::smallint, '535i',  'N55B30',    'sedan', 'PETROL'),
    (2013::smallint, '550i',  'N63B44',    'sedan', 'PETROL'),
    (2013::smallint, '518d',  'N47D20',    'sedan', 'DIESEL'),
    (2015::smallint, '518d',  'B47D20',    'sedan', 'DIESEL'),
    (2012::smallint, '520d',  'N47D20',    'sedan', 'DIESEL'),
    (2012::smallint, '520d',  'N47D20',    'wagon', 'DIESEL'),
    (2015::smallint, '520d',  'B47D20',    'sedan', 'DIESEL'),
    (2016::smallint, '520d',  'B47D20',    'wagon', 'DIESEL'),
    (2013::smallint, '525d',  'N47D20',    'sedan', 'DIESEL'),
    (2012::smallint, '530d',  'N57D30',    'sedan', 'DIESEL'),
    (2015::smallint, '530d',  'N57D30',    'sedan', 'DIESEL'),
    (2014::smallint, '535d',  'N57D30',    'sedan', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '5-series' AND g.slug = 'f10'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- G30/G31 (2017-2023) — sedan + wagon. M5 excluded.
-- Full B-engine family.
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-5-series', 'auto-tech-bmw-5-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2018::smallint, '520i',  'B48B20',  'sedan', 'PETROL'),
    (2019::smallint, '520i',  'B48B20',  'wagon', 'PETROL'),
    (2018::smallint, '530i',  'B48B20',  'sedan', 'PETROL'),
    (2020::smallint, '530i',  'B48B20',  'sedan', 'PETROL'),
    (2018::smallint, '540i',  'B58B30',  'sedan', 'PETROL'),
    (2019::smallint, '530e',  'B48B20',  'sedan', 'HYBRID'),
    (2018::smallint, '518d',  'B47D20',  'sedan', 'DIESEL'),
    (2018::smallint, '520d',  'B47D20',  'sedan', 'DIESEL'),
    (2019::smallint, '520d',  'B47D20',  'wagon', 'DIESEL'),
    (2018::smallint, '530d',  'B57D30',  'sedan', 'DIESEL'),
    (2021::smallint, '530d',  'B57D30',  'sedan', 'DIESEL'),
    (2018::smallint, '540d',  'B57D30',  'sedan', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '5-series' AND g.slug = 'g30'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- G60/G61 (2024-present) — sedan (G61 wagon TBC for CIS).
-- All ICE variants 48V mild-hybrid; PHEV shares B48/B58.
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, v.body_type, v.fuel,
       'auto-tech-bmw-5-series', 'auto-tech-bmw-5-series'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    (2024::smallint, '520i',         'B48B20',  'sedan', 'PETROL'),
    (2024::smallint, '530i',         'B48B20',  'sedan', 'PETROL'),
    (2025::smallint, '530i xDrive',  'B48B20',  'sedan', 'PETROL'),
    (2024::smallint, '540i xDrive',  'B58B30',  'sedan', 'PETROL'),
    (2024::smallint, '530e',         'B48B20',  'sedan', 'HYBRID'),
    (2024::smallint, '520d',         'B47D20',  'sedan', 'DIESEL'),
    (2024::smallint, '540d xDrive',  'B57D30',  'sedan', 'DIESEL')
 ) AS v(year, trim, engine_code, body_type, fuel)
 WHERE mk.slug = 'bmw' AND m.slug = '5-series' AND g.slug = 'g60'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

COMMIT;

-- Verification
SELECT g.code, COUNT(vv.*) AS variants
  FROM vehicle_generations g
  LEFT JOIN vehicle_variants vv ON vv.generation_id = g.id
 WHERE g.model_id = (
       SELECT m.id FROM vehicle_models m
         JOIN vehicle_makes mk ON mk.id = m.make_id
        WHERE mk.slug = 'bmw' AND m.slug = '5-series')
 GROUP BY g.code, g.year_from
 ORDER BY g.year_from;
SQL
