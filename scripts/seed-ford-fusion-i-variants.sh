#!/usr/bin/env bash
# Seed US-market Ford Fusion first generation (CD338, MY2006-2012, sedan only),
# and apply one correction to the second generation (CD391) for MY2020.
#
# Market: US only. FWD/AWD is not part of the key (SEL FWD 3.0 and SEL AWD 3.0
# collapse into one row). Flex-fuel 3.0 V6 (2010-2012) is stored as PETROL
# because the fuel enum has no FLEX value.
#
# What this does:
#   1. Inserts the generation row ford/fusion 'cd338' (code CD338, name
#      'Fusion I (CD338)', 2006-2012) if it does not exist yet. The existing
#      CD391 row keeps slug 'gen'.
#   2. Moves vehicle_models.year_from for ford/fusion back to 2006.
#   3. Inserts one vehicle_variants row per (model year, trim, engine) that was
#      actually sold: 41 rows (5 per year 2006-2009, 7 per year 2010-2012).
#   4. CD391 MY2020 correction: inserts SE + 1.5 EcoBoost (left out of the
#      CD391 seed as unverified; since confirmed by real VINs). SEL + 2.0 EcoBoost
#      AWD was the other open row and is NOT sold in MY2020, so nothing to add.
#   Every statement is idempotent; a re-run changes 0 rows.
#
# Sources (per claim):
#   Platform code CD338 on the Ford CD3 platform, MY2006-2012, 2010 facelift:
#     https://en.wikipedia.org/wiki/Ford_CD3_platform ("2006-2012 Ford Fusion (CD338)")
#     https://autocade.net/index.php/Ford_Fusion_(CD338)
#     https://en.wikipedia.org/wiki/Ford_Fusion_(Americas)
#   Engine x model-year availability (US EPA, all 42 entries 2006-2012):
#     https://www.fueleconomy.gov/feg/PowerSearch.do?action=noform&path=1&year1=2006&year2=2012&make=Ford&baseModel=Fusion&srchtyp=ymm&rowLimit=50
#       2006-2009: 2.3 I4, 3.0 V6 (AWD from 2007, V6 only)
#       2010-2012: 2.5 I4, 3.0 V6 FFV (FWD+AWD), 3.5 V6 (FWD+AWD), 2.5 Hybrid
#   Trim x engine per year:
#     https://www.cars.com/research/ford-fusion-<year>/trims/ for 2006..2012
#     https://www.cars.com/research/ford-fusion_hybrid-<year>/trims/ for 2010..2012
#       (one style per year, "4dr Sdn Hybrid FWD" -> trim 'Hybrid', no sub-trims)
#     https://www.motorweek.org/reviews/road_tests/2006_ford_fusion
#       ("All models come standard with ... 2.3 liter"; V6 "Optional on the SE and SEL")
#     https://www.thetruthaboutcars.com/2008/11/2010-ford-fusion-pricing-announced/
#     https://www.topspeed.com/cars/ford/2010-ford-fusion-ar67130.html
#     https://autotk.com/ford/fusion/2011
#   Optional engines that cars.com does not list as their own style (SE + 3.0 V6
#   in 2010-2012) are backed by real VINs with valid check digits decoded with
#   NHTSA vPIC (https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/<VIN>?format=json):
#     2010 SE 3.0: 3FAHP0HG2AR201325 (https://fleetchaser.com/vin/2010/ford/fusion/3FAHP0HG2AR201325/), 3FAHP0HG2AR326308
#     2011 SE 3.0: 3FAHP0HG5BR296741 (https://vincheck.it.com/auctions/lot/45676306)
#     2012 SE 3.0: https://truevin.com/vin/ford/fusion/2012/3FAHP0HG3CR (27 VINs), 3FAHP0HGXCR192554
#   Engine naming: the 2010-2012 2.5 is "Duratec 25" (Ford 2010 tech specs mirror,
#   https://ophelia.sdsu.edu:8443/ford/03-03-2012/news-center/press-releases-detail/pr-2010-fusion-technical-29453.html)
#   = Mazda L5-VE with iVCT, the same family as the CD391 2.5
#   (https://en.wikipedia.org/wiki/Mazda_L_engine), so it is stored under the
#   same name '2.5 Duratec iVCT' for consistent engine lookups. Same engine_code
#   across generations does NOT imply shared parts: fitments are per variant.
#   MY2020 CD391 correction:
#     SE + 1.5 EcoBoost sold: real VINs decoded by vPIC as SE / 1.5 / FWD
#       3FA6P0HD3LR106563, 3FA6P0HD7LR149383, 3FA6P0HD1LR167930, 3FA6P0HD7LR246311;
#       https://en.wikipedia.org/wiki/Ford_Fusion_(Americas) lists the 1.5 on SE
#     SEL + 2.0 EcoBoost AWD not sold: NHTSA's MY2020 VIN schema has no SEL AWD
#       series code (2019 had E = SEL AWD); https://www.cars.com/research/ford-fusion-2020/trims/
#       lists SEL FWD 1.5 only.
#
# Deliberately LEFT OUT (no source, or sources say not sold):
#   -- S + 3.0 V6, any year (cars.com 2006-2009 lists S as I4 only; V6 optional on SE/SEL)
#   -- SEL + 3.5 V6, 2010-2012 (3.5 is Sport only in every source)
#   -- 3.5 V6 before 2010 (EPA shows none)
#   -- 2020 SEL + 2.0 EcoBoost FWD (exists in the VIN schema, no source shows it sold)
#
# NOTE: no Ford-published brochure / order guide could be read (media.ford.com
# redirects; Edmunds, KBB, JD Power returned 403). Pairings rest on the
# secondary sources above, cross-checked against EPA engine-by-year data and
# real VIN decodes.
#
# Requires: autoparts-postgres container running; ford/fusion model present.
#
# Run:  ./scripts/seed-ford-fusion-i-variants.sh
#       CONTAINER=autoparts-postgres ./scripts/seed-ford-fusion-i-variants.sh
# Prod: print the heredoc body and run it from a DB client (seed-only change, no VM rebuild):
#   awk '/^docker exec/{f=1;next} /^SQL$/{f=0} f' scripts/seed-ford-fusion-i-variants.sh > ~/Downloads/seed-ford-fusion-i-variants.sql

