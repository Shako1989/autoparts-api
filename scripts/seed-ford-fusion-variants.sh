#!/usr/bin/env bash
# Seed US-market Ford Fusion second generation (CD391, MY2013-2020, sedan only).
#
# Market: US (NOT European/CIS). The CD391 car was sold in Europe/CIS as the
# Mondeo Mk V with a different engine line-up; those variants are out of scope here.
#
# What this does:
#   1. Updates the existing ford/fusion generation row (slug 'gen', kept so
#      existing links keep working) to code 'CD391', name 'Fusion II (CD391)',
#      years 2013-2020. Guarded so a re-run updates 0 rows.
#   2. Inserts one vehicle_variants row per (model year, trim, engine) that
#      actually existed. FWD/AWD is not part of the key, so SE FWD 2.0 and
#      SE AWD 2.0 collapse into one row.
#
# Sources (per claim):
#   Platform code CD391 = Fusion (Americas) / Mondeo Mk V:
#     https://en.wikipedia.org/wiki/Ford_Mondeo_(fourth_generation)
#       ("Developed under the model code CD391, it is a rebadged variant of the
#        American-market Fusion")
#   Generation MY2013-2020, engine power, Sport 2017-2019, Platinum 2017-2018,
#   SEL replacing SE Luxury package for 2019, Energi Titanium-only 2019-2020:
#     https://en.wikipedia.org/wiki/Ford_Fusion_(Americas)
#   Engine x model-year availability (authoritative, US EPA):
#     https://www.fueleconomy.gov/feg/PowerSearch.do?action=noform&path=1&year1=2013&year2=2020&make=Ford&baseModel=Fusion&srchtyp=ymm
#       1.6 turbo: 2013 (MT+AT), 2014 (MT only)  | 1.5 turbo: 2014-2020
#       2.0 turbo: 2013-2020 (FWD+AWD)          | 2.5 NA: 2013-2020
#       2.7 turbo V6: 2017-2019 (AWD)            | 2.0 hybrid + 2.0 PHEV: 2013-2020
#   Hybrid/Energi use the 2.0 Atkinson-cycle I4:
#     https://www.greencarreports.com/news/1071789_2013-ford-fusion-high-mpg-engines-hybrid-plug-in-video
#   Trim x engine, 2013:
#     https://www.torquenews.com/106/official-pricing-2013-ford-fusion-comes-online-starting-22495
#     https://consumerguide.com/used/2013-15-ford-fusion/
#     https://www.cars.com/research/ford-fusion-2013/trims/ (+ ford-fusion_hybrid-2013, ford-fusion_energi-2013)
#   Trim x engine, 2014 (Hybrid S added, 1.5 EB added, 1.6 EB manual only):
#     https://www.cars.com/articles/2014-ford-fusion-whats-changed-1420663051662
#     https://consumerguide.com/used/2013-15-ford-fusion/
#   Trim x engine, 2015-2016 (1.6/manual dropped, SE AWD with 2.0 EB added):
#     https://www.autoguide.com/auto-news/2014/07/2015-ford-fusion-gets-small-updates-drops-manual.html
#     https://www.cars.com/research/ford-fusion-2015/trims/ , .../ford-fusion-2016/trims/
#   Trim x engine, 2017-2018 (Platinum, Sport added):
#     https://www.cars.com/research/ford-fusion-2017/trims/ , .../ford-fusion-2018/trims/
#     https://www.cars.com/research/ford-fusion_hybrid-2017/trims/ , ford-fusion_energi-2017 (and -2018)
#     https://www.digitaltrends.com/cars/2018-ford-fusion-release-date-price-specs-news/
#     https://consumerguide.com/ford/2018-fusion/
#   Trim x engine, 2019 (SEL added, Platinum dropped, Energi Titanium only):
#     https://www.cars.com/research/ford-fusion-2019/trims/ (+ _hybrid-2019, _energi-2019)
#     https://www.autoblog.com/buy/2019-Ford-Fusion/review/ (SEL FWD 1.5, SEL AWD 2.0)
#     https://consumerguide.com/ford/2019-fusion/
#   Trim x engine, 2020 (Sport dropped):
#     https://www.cars.com/research/ford-fusion-2020/trims/ (S 2.5, SE FWD 2.5, SE AWD 2.0,
#       SEL FWD 1.5, Titanium FWD/AWD 2.0) (+ _hybrid-2020, _energi-2020)
#
# NOTE: no Ford-published brochure / order guide could be read for any year
# (media.ford.com now redirects; brochure PDFs were image-only or blocked).
# Trim x engine pairings rest on the secondary sources above, cross-checked
# against EPA engine-by-year data. Ford internal engine codes are NOT appended
# because none could be cited.
#
# Settled later (2026-11-09, see scripts/seed-ford-fusion-i-variants.sh for sources):
#   -- 2020 SE  1.5 EcoBoost       SOLD: real VINs decode as SE / 1.5 / FWD; row added below
#   -- 2020 SEL 2.0 EcoBoost (AWD) NOT SOLD: MY2020 VIN schema has no SEL AWD code
#
# Deliberately LEFT OUT (could not verify, < 90% confidence):
#   -- 2013-2014 SE AWD            (Canada-only per auto123/autos.ca; engine row
#                                   SE 2.0 EcoBoost exists anyway as FWD)
#   -- 2019 Hybrid S, 2019 Energi SEL (conflicting sources)
#
# Trim naming: Energi SE is labelled 'SE Energi' (cars.com: "SE"; Ford marketed
# it as "SE Luxury" - unconfirmed). The 2019 Sport was marketed "V6 Sport"; it
# is stored as 'Sport' in every year for consistent fitment lookups.
#
# Requires: autoparts-postgres container running; ford/fusion model with a
# generation row (slug 'gen' or already 'gen' renamed to CD391).
#
# Run:  ./scripts/seed-ford-fusion-variants.sh
#       CONTAINER=autoparts-postgres ./scripts/seed-ford-fusion-variants.sh