set -euo pipefail

CONTAINER="${CONTAINER:-autoparts-postgres}"

docker exec -i "$CONTAINER" psql -U autoparts -d autoparts -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- ============================================================
-- Generation: CD338 (MY2006-2012), slug 'cd338'.
-- ============================================================
INSERT INTO vehicle_generations (model_id, code, name, slug, year_from, year_to, created_by, updated_by)
SELECT m.id, 'CD338', 'Fusion I (CD338)', 'cd338', 2006, 2012,
       'seed-ford-fusion-i-variants', 'seed-ford-fusion-i-variants'
  FROM vehicle_models m
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 WHERE mk.slug = 'ford' AND m.slug = 'fusion'
ON CONFLICT (model_id, slug) DO NOTHING;

-- The model now starts in 2006.
UPDATE vehicle_models m
   SET year_from = 2006, updated_at = now(), updated_by = 'seed-ford-fusion-i-variants'
  FROM vehicle_makes mk
 WHERE m.make_id = mk.id AND mk.slug = 'ford' AND m.slug = 'fusion'
   AND m.year_from > 2006;

-- ============================================================
-- Variants (US model years). Sedan only. 41 rows.
-- ============================================================
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, 'sedan', v.fuel,
       'seed-ford-fusion-i-variants', 'seed-ford-fusion-i-variants'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    -- 2006-2009: 2.3 Duratec I4 on every trim, 3.0 Duratec V6 optional on SE and SEL
    (2006::smallint, 'S',      '2.3 Duratec',       'PETROL'),
    (2006::smallint, 'SE',     '2.3 Duratec',       'PETROL'),
    (2006::smallint, 'SE',     '3.0 Duratec V6',    'PETROL'),
    (2006::smallint, 'SEL',    '2.3 Duratec',       'PETROL'),
    (2006::smallint, 'SEL',    '3.0 Duratec V6',    'PETROL'),

    (2007::smallint, 'S',      '2.3 Duratec',       'PETROL'),
    (2007::smallint, 'SE',     '2.3 Duratec',       'PETROL'),
    (2007::smallint, 'SE',     '3.0 Duratec V6',    'PETROL'),
    (2007::smallint, 'SEL',    '2.3 Duratec',       'PETROL'),
    (2007::smallint, 'SEL',    '3.0 Duratec V6',    'PETROL'),

    (2008::smallint, 'S',      '2.3 Duratec',       'PETROL'),
    (2008::smallint, 'SE',     '2.3 Duratec',       'PETROL'),
    (2008::smallint, 'SE',     '3.0 Duratec V6',    'PETROL'),
    (2008::smallint, 'SEL',    '2.3 Duratec',       'PETROL'),
    (2008::smallint, 'SEL',    '3.0 Duratec V6',    'PETROL'),

    (2009::smallint, 'S',      '2.3 Duratec',       'PETROL'),
    (2009::smallint, 'SE',     '2.3 Duratec',       'PETROL'),
    (2009::smallint, 'SE',     '3.0 Duratec V6',    'PETROL'),
    (2009::smallint, 'SEL',    '2.3 Duratec',       'PETROL'),
    (2009::smallint, 'SEL',    '3.0 Duratec V6',    'PETROL'),

    -- 2010-2012 facelift: 2.5 I4, 3.0 V6 FFV (SE/SEL), 3.5 V6 (Sport), Hybrid
    (2010::smallint, 'S',      '2.5 Duratec iVCT',  'PETROL'),
    (2010::smallint, 'SE',     '2.5 Duratec iVCT',  'PETROL'),
    (2010::smallint, 'SE',     '3.0 Duratec V6',    'PETROL'),
    (2010::smallint, 'SEL',    '2.5 Duratec iVCT',  'PETROL'),
    (2010::smallint, 'SEL',    '3.0 Duratec V6',    'PETROL'),
    (2010::smallint, 'Sport',  '3.5 Duratec V6',    'PETROL'),
    (2010::smallint, 'Hybrid', '2.5 Atkinson HEV',  'HYBRID'),

    (2011::smallint, 'S',      '2.5 Duratec iVCT',  'PETROL'),
    (2011::smallint, 'SE',     '2.5 Duratec iVCT',  'PETROL'),
    (2011::smallint, 'SE',     '3.0 Duratec V6',    'PETROL'),
    (2011::smallint, 'SEL',    '2.5 Duratec iVCT',  'PETROL'),
    (2011::smallint, 'SEL',    '3.0 Duratec V6',    'PETROL'),
    (2011::smallint, 'Sport',  '3.5 Duratec V6',    'PETROL'),
    (2011::smallint, 'Hybrid', '2.5 Atkinson HEV',  'HYBRID'),

    (2012::smallint, 'S',      '2.5 Duratec iVCT',  'PETROL'),
    (2012::smallint, 'SE',     '2.5 Duratec iVCT',  'PETROL'),
    (2012::smallint, 'SE',     '3.0 Duratec V6',    'PETROL'),
    (2012::smallint, 'SEL',    '2.5 Duratec iVCT',  'PETROL'),
    (2012::smallint, 'SEL',    '3.0 Duratec V6',    'PETROL'),
    (2012::smallint, 'Sport',  '3.5 Duratec V6',    'PETROL'),
    (2012::smallint, 'Hybrid', '2.5 Atkinson HEV',  'HYBRID')
 ) AS v(year, trim, engine_code, fuel)
 WHERE mk.slug = 'ford' AND m.slug = 'fusion' AND g.slug = 'cd338'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