set -euo pipefail

CONTAINER="${CONTAINER:-autoparts-postgres}"

docker exec -i "$CONTAINER" psql -U autoparts -d autoparts -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- ============================================================
-- Generation: CD391 (MY2013-2020). Slug stays 'gen'.
-- ============================================================
UPDATE vehicle_generations g
   SET code = 'CD391', name = 'Fusion II (CD391)',
       year_from = 2013, year_to = 2020,
       updated_at = now(), updated_by = 'seed-ford-fusion-variants'
  FROM vehicle_models m, vehicle_makes mk
 WHERE g.model_id = m.id AND m.slug = 'fusion'
   AND m.make_id = mk.id AND mk.slug = 'ford'
   AND g.slug = 'gen'
   AND (g.code IS DISTINCT FROM 'CD391'
        OR g.name IS DISTINCT FROM 'Fusion II (CD391)'
        OR g.year_from IS DISTINCT FROM 2013
        OR g.year_to IS DISTINCT FROM 2020);

-- ============================================================
-- Variants (US model years). Sedan only.
-- ============================================================
INSERT INTO vehicle_variants (generation_id, year, trim, engine_code, body_type, fuel, created_by, updated_by)
SELECT g.id, v.year, v.trim, v.engine_code, 'sedan', v.fuel,
       'seed-ford-fusion-variants', 'seed-ford-fusion-variants'
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 CROSS JOIN (VALUES
    -- 2013: S / SE / Titanium; Hybrid SE, Titanium; Energi SE, Titanium
    (2013::smallint, 'S',                 '2.5 Duratec iVCT',  'PETROL'),
    (2013::smallint, 'SE',                '2.5 Duratec iVCT',  'PETROL'),
    (2013::smallint, 'SE',                '1.6 EcoBoost',      'PETROL'),
    (2013::smallint, 'SE',                '2.0 EcoBoost',      'PETROL'),
    (2013::smallint, 'Titanium',          '2.0 EcoBoost',      'PETROL'),
    (2013::smallint, 'SE Hybrid',         '2.0 Atkinson HEV',  'HYBRID'),
    (2013::smallint, 'Titanium Hybrid',   '2.0 Atkinson HEV',  'HYBRID'),
    (2013::smallint, 'SE Energi',         '2.0 Atkinson PHEV', 'HYBRID'),
    (2013::smallint, 'Titanium Energi',   '2.0 Atkinson PHEV', 'HYBRID'),
    -- 2014: + 1.5 EcoBoost (SE, auto), 1.6 EcoBoost manual-only; + Hybrid S
    (2014::smallint, 'S',                 '2.5 Duratec iVCT',  'PETROL'),
    (2014::smallint, 'SE',                '2.5 Duratec iVCT',  'PETROL'),
    (2014::smallint, 'SE',                '1.5 EcoBoost',      'PETROL'),
    (2014::smallint, 'SE',                '1.6 EcoBoost',      'PETROL'),
    (2014::smallint, 'SE',                '2.0 EcoBoost',      'PETROL'),
    (2014::smallint, 'Titanium',          '2.0 EcoBoost',      'PETROL'),
    (2014::smallint, 'S Hybrid',          '2.0 Atkinson HEV',  'HYBRID'),
    (2014::smallint, 'SE Hybrid',         '2.0 Atkinson HEV',  'HYBRID'),
    (2014::smallint, 'Titanium Hybrid',   '2.0 Atkinson HEV',  'HYBRID'),
    (2014::smallint, 'SE Energi',         '2.0 Atkinson PHEV', 'HYBRID'),
    (2014::smallint, 'Titanium Energi',   '2.0 Atkinson PHEV', 'HYBRID'),
    -- 2015: 1.6 EcoBoost + manual dropped; SE AWD (2.0 EcoBoost) added
    (2015::smallint, 'S',                 '2.5 Duratec iVCT',  'PETROL'),
    (2015::smallint, 'SE',                '2.5 Duratec iVCT',  'PETROL'),
    (2015::smallint, 'SE',                '1.5 EcoBoost',      'PETROL'),
    (2015::smallint, 'SE',                '2.0 EcoBoost',      'PETROL'),
    (2015::smallint, 'Titanium',          '2.0 EcoBoost',      'PETROL'),
    (2015::smallint, 'S Hybrid',          '2.0 Atkinson HEV',  'HYBRID'),
    (2015::smallint, 'SE Hybrid',         '2.0 Atkinson HEV',  'HYBRID'),
    (2015::smallint, 'Titanium Hybrid',   '2.0 Atkinson HEV',  'HYBRID'),
    (2015::smallint, 'SE Energi',         '2.0 Atkinson PHEV', 'HYBRID'),
    (2015::smallint, 'Titanium Energi',   '2.0 Atkinson PHEV', 'HYBRID'),
    -- 2016: same line-up as 2015
    (2016::smallint, 'S',                 '2.5 Duratec iVCT',  'PETROL'),
    (2016::smallint, 'SE',                '2.5 Duratec iVCT',  'PETROL'),
    (2016::smallint, 'SE',                '1.5 EcoBoost',      'PETROL'),
    (2016::smallint, 'SE',                '2.0 EcoBoost',      'PETROL'),
    (2016::smallint, 'Titanium',          '2.0 EcoBoost',      'PETROL'),
    (2016::smallint, 'S Hybrid',          '2.0 Atkinson HEV',  'HYBRID'),
    (2016::smallint, 'SE Hybrid',         '2.0 Atkinson HEV',  'HYBRID'),
    (2016::smallint, 'Titanium Hybrid',   '2.0 Atkinson HEV',  'HYBRID'),
    (2016::smallint, 'SE Energi',         '2.0 Atkinson PHEV', 'HYBRID'),
    (2016::smallint, 'Titanium Energi',   '2.0 Atkinson PHEV', 'HYBRID'),
    -- 2017: facelift; + Platinum (gas/Hybrid/Energi), + Sport (2.7 V6, AWD)
    (2017::smallint, 'S',                 '2.5 Duratec iVCT',  'PETROL'),
    (2017::smallint, 'SE',                '2.5 Duratec iVCT',  'PETROL'),
    (2017::smallint, 'SE',                '1.5 EcoBoost',      'PETROL'),
    (2017::smallint, 'SE',                '2.0 EcoBoost',      'PETROL'),
    (2017::smallint, 'Titanium',          '2.0 EcoBoost',      'PETROL'),
    (2017::smallint, 'Platinum',          '2.0 EcoBoost',      'PETROL'),
    (2017::smallint, 'Sport',             '2.7 EcoBoost V6',   'PETROL'),
    (2017::smallint, 'S Hybrid',          '2.0 Atkinson HEV',  'HYBRID'),
    (2017::smallint, 'SE Hybrid',         '2.0 Atkinson HEV',  'HYBRID'),
    (2017::smallint, 'Titanium Hybrid',   '2.0 Atkinson HEV',  'HYBRID'),
    (2017::smallint, 'Platinum Hybrid',   '2.0 Atkinson HEV',  'HYBRID'),
    (2017::smallint, 'SE Energi',         '2.0 Atkinson PHEV', 'HYBRID'),
    (2017::smallint, 'Titanium Energi',   '2.0 Atkinson PHEV', 'HYBRID'),
    (2017::smallint, 'Platinum Energi',   '2.0 Atkinson PHEV', 'HYBRID'),
    -- 2018: unchanged from 2017
    (2018::smallint, 'S',                 '2.5 Duratec iVCT',  'PETROL'),
    (2018::smallint, 'SE',                '2.5 Duratec iVCT',  'PETROL'),
    (2018::smallint, 'SE',                '1.5 EcoBoost',      'PETROL'),
    (2018::smallint, 'SE',                '2.0 EcoBoost',      'PETROL'),
    (2018::smallint, 'Titanium',          '2.0 EcoBoost',      'PETROL'),
    (2018::smallint, 'Platinum',          '2.0 EcoBoost',      'PETROL'),
    (2018::smallint, 'Sport',             '2.7 EcoBoost V6',   'PETROL'),
    (2018::smallint, 'S Hybrid',          '2.0 Atkinson HEV',  'HYBRID'),
    (2018::smallint, 'SE Hybrid',         '2.0 Atkinson HEV',  'HYBRID'),
    (2018::smallint, 'Titanium Hybrid',   '2.0 Atkinson HEV',  'HYBRID'),
    (2018::smallint, 'Platinum Hybrid',   '2.0 Atkinson HEV',  'HYBRID'),
    (2018::smallint, 'SE Energi',         '2.0 Atkinson PHEV', 'HYBRID'),
    (2018::smallint, 'Titanium Energi',   '2.0 Atkinson PHEV', 'HYBRID'),
    (2018::smallint, 'Platinum Energi',   '2.0 Atkinson PHEV', 'HYBRID'),
    -- 2019: refresh; + SEL, Platinum dropped, Hybrid S dropped, Energi Titanium only
    (2019::smallint, 'S',                 '2.5 Duratec iVCT',  'PETROL'),
    (2019::smallint, 'SE',                '2.5 Duratec iVCT',  'PETROL'),
    (2019::smallint, 'SE',                '1.5 EcoBoost',      'PETROL'),
    (2019::smallint, 'SE',                '2.0 EcoBoost',      'PETROL'),
    (2019::smallint, 'SEL',               '1.5 EcoBoost',      'PETROL'),
    (2019::smallint, 'SEL',               '2.0 EcoBoost',      'PETROL'),
    (2019::smallint, 'Titanium',          '2.0 EcoBoost',      'PETROL'),
    (2019::smallint, 'Sport',             '2.7 EcoBoost V6',   'PETROL'),
    (2019::smallint, 'SE Hybrid',         '2.0 Atkinson HEV',  'HYBRID'),
    (2019::smallint, 'SEL Hybrid',        '2.0 Atkinson HEV',  'HYBRID'),
    (2019::smallint, 'Titanium Hybrid',   '2.0 Atkinson HEV',  'HYBRID'),
    (2019::smallint, 'Titanium Energi',   '2.0 Atkinson PHEV', 'HYBRID'),
    -- 2020: final year; Sport / 2.7 V6 dropped
    (2020::smallint, 'S',                 '2.5 Duratec iVCT',  'PETROL'),
    (2020::smallint, 'SE',                '2.5 Duratec iVCT',  'PETROL'),
    (2020::smallint, 'SE',                '1.5 EcoBoost',      'PETROL'),
    (2020::smallint, 'SE',                '2.0 EcoBoost',      'PETROL'),
    (2020::smallint, 'SEL',               '1.5 EcoBoost',      'PETROL'),
    (2020::smallint, 'Titanium',          '2.0 EcoBoost',      'PETROL'),
    (2020::smallint, 'SE Hybrid',         '2.0 Atkinson HEV',  'HYBRID'),
    (2020::smallint, 'SEL Hybrid',        '2.0 Atkinson HEV',  'HYBRID'),
    (2020::smallint, 'Titanium Hybrid',   '2.0 Atkinson HEV',  'HYBRID'),
    (2020::smallint, 'Titanium Energi',   '2.0 Atkinson PHEV', 'HYBRID')
    -- 2020 SEL 2.0 EcoBoost: not sold in MY2020 (see header), deliberately absent.
 ) AS v(year, trim, engine_code, fuel)
 WHERE mk.slug = 'ford' AND m.slug = 'fusion' AND g.slug = 'gen'
ON CONFLICT (generation_id, year, trim, engine_code) DO NOTHING;

COMMIT;

-- ============================================================
-- Verify
-- ============================================================
SELECT g.slug, g.code, g.name, g.year_from, g.year_to
  FROM vehicle_generations g
  JOIN vehicle_models m  ON m.id  = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 WHERE mk.slug = 'ford' AND m.slug = 'fusion';

SELECT vv.year, COUNT(*) AS variants,
       string_agg(DISTINCT vv.engine_code, ', ' ORDER BY vv.engine_code) AS engines
  FROM vehicle_variants vv
  JOIN vehicle_generations g ON g.id = vv.generation_id
  JOIN vehicle_models m  ON m.id  = g.model_id
  JOIN vehicle_makes  mk ON mk.id = m.make_id
 WHERE mk.slug = 'ford' AND m.slug = 'fusion' AND g.slug = 'gen'
 GROUP BY vv.year
 ORDER BY vv.year;
SQL