-- ============================================================
-- CD391 MY2020 correction: SE + 1.5 EcoBoost was sold.
-- ============================================================
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, 2020, 'SE', '1.5 EcoBoost', 'sedan', 'PETROL',
       'seed-ford-fusion-i-variants', 'seed-ford-fusion-i-variants'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 WHERE mk.slug = 'ford' AND m.slug = 'fusion' AND g.code = 'CD391'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

COMMIT;

-- ============================================================
-- Verify
-- ============================================================
SELECT g.slug, g.code, g.name, g.year_from, g.year_to, m.year_from AS model_from, m.year_to AS model_to
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id  = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 WHERE mk.slug = 'ford' AND m.slug = 'fusion'
 ORDER BY g.year_from;

SELECT g.code, vv.year, COUNT(*) AS variants,
       string_agg(DISTINCT vv.engine_code, ', ' ORDER BY vv.engine_code) AS engines
  FROM vehicle_variants vv
  JOIN vehicle_generations g ON g.id = vv.generation_id
  JOIN vehicle_models m  ON m.id  = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 WHERE mk.slug = 'ford' AND m.slug = 'fusion' AND (g.slug = 'cd338' OR vv.year = 2020)
 GROUP BY g.code, vv.year
 ORDER BY vv.year;
SQL
