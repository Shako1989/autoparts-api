#!/usr/bin/env bash
# Seed body and lighting parts for both Ford Fusion generations (CD338
# MY2006-2012 and CD391 MY2013-2020, US market, sedan), split by facelift:
# headlamps, tail lamps (outer and, where the car has them, inner trunk-lid
# lamps), fog lamps, front and rear bumper covers, fenders, hoods, grilles
# (upper bars, lower bumper grilles, fog bezels), door mirrors and caps,
# radiator supports and trunk lids. TODO.md task 6. Same layout and rules as
# the service-part seeds (batch 1 and 2), with two differences:
#   seed_fits.generation_slug  'cd338' or 'gen' (= CD391), so one script
#                              covers both generations;
#   seed_fits.engine_code      optional: NULL = every engine of those model
#                              years, because body parts fit by year and trim.
#
# Ford splits body parts by option code (signature lamps, LED, Sport, Auto
# Park, tow hook, engine heater, Plug-In Hybrid, fog bezel finish), not by
# trim name. Where the option is a trim (Sport, Energi, Titanium) the trims
# column carries it; otherwise the part is fitted to every trim of those
# years and the option sits in fitments.notes, for the buyer to match against
# their own car. Body parts have Ford service numbers only; "CP" suffixes are
# Ford's crash-part order codes for the same part and "PTM" means primed,
# paint to match; both are stored as alternate OEM numbers.
#
# Requires: ford/fusion generations 'cd338' (41 variants) and 'gen' (CD391,
# 90 variants) and the canonical category tree (scripts/seed-category-tree.sh).
#
# Run locally:  ./scripts/seed-ford-fusion-body-lighting.sh
# Run on prod:  print the heredoc body and run it from a DB client (seed-only change, no VM rebuild):
#   awk '/^docker exec/{f=1;next} /^SQL$/{f=0} f' scripts/seed-ford-fusion-body-lighting.sh > ~/Downloads/seed-ford-fusion-body-lighting.sql
#
# Research date: 2026-11-10. Market: US. Confidence bar: 90%; everything below
# it is listed under LEFT OUT and not seeded. Sources are the Ford EPC mirrors
# fordpartsgiant.com and fordpartsdeal.com (year lists with Ford's division,
# production dates, option notes and "Replaces" chains, plus part detail pages)
# and, for the few cross-references, CarParts.com, FitParts, Brock / Everyday
# Auto Parts and Central Alberta Paint Supply pages. Every aftermarket catalog
# (TYC, Depo, Dorman, Keystone, RockAuto, go-parts, paintedautoparts) blocked
# fetches, so aftermarket numbers are thin. Mercury Milan / Lincoln MKZ-only
# numbers on the shared catalog pages were left out.
#
# Sources (per claim):
#   CD338 pre-facelift MY2006-2009 (fordpartsgiant year lists with Ford division, production dates and "Replaced By"; fordpartsdeal part pages for model years):
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/electrical/headlamps_and_front_flasher_lamps.html , .../2006-ford-fusion/electrical/headlamps_and_front_flasher_lamps.html (no Ford-division HID; bulbs)
#     https://www.fordpartsgiant.com/parts/ford-headlamp-asy_6e5z-13008-ad.html , .../ford-headlamp-asy_6e5z-13008-bd.html (replace -AC / -BC, 2006-2009)
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/electrical/rear_lamps.html , .../2006-ford-fusion/electrical/rear_lamps.html (6E5Z-13404-B / 13405-B replace -A; inner lamps Mercury / Lincoln only)
#     https://www.fordpartsdeal.com/oem/ford~lamp-assembly-rear~6e5z-13404-b , .../ford~lamp-assembly-rear~6e5z-13405-b
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/electrical/front_fog_lamps.html , https://www.fordpartsdeal.com/oem/ford~lamp-assembly-fog~6e5z-15200-a
#     https://www.fordpartsgiant.com/parts-list/2006-ford-fusion/body_and_paint/radiator_grille_and_front_bumper.html , .../2008-ford-fusion/... , .../2009-ford-fusion/... (bumper cover, grille 8200A/B/C, 7E5Z black + bright set, fog bezels 17E810 / 17E811 and supersessions)
#     https://www.fordpartsgiant.com/parts/ford-cover_6e5z-17d957-captm.html
#     https://www.fordpartsgiant.com/parts-list/2006-ford-fusion/body_and_paint/rear_bumper.html , .../2008-ford-fusion/body_and_paint/rear_bumper.html , .../2009-ford-fusion/body_and_paint/rear_bumper.html (8E5Z covers "With Rear Parking Aid" supersede the 6E5Z "Less" covers; I4 vs V6 cut-outs)
#     https://www.fordpartsdeal.com/parts-select/ford-fusion-bumper-cover (8E5Z-17K835-GAPTM replaces 6E5Z-17K835-CAPTM, 2006-2009)
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/body_and_paint/dash_panel_and_front_fenders.html , https://fordpartsdeal.com/parts-select/ford-fusion-fender
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/body_and_paint/hood_and_related_parts.html , https://www.fordpartsdeal.com/parts-select/ford-fusion-hood
#     https://www.fordpartsgiant.com/parts-list/2006-ford-fusion/body_and_paint/exterior_rear_view_mirror.html , .../2008-ford-fusion/... , .../2009-ford-fusion/... (mirrors sold without caps; caps by option code)
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/body_and_paint/front_panels_aprons_side_members.html , https://www.fordpartsdeal.com/parts-select/ford-fusion-radiator-support
#     https://www.fordpartsgiant.com/parts-list/2006-ford-fusion/body_and_paint/luggage_compartment_door.html , .../2007-ford-fusion/... , .../2008-ford-fusion/... , .../2009-ford-fusion/...
#     https://www.everydayautoparts.com/products/3221-2085l (Brock left headlamp = Partslink FO2502219) , https://www.everydayautoparts.com/products/3222-2010l (Brock left tail lamp = FO2818123)
#     https://centralalbertapaintsupply.ca/?p=146436 (FO2502219C = 6E5Z13008BD) , https://centralalbertapaintsupply.ca/?p=146630 (FO2503219C = 6E5Z13008AD)
#   CD338 facelift MY2010-2012 (Ford EPC mirrors; "CP" = Ford crash-part order code for the same part, "PTM" = paint-to-match primed panel):
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/electrical/headlamps_and_front_flasher_lamps.html (9E5Z-13008-A/-B, no Ford-division HID; bulb 9N7Z-13N021-A)
#     https://www.fordpartsdeal.com/oem/ford~headlamp-assembly~9e5z-13008-a , https://www.fordpartsgiant.com/parts/ford-headlamp-asy_9e5z-13008-b.html
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/electrical/rear_lamps.html (9E5Z-13404-A / 13405-A; inner lamps are Lincoln / Mercury only)
#     https://www.fordpartsdeal.com/oem/ford~tail-lamp-assembly~9e5z-13404-a , .../ford~tail-lamp-assembly~9e5z-13405-a
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/electrical/front_fog_lamps.html , https://www.fordpartsdeal.com/oem/ford~fog-lamp-assembly~6e5z-15200-a (one number both sides, 2006-2012)
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/body_and_paint/radiator_grille_and_front_bumper.html (bumper cover, grille bars, bumper grille, surround, CP codes)
#     https://www.fordpartsdeal.com/oem/ford~bumper-cover~ae5z-17d957-baptm
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/body_and_paint/rear_bumper.html , https://www.fordpartsdeal.com/oem/ford~bumper-cover~ae5z-17k835-aaptm (park-aid holes drilled; stone deflectors by engine)
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/body_and_paint/dash_panel_and_front_fenders.html , https://www.fordpartsdeal.com/oem/ford~fender~ae5z-16005-a , .../ford~fender~ae5z-16006-a
#     https://www.fordpartsdeal.com/oem/ford~hood~be5z-16612-a , https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/body_and_paint/hood_and_related_parts.html (9E5Z-16612-A superseded; insulators)
#     https://www.fordpartsdeal.com/oem/ford~grille~ae5z-8200-c , .../ae5z-8200-a , .../ae5z-8200-b (bright bars; S / SE / SEL / Hybrid)
#     https://www.fordpartsdeal.com/oem/ford~grille~be5z-8200-aa , .../be5z-8200-ba , .../be5z-8200-ca (Sport Shadow Chrome bars)
#     https://www.fordpartsdeal.com/oem/ford~grille~ae5z-8200-da , .../ae5z-8200-db (bumper lower grille), .../ford~grille~ae5z-17k945-a , .../be5z-17k945-aa (surround)
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/body_and_paint/exterior_rear_view_mirror.html , .../2010-ford-fusion/body_and_paint/exterior_rear_view_mirror.html (mirror versions, production dates, covers)
#     https://www.fordpartsdeal.com/oem/ford~mirror-assembly~be5z-17682-aa , .../be5z-17683-aa , .../be5z-17682-ba , .../be5z-17683-ba , .../be5z-17682-ca , .../be5z-17683-ca , .../9e5z-17682-b
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/body_and_paint/front_panels_aprons_side_members.html (radiator supports)
#     https://www.fordpartsdeal.com/oem/ford~radiator-support~ae5z-16138-a , .../ae5z-16138-b , .../ah6z-16138-a , https://www.fordpartsgiant.com/parts/ford-front-end-assy_ae5z-16138-b.html
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/body_and_paint/luggage_compartment_door.html , https://www.fordpartsdeal.com/oem/ford~trunk-lid~9e5z-5440110-a , .../9e5z-5440110-b
#     https://www.carparts.com/details/Ford/Fusion/Replacement/Headlight/2012/SET-REPF100115Q.html (CAPA pair; Partslink FO2502273C / FO2503273C)
#     https://www.fitparts.com/bumpers-parts-fitparts-primed-front-bumper-cover-fascia-for-2010-2011-2012-ford-fusion-s-10-11-12-5798 (Partslink FO1000650)
#   CD391 pre-facelift MY2013-2016 (Ford EPC mirrors; Ford's "With / Without Energi Or Titanium" split = Series 20/50/55 + Plug-In Hybrid vs 5/10/25 + Hybrid):
#     https://www.fordpartsdeal.com/parts-list/{2013,2014,2015,2016}-ford-fusion/headlights-lighting/{headlamps,tail-lamps,fog-lamps,backup-lamps}
#     https://www.fordpartsdeal.com/parts-list/{2013,2014,2015,2016}-ford-fusion/body-hardware/{bumper-components-front,bumper-components-rear,fender-components,hood-components,grille-components,outside-mirrors,radiator-support,structural-components-rails,trunk-lid-components}
#     https://www.fordpartsdeal.com/parts-select/2016-ford-fusion-headlight , https://www.fordpartsdeal.com/oem/ford~bumper-assembly-front~ds7z-17d957-aacp
#     https://www.fordpartsgiant.com/parts-list/{2013,2016}-ford-fusion/electrical/{headlamps_and_front_flasher_lamps,front_fog_lamps,rear_lamps}.html
#     https://www.fordpartsgiant.com/parts-list/{2013,2016}-ford-fusion/body_and_paint/{radiator_grille_and_front_bumper,rear_bumper,exterior_rear_view_mirror,dash_panel_and_front_fenders,hood_and_related_parts,luggage_compartment_door,front_panels_aprons_side_members}.html
#     https://www.fordpartsgiant.com/parts/ford-part_<pn>.html product pages ("Replaces" lists, vehicle fitment) for: ds7z-13008-a/-b, 4f9z-15200-aa, ds7z-13404-a/-b/-d/-h, ds7z-13405-a/-b/-d/-h,
#       ds7z-17d957-aaptm, es7z-17d957-cptm, es7z-17757-daptm, es7z-17d957-eptm, ds7z-17k835-aaptm, hs7z-17k835-vfptm, hs7z-17k835-veptm, ds7z-16005-a, ds7z-16006-a/-b, ds7z-16612-a/-b,
#       ds7z-8200-ba, ds7z-17k945-ab/-baptm/-captm, ds7z-16138-b/-c, gs7z-16138-a, hs7z-5440110-a/-b, fs7z-17682-b, fs7z-17683-b, fs7z-17682-bc, fs7z-17683-bc, js7z-17682-dc
#   CD391 facelift MY2017-2020 (Ford EPC mirrors; Ford splits by option code, not trim: signature lamps, LED, Sport, Auto Park, tow hook, engine heater, Plug-In Hybrid):
#     https://www.fordpartsdeal.com/parts-select/2018-ford-fusion-headlight , .../2019-ford-fusion-headlight ("Halogen Without / With Signature Lamps", "LED", 2017-20)
#     https://www.fordpartsgiant.com/parts-list/2018-ford-fusion/electrical/headlamps_and_front_flasher_lamps.html , .../2019-ford-fusion/electrical/headlamps_and_front_flasher_lamps.html
#     https://www.fordpartsgiant.com/parts/ford-lamp-asy_hs7z-13008-aa.html , https://www.fordpartsdeal.com/oem/ford~lamp-asy~hs7z-13008-ab (LED; replace HS7Z-13008-C/-Z and -F/-Y)
#     https://www.fordpartsgiant.com/parts/ford-headlamp-asy_hs7z-13008-d.html , .../ford-headlamp-asy_hs7z-13008-g.html , .../ford-lamp-asy_hs7z-13008-c.html
#     https://www.fordpartsdeal.com/oem/ford~lamp-asy~hs7z-13405-j , .../ford~lamp-asy-rear-stop-and-flas~hs7z-13404-j , https://www.fordpartsdeal.com/parts-select/2019-ford-fusion-tail-light (outer lamps 2017-20)
#     https://www.fordpartsgiant.com/parts-list/2018-ford-fusion/electrical/rear_lamps.html , .../2019-ford-fusion/electrical/rear_lamps.html , https://www.fordpartsgiant.com/oem-2018-ford-fusion-tail_light.html (inner lamps, production dates)
#     https://www.fordpartsdeal.com/oem/ford~lamp-asy-rear-stop-and-flas~hs7z-13404-h , .../hs7z-13404-a , .../ks7z-13404-f , .../ks7z-13404-g
#     https://www.fordpartsdeal.com/parts-select/2018-ford-fusion-fog-light , .../2019-ford-fusion-fog-light , .../2020-ford-fusion-fog-light
#     https://www.fordpartsgiant.com/parts-list/2018-ford-fusion/electrical/front_fog_lamps.html , .../2019-ford-fusion/electrical/front_fog_lamps.html
#     https://www.fordpartsdeal.com/parts-select/2018-ford-fusion-bumper , .../2019-ford-fusion-bumper , .../2020-ford-fusion-bumper (front covers by Sport / Auto Park / tow hook)
#     https://www.fordpartsgiant.com/parts-list/2018-ford-fusion/body_and_paint/radiator_grille_and_front_bumper.html , .../2019-ford-fusion/body_and_paint/radiator_grille_and_front_bumper.html (lower grille covers 17B968)
#     https://www.fordpartsgiant.com/parts/ford-bumper-asy-front_hs7z-17d957-aptm.html , .../hs7z-17d957-vaptm.html , .../hs7z-17d957-acp.html
#     https://www.fordpartsdeal.com/parts-list/2018-ford-fusion/body-hardware/bumper-components-rear , .../2019-ford-fusion/body-hardware/bumper-components-rear (rear covers by sensors; valances)
#     https://www.fordpartsgiant.com/parts-list/2018-ford-fusion/body_and_paint/rear_bumper.html , .../2019-ford-fusion/body_and_paint/rear_bumper.html
#     https://www.fordpartsgiant.com/parts-list/2018-ford-fusion/body_and_paint/dash_panel_and_front_fenders.html , .../2019-ford-fusion/... , https://www.fordpartsgiant.com/parts/ford-fender-asy-front_hs7z-16006-a.html , .../hs7z-16006-b.html , .../hs7z-16005-a.html
#     https://www.fordpartsgiant.com/parts/ford-hood-asy_ds7z-16612-b.html (2013-2020, replaces DS7Z-16612-A) , .../parts-list/2018-ford-fusion/body_and_paint/hood_and_related_parts.html , .../2019-ford-fusion/...
#     https://www.fordpartsdeal.com/parts-select/2018-ford-fusion-grille , .../2019-ford-fusion-grille , https://www.fordpartsgiant.com/parts/ford-grille-assy-radiator_hs7z-8200-aa.html , .../hs7z-8200-ba.html , .../hs7z-8200-va.html , .../ford-grille-assembly-radiator_ks7z-8200-ac.html , .../ford-grille-assy-radiator_ks7z-8200-bb.html , .../ford-grille-assembly-radiator_ks7z-8200-db.html
#     https://www.fordpartsdeal.com/parts-select/2017-ford-fusion-car-mirror , .../2018-... , .../2019-... , .../2020-ford-fusion-car-mirror (Ford mirror option notes per year)
#     https://www.fordpartsgiant.com/parts-list/2018-ford-fusion/body_and_paint/exterior_rear_view_mirror.html , https://www.fordpartsgiant.com/parts/ford-mirror-asy-rear-view-outer_js7z-17682-xb.html , .../js7z-17683-xb.html , .../js7z-17682-db.html , .../js7z-17683-db.html , .../js7z-17682-ca.html
#     https://www.fordpartsgiant.com/parts-list/2018-ford-fusion/body_and_paint/front_panels_aprons_side_members.html , https://www.fordpartsgiant.com/parts/ford-front-end-asy_hs7z-16138-a.html , .../hs7z-16138-c.html , .../ford-support-radiator_gs7z-16138-a.html , .../gp5z-16138-a.html
#
# Deliberately LEFT OUT (could not verify, < 90% confidence, or no clean supersession):
#   CD338 MY2006-2009:
#   -- Right tail lamp Partslink FO2819113 / Brock 3222-2010R: search results only (Brock page rate-limited).
#   -- Front bumper FO1000596C: page ties it to 6E5Z17D957CA but never labels it Partslink or CAPA (85%). Grille bars FO1036117 / FO1036118, fog bezel FO1039108, radiator support FO1225184: "related parts" boxes or snippets only.
#   -- CAPA status of FO2502219C / FO2503219C: pages contradict each other.
#   -- Headlamp numbers 6E5Z-13008-AB / -BB: seller "compatible numbers" only; Ford shows only -AC / -BC as superseded.
#   -- Mirrors 6E5Z-17682-C / 17683-C ("electric / heated", no production date): market unclear, possibly export.
#   -- Trim mapping of Ford option codes (Base / Low / Mid / SEL, colour-keyed bezels): catalog gives option codes, not trim names, so grilles, bezels and caps are fitted to every trim with the option in notes.
#   -- CP listings of the fog bezels: exact strings not captured. Side marker lamps 6E5Z-13200-C / -D, hinges, upper radiator brackets, door handles: out of scope.
#   -- TYC / Depo / Dorman / Sherman / Keystone / RockAuto / 1A Auto numbers: 403 or script-only pages.
#   CD338 MY2010-2012:
#   -- Upper grille bar for the MY2010 Sport: fordpartsdeal says BE5Z-8200-AA 2010-2012 but the matching bars are 2011-2012 and the bright bars list Sport too; seeded 2011-2012 only (80% for 2010).
#   -- MY2010 mirrors 6E5Z-17682-A/-B and 6E5Z-17683-A/-B (production to 07/2010) belong to the 2006-2009 window and are seeded there with MY2010 included.
#   -- Partslink numbers from snippets only: headlamps FO2502273 / FO2503273 (non-CAPA), tail lamp FO2819147, rear bumper FO1100649(C), hood FO1230279(C), left fender FO1240274(C).
#   -- TYC / Depo / Dorman / Sherman / Keystone numbers for lamps, mirrors, radiator supports, grilles, trunk lids: RockAuto blocked, partsgeek / go-parts / paintedautoparts 403.
#   -- Mirror covers (6E5Z-17D742/-743 black, PTM, chrome) and door handles: not seeded (covers listed for all divisions, chrome possibly Lincoln-only).
#   CD391 MY2013-2016:
#   -- Aftermarket: Partslink FO2502304 / FO2503304 (headlamps), FO1000680 / FO1000681 (front covers), FO2803105C / FO2803106C (inner lamps), FO1320482 / FO1320541 / FO1320542 (mirrors), "20-FD73-AR": snippets only; paintedautoparts, go-parts, carid, eBay, Walmart, RockAuto blocked.
#   -- HID / LED / adaptive headlamps 2013-2016: Ford lists none for the Fusion (the split 13008 numbers are MKZ-only).
#   -- Mirrors with tangled chains: puddle-lamp units DS7Z/FS7Z-17682-CA -> JS7Z-17682-CA (its page lists Police / SSV), FS7Z-17682-CB -> FS7Z-17682-CC (2016-19 page), left BLIS 2013-14 DS7Z-17683-DA -> JS7Z-17683-DB (Police only on its page),
#      BLIS 2015+ FS7Z-1768x-DB, coverless primed DS7Z-1768x-LT / -NU / -NT, painted-cap left FS7Z-17683-XA: not seeded for 2013-2016.
#   -- Titanium Hybrid (2015-16) tail-lamp level: Ford only says "With Energi Or Titanium"; assigned to the Titanium lamps with a note (80%).
#   -- Chrome grille inserts DS7Z-8200-DA..-HA, side grilles 17B814, lower trim panels 17K922, dual-exhaust bezels DS7Z-17F827-C/-D, rear reflectors DS7Z-13A565-J/-K: not seeded (inserts / no category).
#   -- Hood material: not stated by any source. Door handles: not researched.
#   CD391 MY2017-2020:
#   -- Trim mapping of Ford's option splits (signature lamps, LED headlamps, Storm Metallic / honeycomb / black grilles, lower grille finish, mirror packages): Ford gives options, not trims, so those parts are fitted to every (non-Sport) trim with the option in notes.
#   -- Inner tail lamp "Level 1 / Level 3": Ford merges the notes; the halogen / LED labels come from salvage-seller listings and are marked unverified in the descriptions.
#   -- Bumper side grilles / fog surrounds (17B814; HS7Z-17B814-AA..VB, JS7Z-17B814-DA/DB, KS7Z-17B814-AA..PB): garbled option strings and inconsistent side labels.
#   -- Energi charge-port door: not on the fender pages. Mirror power-fold / camera / auto-dim splits: not separate Ford assemblies.
#   -- Supersession chains of the heated (JS7Z/KS7Z-1768x-BB), 2020 BLIS (KS7Z-1768x-DAPTM) and BLIS-no-memory (KS7Z-1768x-ZA) mirrors: detail pages not opened (seeded from the yearly pages, 90%).
#   -- Police-only mirrors KS7Z-1768x-EA, primed coverless BLIS units DS7Z-17682-NU / DS7Z-17683-NT: excluded.
#   -- Rear valances (DS7Z-17810-AA/-CAPTM/-DAPTM, HS7Z-17810-VAPTM, KS7Z-17F828-CA/-HA/-DA/-VA): named in the rear-cover descriptions, no category for them.
#   -- Aftermarket: Partslink FO2502348 / FO2503348 / FO2503350 / FO2502347 (headlamps), FO2804118 (outer tail lamp), FO1321623 (mirror), FO1240305(C) (fender), Depo A30-1105R-AC7: snippets only; go-parts, paintedautoparts, auto-bodyparts, partify, RockAuto, carparts.com blocked or empty.

set -euo pipefail

CONTAINER="${CONTAINER:-autoparts-postgres}"

docker exec -i "$CONTAINER" psql -U autoparts -d autoparts -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

CREATE TEMP TABLE seed_parts (
    key           text PRIMARY KEY,
    category_slug text NOT NULL,
    name_az       text NOT NULL,
    name_ru       text NOT NULL,
    name_en       text NOT NULL,
    brand         text NOT NULL,
    oem_key        text NOT NULL UNIQUE,   -- identity: an OEM number (Ford service or Motorcraft)
    oem_key_source text NOT NULL,          -- 'Ford' or 'Motorcraft'
    position      text,
    description   text
) ON COMMIT DROP;

CREATE TEMP TABLE seed_numbers (
    key    text NOT NULL REFERENCES seed_parts(key),
    number text NOT NULL,
    type   text NOT NULL CHECK (type IN ('OEM', 'AFTERMARKET')),
    source text NOT NULL,
    PRIMARY KEY (key, number, type)
) ON COMMIT DROP;

CREATE TEMP TABLE seed_fits (
    key         text NOT NULL REFERENCES seed_parts(key),
    generation_slug text NOT NULL CHECK (generation_slug IN ('cd338', 'gen')),  -- 'gen' = CD391
    year_from   smallint NOT NULL,
    year_to     smallint NOT NULL,
    engine_code text,            -- NULL = every engine of those model years
    trims       text[],          -- NULL = all trims
    notes       text
) ON COMMIT DROP;

-- ============================================================
-- DATA
-- ============================================================
-- ---------- CD338 pre-facelift, MY2006-2009 (mirrors and caps run into MY2010-2012) ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  ('headlamp-l-0609',        'headlights',        'Fara, sol, halogen (2006-2009)',                              'Фара левая, галоген (2006-2009)',                                    'Headlamp assembly, left, halogen (2006-2009)',                     'Ford', '6E5Z-13008-BD',    'Ford', 'FRONT_LEFT',  'Every trim; Ford built no HID or self-levelling Fusion. Supersedes 6E5Z-13008-BC (built 12/2005-02/2006). Bulbs: low beam H11, high beam H7, park/turn 3457NAK amber. Crash-part code 6E5Z-13008-BDCP.'),
  ('headlamp-r-0609',        'headlights',        'Fara, sağ, halogen (2006-2009)',                              'Фара правая, галоген (2006-2009)',                                   'Headlamp assembly, right, halogen (2006-2009)',                    'Ford', '6E5Z-13008-AD',    'Ford', 'FRONT_RIGHT', 'Every trim. Supersedes 6E5Z-13008-AC. Bulbs: low beam H11, high beam H7, park/turn 3457NAK amber. Discontinued at Ford. Crash-part code 6E5Z-13008-ADCP.'),
  ('taillamp-l-0609',        'tail-lights',       'Arxa fənər, sol (2006-2009)',                                 'Фонарь задний левый (2006-2009)',                                    'Tail lamp assembly, left (2006-2009)',                             'Ford', '6E5Z-13405-B',     'Ford', 'REAR_LEFT',   'One-piece quarter-mounted lamp (no inner trunk-lid lamp on the Fusion). Supersedes 6E5Z-13405-A. Stop/turn bulb 4157K. Crash-part code 6E5Z-13405-BCP.'),
  ('taillamp-r-0609',        'tail-lights',       'Arxa fənər, sağ (2006-2009)',                                 'Фонарь задний правый (2006-2009)',                                   'Tail lamp assembly, right (2006-2009)',                            'Ford', '6E5Z-13404-B',     'Ford', 'REAR_RIGHT',  'One-piece quarter-mounted lamp. Supersedes 6E5Z-13404-A. Stop/turn bulb 4157K. Crash-part code 6E5Z-13404-BCP.'),
  ('front-bumper-0609',      'bumpers',           'Ön bamper, astarlanmış (2006-2009)',                          'Бампер передний, грунтованный (2006-2009)',                          'Front bumper cover, primed (2006-2009)',                           'Ford', '6E5Z-17D957-CAPTM','Ford', 'FRONT',       'Paint-to-match cover, every trim, with or without fog lamps (the fog bezels are separate). Crash-part code 6E5Z-17D957-CACP.'),
  ('rear-bumper-i4-0609',    'bumpers',           'Arxa bamper, astarlanmış, bir egzoz kəsiyi (2.3, 2006-2009)', 'Бампер задний, грунтованный, один вырез под выхлоп (2.3, 2006-2009)', 'Rear bumper cover, primed, single exhaust cut-out (2.3, 2006-2009)', 'Ford', '8E5Z-17K835-GAPTM','Ford', 'REAR',      '2.3 I4 cars (single exhaust). Current cover has park-aid locating holes inside: drill them on cars with rear park aid. Supersedes 6E5Z-17K835-CAPTM. Crash-part code 8E5Z-17K835-GACP.'),
  ('rear-bumper-v6-0609',    'bumpers',           'Arxa bamper, astarlanmış, iki egzoz kəsiyi (3.0 V6, 2006-2009)', 'Бампер задний, грунтованный, два выреза под выхлоп (3.0 V6, 2006-2009)', 'Rear bumper cover, primed, two exhaust cut-outs (3.0 V6, 2006-2009)', 'Ford', '8E5Z-17K835-HAPTM','Ford', 'REAR', '3.0 V6 cars (dual exhaust), FWD and AWD. Park-aid holes drilled on equipped cars. Supersedes 6E5Z-17K835-DAPTM. Crash-part code 8E5Z-17K835-HACP.'),
  ('fender-l-0609',          'fenders',           'Ön qanad, sol (2006-2009)',                                   'Крыло переднее левое (2006-2009)',                                   'Front fender, left (2006-2009)',                                   'Ford', '6E5Z-16006-AA',    'Ford', 'FRONT_LEFT',  'Every trim; shared with the Mercury Milan.'),
  ('fender-r-0609',          'fenders',           'Ön qanad, sağ (2006-2009)',                                   'Крыло переднее правое (2006-2009)',                                  'Front fender, right (2006-2009)',                                  'Ford', '6E5Z-16005-AA',    'Ford', 'FRONT_RIGHT', 'Every trim; shared with the Mercury Milan.'),
  ('hood-0609',              'hoods',             'Kapot (2006-2009)',                                           'Капот (2006-2009)',                                                  'Hood panel (2006-2009)',                                           'Ford', '6E5Z-16612-AA',    'Ford', 'FRONT',       'Every trim. The 2010-2012 hood is a different part.'),
  ('grille-upper-0609',      'grilles',           'Radiator barmaqlığı, üst, xrom (2006-2009)',                  'Решётка радиатора верхняя, хром (2006-2009)',                        'Upper radiator grille, chrome (2006-2009)',                        'Ford', '6E5Z-8200-A',      'Ford', 'FRONT',       'Cars with the chrome grille (no fog lamps, or black / bright fog bezels). Crash-part code 6E5Z-8200-ACP.'),
  ('grille-bar1-0609',       'grilles',           'Radiator barmaqlığı, alt bar 1, xrom (2006-2009)',            'Решётка радиатора, нижняя планка 1, хром (2006-2009)',               'Lower grille bar 1, chrome (2006-2009)',                           'Ford', '6E5Z-8200-B',      'Ford', 'FRONT',       'Cars with the chrome grille. Crash-part code 6E5Z-8200-BCP.'),
  ('grille-bar2-0609',       'grilles',           'Radiator barmaqlığı, alt bar 2, xrom (2006-2009)',            'Решётка радиатора, нижняя планка 2, хром (2006-2009)',               'Lower grille bar 2, chrome (2006-2009)',                           'Ford', '6E5Z-8200-C',      'Ford', 'FRONT',       'Cars with the chrome grille. Crash-part code 6E5Z-8200-CCP.'),
  ('grille-upper-blk-0709',  'grilles',           'Radiator barmaqlığı, üst, qara + xrom (2007-2009)',           'Решётка радиатора верхняя, чёрная с хромом (2007-2009)',             'Upper radiator grille, black and bright chrome (2007-2009)',       'Ford', '7E5Z-8200-AA',     'Ford', 'FRONT',       'Cars with colour-keyed fog lamp bezels; on the MY2007-2009 catalog lists only.'),
  ('grille-bar1-blk-0709',   'grilles',           'Radiator barmaqlığı, alt bar 1, qara + xrom (2007-2009)',     'Решётка радиатора, нижняя планка 1, чёрная с хромом (2007-2009)',    'Lower grille bar 1, black and bright chrome (2007-2009)',          'Ford', '7E5Z-8200-BA',     'Ford', 'FRONT',       'Cars with colour-keyed fog lamp bezels.'),
  ('grille-bar2-blk-0709',   'grilles',           'Radiator barmaqlığı, alt bar 2, qara + xrom (2007-2009)',     'Решётка радиатора, нижняя планка 2, чёрная с хромом (2007-2009)',    'Lower grille bar 2, black and bright chrome (2007-2009)',          'Ford', '7E5Z-8200-CA',     'Ford', 'FRONT',       'Cars with colour-keyed fog lamp bezels.'),
  ('fog-bezel-blank-l-0609', 'grilles',           'Ön bamper duman farası yeri qapağı, sol, dumansız (2006-2009)','Заглушка противотуманной фары в бампере, левая (2006-2009)',         'Front bumper fog lamp blank cover, left (2006-2009)',              'Ford', '6E5Z-17E811-AA',   'Ford', 'FRONT_LEFT',  'Cars without front fog lamps.'),
  ('fog-bezel-blank-r-0609', 'grilles',           'Ön bamper duman farası yeri qapağı, sağ, dumansız (2006-2009)','Заглушка противотуманной фары в бампере, правая (2006-2009)',        'Front bumper fog lamp blank cover, right (2006-2009)',             'Ford', '6E5Z-17E810-AA',   'Ford', 'FRONT_RIGHT', 'Cars without front fog lamps.'),
  ('fog-bezel-bright-l-0609','grilles',           'Duman farası haşiyəsi, sol, xrom (2006-2009)',                'Рамка противотуманной фары, левая, хром (2006-2009)',                'Fog lamp bezel, left, bright (2006-2009)',                         'Ford', '6E5Z-17E811-A',    'Ford', 'FRONT_LEFT',  'Cars with fog lamps and the bright bezel (Ford option code SEL). Supersedes 6E5Z-17E811-B.'),
  ('fog-bezel-bright-r-0609','grilles',           'Duman farası haşiyəsi, sağ, xrom (2006-2009)',                'Рамка противотуманной фары, правая, хром (2006-2009)',               'Fog lamp bezel, right, bright (2006-2009)',                        'Ford', '6E5Z-17E810-A',    'Ford', 'FRONT_RIGHT', 'Cars with fog lamps and the bright bezel (Ford option code SEL). Supersedes 6E5Z-17E810-C.'),
  ('fog-bezel-black-l-0709', 'grilles',           'Duman farası haşiyəsi, sol, qara (2007-2009)',                'Рамка противотуманной фары, левая, чёрная (2007-2009)',              'Fog lamp bezel, left, black (2007-2009)',                          'Ford', '6E5Z-17E811-CA',   'Ford', 'FRONT_LEFT',  'Cars with fog lamps and the black bezel (Ford option code Mid), built from 08/2006.'),
  ('fog-bezel-black-r-0709', 'grilles',           'Duman farası haşiyəsi, sağ, qara (2007-2009)',                'Рамка противотуманной фары, правая, чёрная (2007-2009)',             'Fog lamp bezel, right, black (2007-2009)',                         'Ford', '6E5Z-17E810-CA',   'Ford', 'FRONT_RIGHT', 'Cars with fog lamps and the black bezel (Ford option code Mid), built from 08/2006.'),
  ('fog-bezel-ptm-l-0709',   'grilles',           'Duman farası haşiyəsi, sol, astarlanmış (2007-2009)',         'Рамка противотуманной фары, левая, грунтованная (2007-2009)',        'Fog lamp bezel, left, colour-keyed primed (2007-2009)',            'Ford', '7E5Z-17E811-APTM', 'Ford', 'FRONT_LEFT',  'Cars with fog lamps and body-colour bezels, with the black + bright grille.'),
  ('fog-bezel-ptm-r-0709',   'grilles',           'Duman farası haşiyəsi, sağ, astarlanmış (2007-2009)',         'Рамка противотуманной фары, правая, грунтованная (2007-2009)',       'Fog lamp bezel, right, colour-keyed primed (2007-2009)',           'Ford', '7E5Z-17E810-APTM', 'Ford', 'FRONT_RIGHT', 'Cars with fog lamps and body-colour bezels, with the black + bright grille.'),
  ('mirror-l-power-0610',    'mirrors',           'Yan güzgü, sol, elektrik (2006-2010)',                        'Зеркало наружное левое, электро (2006-2010)',                        'Door mirror, left, power, not heated (2006-2010)',                 'Ford', '6E5Z-17683-A',     'Ford', 'FRONT_LEFT',  'Cars built 08/2005-07/2010 (MY2011-2012 use BE5Z-17683-AA). Sold without the cap (6E5Z-17D743-AA black / -BPTM paint-to-match). No power-fold or BLIS Fusion mirror in these years. Crash-part code 6E5Z-17683-ACP.'),
  ('mirror-r-power-0610',    'mirrors',           'Yan güzgü, sağ, elektrik (2006-2010)',                        'Зеркало наружное правое, электро (2006-2010)',                       'Door mirror, right, power, not heated (2006-2010)',                'Ford', '6E5Z-17682-A',     'Ford', 'FRONT_RIGHT', 'Cars built 08/2005-07/2010 (MY2011-2012 use BE5Z-17682-AA). Sold without the cap (6E5Z-17D742-AA / -BPTM). Crash-part code 6E5Z-17682-ACP.'),
  ('mirror-l-heated-puddle-0610','mirrors',       'Yan güzgü, sol, qızdırıcılı, işıqlı (2006-2010)',             'Зеркало наружное левое, с обогревом и подсветкой (2006-2010)',       'Door mirror, left, power, heated, puddle lamp (2006-2010)',        'Ford', '6E5Z-17683-B',     'Ford', 'FRONT_LEFT',  'Ford note: power / heated with puddle lamp, also the memory mirror. Catalog dates end 07/2010 on one page and 07/2012 on another; MY2011-2012 cars are catalogued with BE5Z-17683-BA. Sold without the cap. Crash-part code 6E5Z-17683-BCP.'),
  ('mirror-r-heated-puddle-0610','mirrors',       'Yan güzgü, sağ, qızdırıcılı, işıqlı (2006-2010)',             'Зеркало наружное правое, с обогревом и подсветкой (2006-2010)',      'Door mirror, right, power, heated, puddle lamp (2006-2010)',       'Ford', '6E5Z-17682-B',     'Ford', 'FRONT_RIGHT', 'Ford note: passenger power heated with puddle lamp. Sold without the cap. Crash-part code 6E5Z-17682-BCP.'),
  ('mirror-cap-l-black',     'mirrors',           'Yan güzgü qapağı, sol, qara (2006-2012)',                     'Крышка зеркала левая, чёрная (2006-2012)',                           'Mirror cap, left, black grained (2006-2012)',                      'Ford', '6E5Z-17D743-AA',   'Ford', 'FRONT_LEFT',  'Textured black cap, Ford option codes Base / Low (usually the S).'),
  ('mirror-cap-r-black',     'mirrors',           'Yan güzgü qapağı, sağ, qara (2006-2012)',                     'Крышка зеркала правая, чёрная (2006-2012)',                          'Mirror cap, right, black grained (2006-2012)',                     'Ford', '6E5Z-17D742-AA',   'Ford', 'FRONT_RIGHT', 'Textured black cap, Ford option codes Base / Low (usually the S).'),
  ('mirror-cap-l-ptm',       'mirrors',           'Yan güzgü qapağı, sol, astarlanmış (2006-2012)',              'Крышка зеркала левая, грунтованная (2006-2012)',                     'Mirror cap, left, paint-to-match (2006-2012)',                     'Ford', '6E5Z-17D743-BPTM', 'Ford', 'FRONT_LEFT',  'Primed cap, Ford option codes Mid / SEL (body-colour mirrors).'),
  ('mirror-cap-r-ptm',       'mirrors',           'Yan güzgü qapağı, sağ, astarlanmış (2006-2012)',              'Крышка зеркала правая, грунтованная (2006-2012)',                    'Mirror cap, right, paint-to-match (2006-2012)',                    'Ford', '6E5Z-17D742-BPTM', 'Ford', 'FRONT_RIGHT', 'Primed cap, Ford option codes Mid / SEL (body-colour mirrors).'),
  ('radiator-support-0609',  'radiator-supports', 'Radiator dayağı, ön panel (2006-2009)',                       'Панель передняя, рамка радиатора (2006-2009)',                       'Radiator support, front end panel (2006-2009)',                    'Ford', '6E5Z-16138-A',     'Ford', 'FRONT',       '2.3 and 3.0 cars, every trim. Upper radiator brackets 6E5Z-8A193-A (qty 2) sold separately.'),
  ('trunk-lid-0609',         'trunk-lids',        'Baqaj qapağı, spoylersiz (2006-2009)',                        'Крышка багажника, без спойлера (2006-2009)',                         'Trunk lid, without spoiler (2006-2009)',                           'Ford', '6E5Z-5440110-AA',  'Ford', 'REAR',        'Every trim without the rear spoiler. Hinges 7E5Z-5442700-A (right) / 7E5Z-5442701-A (left).'),
  ('trunk-lid-spoiler-0709', 'trunk-lids',        'Baqaj qapağı, spoyler dəlikli (2007-2009)',                   'Крышка багажника, с отверстиями под спойлер (2007-2009)',            'Trunk lid, with rear spoiler holes (2007-2009)',                   'Ford', '7E5Z-5440110-A',   'Ford', 'REAR',        'Cars with the single rear wing spoiler; on the MY2007-2009 catalog lists only.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('headlamp-l-0609',        '6E5Z-13008-BC',      'OEM', 'Ford'),
  ('headlamp-l-0609',        '6E5Z-13008-BDCP',    'OEM', 'Ford'),
  ('headlamp-l-0609',        'FO2502219',          'AFTERMARKET', 'Partslink'),
  ('headlamp-l-0609',        'FO2502219C',         'AFTERMARKET', 'Partslink'),
  ('headlamp-l-0609',        '3221-2085L',         'AFTERMARKET', 'Brock'),
  ('headlamp-r-0609',        '6E5Z-13008-AC',      'OEM', 'Ford'),
  ('headlamp-r-0609',        '6E5Z-13008-ADCP',    'OEM', 'Ford'),
  ('headlamp-r-0609',        'FO2503219C',         'AFTERMARKET', 'Partslink'),
  ('taillamp-l-0609',        '6E5Z-13405-A',       'OEM', 'Ford'),
  ('taillamp-l-0609',        '6E5Z-13405-BCP',     'OEM', 'Ford'),
  ('taillamp-l-0609',        'FO2818123',          'AFTERMARKET', 'Partslink'),
  ('taillamp-l-0609',        '3222-2010L',         'AFTERMARKET', 'Brock'),
  ('taillamp-r-0609',        '6E5Z-13404-A',       'OEM', 'Ford'),
  ('taillamp-r-0609',        '6E5Z-13404-BCP',     'OEM', 'Ford'),
  ('front-bumper-0609',      '6E5Z-17D957-CACP',   'OEM', 'Ford'),
  ('rear-bumper-i4-0609',    '6E5Z-17K835-CAPTM',  'OEM', 'Ford'),
  ('rear-bumper-i4-0609',    '8E5Z-17K835-GACP',   'OEM', 'Ford'),
  ('rear-bumper-v6-0609',    '6E5Z-17K835-DAPTM',  'OEM', 'Ford'),
  ('rear-bumper-v6-0609',    '8E5Z-17K835-HACP',   'OEM', 'Ford'),
  ('grille-upper-0609',      '6E5Z-8200-ACP',      'OEM', 'Ford'),
  ('grille-bar1-0609',       '6E5Z-8200-BCP',      'OEM', 'Ford'),
  ('grille-bar2-0609',       '6E5Z-8200-CCP',      'OEM', 'Ford'),
  ('fog-bezel-bright-l-0609','6E5Z-17E811-B',      'OEM', 'Ford'),
  ('fog-bezel-bright-r-0609','6E5Z-17E810-C',      'OEM', 'Ford'),
  ('mirror-l-power-0610',    '6E5Z-17683-ACP',     'OEM', 'Ford'),
  ('mirror-r-power-0610',    '6E5Z-17682-ACP',     'OEM', 'Ford'),
  ('mirror-l-heated-puddle-0610', '6E5Z-17683-BCP', 'OEM', 'Ford'),
  ('mirror-r-heated-puddle-0610', '6E5Z-17682-BCP', 'OEM', 'Ford');

INSERT INTO seed_fits (key, generation_slug, year_from, year_to, engine_code, trims, notes) VALUES
  ('headlamp-l-0609',        'cd338', 2006, 2009, NULL, NULL, NULL),
  ('headlamp-r-0609',        'cd338', 2006, 2009, NULL, NULL, NULL),
  ('taillamp-l-0609',        'cd338', 2006, 2009, NULL, NULL, NULL),
  ('taillamp-r-0609',        'cd338', 2006, 2009, NULL, NULL, NULL),
  ('front-bumper-0609',      'cd338', 2006, 2009, NULL, NULL, NULL),
  ('rear-bumper-i4-0609',    'cd338', 2006, 2009, '2.3 Duratec',    NULL, 'Single exhaust; park-aid cars: drill out the sensor holes'),
  ('rear-bumper-v6-0609',    'cd338', 2006, 2009, '3.0 Duratec V6', NULL, 'Dual exhaust, FWD and AWD; park-aid cars: drill out the sensor holes'),
  ('fender-l-0609',          'cd338', 2006, 2009, NULL, NULL, NULL),
  ('fender-r-0609',          'cd338', 2006, 2009, NULL, NULL, NULL),
  ('hood-0609',              'cd338', 2006, 2009, NULL, NULL, NULL),
  ('grille-upper-0609',      'cd338', 2006, 2009, NULL, NULL, 'Chrome grille (no fog lamps, or black / bright fog bezels)'),
  ('grille-bar1-0609',       'cd338', 2006, 2009, NULL, NULL, 'Chrome grille'),
  ('grille-bar2-0609',       'cd338', 2006, 2009, NULL, NULL, 'Chrome grille'),
  ('grille-upper-blk-0709',  'cd338', 2007, 2009, NULL, NULL, 'Black + bright chrome grille with colour-keyed fog bezels'),
  ('grille-bar1-blk-0709',   'cd338', 2007, 2009, NULL, NULL, 'Black + bright chrome grille with colour-keyed fog bezels'),
  ('grille-bar2-blk-0709',   'cd338', 2007, 2009, NULL, NULL, 'Black + bright chrome grille with colour-keyed fog bezels'),
  ('fog-bezel-blank-l-0609', 'cd338', 2006, 2009, NULL, NULL, 'Cars without fog lamps'),
  ('fog-bezel-blank-r-0609', 'cd338', 2006, 2009, NULL, NULL, 'Cars without fog lamps'),
  ('fog-bezel-bright-l-0609','cd338', 2006, 2009, NULL, NULL, 'Fog lamps with bright bezel'),
  ('fog-bezel-bright-r-0609','cd338', 2006, 2009, NULL, NULL, 'Fog lamps with bright bezel'),
  ('fog-bezel-black-l-0709', 'cd338', 2007, 2009, NULL, NULL, 'Fog lamps with black bezel'),
  ('fog-bezel-black-r-0709', 'cd338', 2007, 2009, NULL, NULL, 'Fog lamps with black bezel'),
  ('fog-bezel-ptm-l-0709',   'cd338', 2007, 2009, NULL, NULL, 'Fog lamps with body-colour bezel'),
  ('fog-bezel-ptm-r-0709',   'cd338', 2007, 2009, NULL, NULL, 'Fog lamps with body-colour bezel'),
  ('mirror-l-power-0610',    'cd338', 2006, 2010, NULL, NULL, 'Power, not heated; cars built to 07/2010'),
  ('mirror-r-power-0610',    'cd338', 2006, 2010, NULL, NULL, 'Power, not heated; cars built to 07/2010'),
  ('mirror-l-heated-puddle-0610', 'cd338', 2006, 2010, NULL, NULL, 'Heated with puddle lamp; cars built to 07/2010'),
  ('mirror-r-heated-puddle-0610', 'cd338', 2006, 2010, NULL, NULL, 'Heated with puddle lamp; cars built to 07/2010'),
  ('mirror-cap-l-black',     'cd338', 2006, 2012, NULL, NULL, 'Black textured caps (Ford option codes Base / Low)'),
  ('mirror-cap-r-black',     'cd338', 2006, 2012, NULL, NULL, 'Black textured caps (Ford option codes Base / Low)'),
  ('mirror-cap-l-ptm',       'cd338', 2006, 2012, NULL, NULL, 'Body-colour caps (Ford option codes Mid / SEL)'),
  ('mirror-cap-r-ptm',       'cd338', 2006, 2012, NULL, NULL, 'Body-colour caps (Ford option codes Mid / SEL)'),
  ('radiator-support-0609',  'cd338', 2006, 2009, NULL, NULL, NULL),
  ('trunk-lid-0609',         'cd338', 2006, 2009, NULL, NULL, 'Without rear spoiler'),
  ('trunk-lid-spoiler-0709', 'cd338', 2007, 2009, NULL, NULL, 'With rear spoiler');

-- ---------- CD338 facelift, MY2010-2012 ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  ('headlamp-r-1012',        'headlights',        'Fara, sağ, halogen (2010-2012)',                              'Фара правая, галоген (2010-2012)',                                   'Headlamp assembly, right, halogen (2010-2012)',                    'Ford', '9E5Z-13008-A',     'Ford', 'FRONT_RIGHT', 'Composite halogen headlamp, every 2010-2012 trim incl. Sport and Hybrid; Ford built no HID Fusion in these years. Low/high beam bulb HB3 / 9005. Crash-part code 9E5Z-13008-ACP.'),
  ('headlamp-l-1012',        'headlights',        'Fara, sol, halogen (2010-2012)',                              'Фара левая, галоген (2010-2012)',                                    'Headlamp assembly, left, halogen (2010-2012)',                     'Ford', '9E5Z-13008-B',     'Ford', 'FRONT_LEFT',  'Composite halogen headlamp, every 2010-2012 trim. Bulb HB3 / 9005. Crash-part code 9E5Z-13008-BCP.'),
  ('taillamp-r-1012',        'tail-lights',       'Arxa fənər, sağ (2010-2012)',                                 'Фонарь задний правый (2010-2012)',                                   'Tail lamp assembly, right (2010-2012)',                            'Ford', '9E5Z-13404-A',     'Ford', 'REAR_RIGHT',  'One-piece quarter-mounted lamp, every trim; the Fusion has no inner trunk-lid lamps. Bulb 3M7Z-13466-B (21/5 W). Crash-part code 9E5Z-13404-ACP.'),
  ('taillamp-l-1012',        'tail-lights',       'Arxa fənər, sol (2010-2012)',                                 'Фонарь задний левый (2010-2012)',                                    'Tail lamp assembly, left (2010-2012)',                             'Ford', '9E5Z-13405-A',     'Ford', 'REAR_LEFT',   'One-piece quarter-mounted lamp, every trim. Bulb 3M7Z-13466-B. Crash-part code 9E5Z-13405-ACP.'),
  ('foglamp-cd338',          'fog-lights',        'Duman farası, ön (sol və ya sağ)',                            'Противотуманная фара передняя (левая или правая)',                   'Front fog lamp assembly (left or right)',                          'Ford', '6E5Z-15200-A',     'Ford', 'FRONT',       'One number for both sides, qty 2; cars equipped with front fog lamps, MY2006-2012. Bulb H11 (BM5Z-13N021-B, formerly 2C5Z-13N021-AA). Crash-part code 6E5Z-15200-ACP.'),
  ('front-bumper-1012',      'bumpers',           'Ön bamper, astarlanmış (2010-2012)',                          'Бампер передний, грунтованный (2010-2012)',                          'Front bumper cover, primed (2010-2012)',                           'Ford', 'AE5Z-17D957-BAPTM','Ford', 'FRONT',       'Paint-to-match cover, one part for every trim and engine incl. Sport and Hybrid; trim differences sit in the separate grilles and fog bezels. Crash-part code AE5Z-17D957-BACP.'),
  ('rear-bumper-1012',       'bumpers',           'Arxa bamper, astarlanmış (2010-2012)',                        'Бампер задний, грунтованный (2010-2012)',                            'Rear bumper cover, primed (2010-2012)',                            'Ford', 'AE5Z-17K835-AAPTM','Ford', 'REAR',        'Paint-to-match cover, every trim; park-aid sensor holes are drilled out on cars with park aid. Exhaust openings come from the separate stone deflector (AE5Z-17808-AA I4, -BA 3.0, -BB styling kit). Crash-part code AE5Z-17K835-AACP.'),
  ('fender-r-1012',          'fenders',           'Ön qanad, sağ (2010-2012)',                                   'Крыло переднее правое (2010-2012)',                                  'Front fender, right (2010-2012)',                                  'Ford', 'AE5Z-16005-A',     'Ford', 'FRONT_RIGHT', 'Every trim; also the 2010-2011 Mercury Milan.'),
  ('fender-l-1012',          'fenders',           'Ön qanad, sol (2010-2012)',                                   'Крыло переднее левое (2010-2012)',                                   'Front fender, left (2010-2012)',                                   'Ford', 'AE5Z-16006-A',     'Ford', 'FRONT_LEFT',  'Every trim.'),
  ('hood-1012',              'hoods',             'Kapot (2010-2012)',                                           'Капот (2010-2012)',                                                  'Hood panel (2010-2012)',                                           'Ford', 'BE5Z-16612-A',     'Ford', 'FRONT',       'Every trim; supersedes 9E5Z-16612-A. Hood insulator by engine: 9E5Z-16738-A (2.5), -B (3.0 / 3.5), -C (Hybrid).'),
  ('grille-upper-1012',      'grilles',           'Radiator barmaqlığı, üst bar, xrom (2010-2012)',              'Решётка радиатора, верхняя планка, хром (2010-2012)',                'Radiator grille, upper bar, bright chrome (2010-2012)',            'Ford', 'AE5Z-8200-C',      'Ford', 'FRONT',       'The three-bar grille is serviced as three bars. S / SE / SEL / Hybrid; Sport uses Shadow Chrome bars. Painted body-colour version AE5Z-8200-EAPTM. Crash-part code AE5Z-8200-CCP.'),
  ('grille-center-1012',     'grilles',           'Radiator barmaqlığı, orta bar, xrom (2010-2012)',             'Решётка радиатора, средняя планка, хром (2010-2012)',                'Radiator grille, middle bar, bright chrome (2010-2012)',           'Ford', 'AE5Z-8200-A',      'Ford', 'FRONT',       'S / SE / SEL / Hybrid. Painted version AE5Z-8200-BAPTM. Crash-part code AE5Z-8200-ACP.'),
  ('grille-lower-1012',      'grilles',           'Radiator barmaqlığı, alt bar, xrom (2010-2012)',              'Решётка радиатора, нижняя планка, хром (2010-2012)',                 'Radiator grille, lower bar, bright chrome (2010-2012)',            'Ford', 'AE5Z-8200-B',      'Ford', 'FRONT',       'S / SE / SEL / Hybrid. Painted version AE5Z-8200-CAPTM. Crash-part code AE5Z-8200-BCP.'),
  ('grille-upper-sport',     'grilles',           'Radiator barmaqlığı, üst bar, Shadow Chrome (Sport)',         'Решётка радиатора, верхняя планка, Shadow Chrome (Sport)',           'Radiator grille, upper bar, Shadow Chrome (Sport)',                'Ford', 'BE5Z-8200-AA',     'Ford', 'FRONT',       'Fusion Sport; on cars built 04/2011-10/2011 Ford replaces all three bars together. MY2010 Sport grille unconfirmed (may use the bright bars).'),
  ('grille-center-sport',    'grilles',           'Radiator barmaqlığı, orta bar, Shadow Chrome (Sport)',        'Решётка радиатора, средняя планка, Shadow Chrome (Sport)',           'Radiator grille, middle bar, Shadow Chrome (Sport)',               'Ford', 'BE5Z-8200-BA',     'Ford', 'FRONT',       'Fusion Sport MY2011-2012. Discontinued at Ford.'),
  ('grille-lower-sport',     'grilles',           'Radiator barmaqlığı, alt bar, Shadow Chrome (Sport)',         'Решётка радиатора, нижняя планка, Shadow Chrome (Sport)',            'Radiator grille, lower bar, Shadow Chrome (Sport)',                'Ford', 'BE5Z-8200-CA',     'Ford', 'FRONT',       'Fusion Sport MY2011-2012. Discontinued at Ford.'),
  ('bumper-grille-1012',     'grilles',           'Ön bamperin alt barmaqlığı (2010-2012)',                      'Решётка переднего бампера нижняя (2010-2012)',                       'Front bumper lower grille insert (2010-2012)',                     'Ford', 'AE5Z-8200-DA',     'Ford', 'FRONT',       'S / SE / SEL / Hybrid. Crash-part code AE5Z-8200-DACP.'),
  ('bumper-grille-sport',    'grilles',           'Ön bamperin alt barmaqlığı, qara (Sport)',                    'Решётка переднего бампера нижняя, чёрная (Sport)',                   'Front bumper lower grille insert, black (Sport)',                  'Ford', 'AE5Z-8200-DB',     'Ford', 'FRONT',       'Fusion Sport MY2010-2012. Crash-part code AE5Z-8200-DBCP.'),
  ('bumper-grille-trim-1012','grilles',           'Alt barmaqlıq haşiyəsi, xrom (2010-2012)',                    'Окантовка нижней решётки бампера, хром (2010-2012)',                 'Front lower grille surround moulding, chrome (2010-2012)',         'Ford', 'AE5Z-17K945-A',    'Ford', 'FRONT',       'S / SE / SEL / Hybrid. Crash-part code AE5Z-17K945-ACP.'),
  ('bumper-grille-trim-sport','grilles',          'Alt barmaqlıq haşiyəsi (Sport)',                              'Окантовка нижней решётки бампера (Sport)',                           'Front lower grille surround moulding (Sport)',                     'Ford', 'BE5Z-17K945-AA',   'Ford', 'FRONT',       'Fusion Sport MY2011-2012. Currently unavailable at Ford.'),
  ('mirror-r-power-1112',    'mirrors',           'Yan güzgü, sağ, elektrik (2011-2012)',                        'Зеркало наружное правое, электро (2011-2012)',                       'Door mirror, right, power, not heated, without BLIS (2011-2012)',  'Ford', 'BE5Z-17682-AA',    'Ford', 'FRONT_RIGHT', 'Cars built from 07/2010. Mirror cover sold separately (6E5Z-17D742-AA black, 6E5Z-17D742-BPTM paint-to-match). Crash-part code BE5Z-17682-AACP.'),
  ('mirror-l-power-1112',    'mirrors',           'Yan güzgü, sol, elektrik (2011-2012)',                        'Зеркало наружное левое, электро (2011-2012)',                        'Door mirror, left, power, not heated, without BLIS (2011-2012)',   'Ford', 'BE5Z-17683-AA',    'Ford', 'FRONT_LEFT',  'Cars built from 07/2010. Cover sold separately (6E5Z-17D743-AA / -BPTM). Crash-part code BE5Z-17683-AACP.'),
  ('mirror-r-heated-puddle-1112','mirrors',       'Yan güzgü, sağ, qızdırıcılı, işıqlı (2011-2012)',             'Зеркало наружное правое, с обогревом и подсветкой (2011-2012)',      'Door mirror, right, power, heated, puddle lamp, without BLIS (2011-2012)', 'Ford', 'BE5Z-17682-BA', 'Ford', 'FRONT_RIGHT', 'Discontinued at Ford. Crash-part code BE5Z-17682-BACP.'),
  ('mirror-l-heated-puddle-1112','mirrors',       'Yan güzgü, sol, qızdırıcılı, işıqlı (2011-2012)',             'Зеркало наружное левое, с обогревом и подсветкой (2011-2012)',       'Door mirror, left, power, heated, puddle lamp, without BLIS (2011-2012)',  'Ford', 'BE5Z-17683-BA', 'Ford', 'FRONT_LEFT',  'Discontinued at Ford. Crash-part code BE5Z-17683-BACP.'),
  ('mirror-r-heated-1112',   'mirrors',           'Yan güzgü, sağ, qızdırıcılı (2011-2012)',                     'Зеркало наружное правое, с обогревом (2011-2012)',                   'Door mirror, right, power, heated, without BLIS (2011-2012)',      'Ford', 'BE5Z-17682-CA',    'Ford', 'FRONT_RIGHT', 'Ford option text "electric / heated"; no puddle lamp mentioned.'),
  ('mirror-l-heated-1112',   'mirrors',           'Yan güzgü, sol, qızdırıcılı (2011-2012)',                     'Зеркало наружное левое, с обогревом (2011-2012)',                    'Door mirror, left, power, heated, without BLIS (2011-2012)',       'Ford', 'BE5Z-17683-CA',    'Ford', 'FRONT_LEFT',  'Ford option text "electric / heated"; no puddle lamp mentioned.'),
  ('mirror-r-blis-1012',     'mirrors',           'Yan güzgü, sağ, qızdırıcılı, işıqlı, BLIS (2010-2012)',       'Зеркало наружное правое, обогрев, подсветка, BLIS (2010-2012)',      'Door mirror, right, power, heated, puddle lamp, BLIS (2010-2012)', 'Ford', '9E5Z-17682-B',     'Ford', 'FRONT_RIGHT', 'Blind-spot (BLIS) mirror; cars built from 05/2010, earlier builds 9E5Z-17682-A. Discontinued at Ford. Crash-part code 9E5Z-17682-BCP.'),
  ('mirror-l-blis-1012',     'mirrors',           'Yan güzgü, sol, qızdırıcılı, işıqlı, BLIS (2010-2012)',       'Зеркало наружное левое, обогрев, подсветка, BLIS (2010-2012)',       'Door mirror, left, power, heated, puddle lamp, BLIS (2010-2012)',  'Ford', '9E5Z-17683-B',     'Ford', 'FRONT_LEFT',  'Blind-spot (BLIS) mirror; cars built from 05/2010, earlier builds 9E5Z-17683-A. Crash-part code 9E5Z-17683-BCP.'),
  ('radiator-support-1012',  'radiator-supports', 'Radiator dayağı, ön panel (2.5 / 3.0, 2010-2012)',            'Панель передняя, рамка радиатора (2.5 / 3.0, 2010-2012)',            'Radiator support, front end panel (2.5 / 3.0, 2010-2012)',         'Ford', 'AE5Z-16138-A',     'Ford', 'FRONT',       'S / SE / SEL with the 2.5 or 3.0; Hybrid and Sport use their own. Crash-part code AE5Z-16138-ACP.'),
  ('radiator-support-hev-1012','radiator-supports','Radiator dayağı, ön panel (Hybrid, 2010-2012)',              'Панель передняя, рамка радиатора (Hybrid, 2010-2012)',               'Radiator support, front end panel (Hybrid, 2010-2012)',            'Ford', 'AE5Z-16138-B',     'Ford', 'FRONT',       'Fusion Hybrid only. Currently unavailable at Ford.'),
  ('radiator-support-sport-1012','radiator-supports','Radiator dayağı, ön panel (Sport 3.5, 2010-2012)',          'Панель передняя, рамка радиатора (Sport 3.5, 2010-2012)',            'Radiator support, front end panel (Sport 3.5, 2010-2012)',         'Ford', 'AH6Z-16138-A',     'Ford', 'FRONT',       'Fusion Sport 3.5; shared with the Lincoln MKZ 3.5.'),
  ('trunk-lid-1012',         'trunk-lids',        'Baqaj qapağı, spoylersiz (2010-2012)',                        'Крышка багажника, без спойлера (2010-2012)',                         'Trunk lid, without spoiler (2010-2012)',                           'Ford', '9E5Z-5440110-A',   'Ford', 'REAR',        'Every trim without the rear spoiler.'),
  ('trunk-lid-spoiler-1012', 'trunk-lids',        'Baqaj qapağı, spoyler dəlikli (2010-2012)',                   'Крышка багажника, с отверстиями под спойлер (2010-2012)',            'Trunk lid, with rear spoiler holes (2010-2012)',                   'Ford', '9E5Z-5440110-B',   'Ford', 'REAR',        'Every trim with the single rear wing spoiler.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('headlamp-r-1012',        '9E5Z-13008-ACP',     'OEM', 'Ford'),
  ('headlamp-r-1012',        'FO2503273C',         'AFTERMARKET', 'Partslink (CAPA)'),
  ('headlamp-r-1012',        'SET-REPF100115Q',    'AFTERMARKET', 'Replacement (CarParts.com), pair'),
  ('headlamp-l-1012',        '9E5Z-13008-BCP',     'OEM', 'Ford'),
  ('headlamp-l-1012',        'FO2502273C',         'AFTERMARKET', 'Partslink (CAPA)'),
  ('headlamp-l-1012',        'SET-REPF100115Q',    'AFTERMARKET', 'Replacement (CarParts.com), pair'),
  ('taillamp-r-1012',        '9E5Z-13404-ACP',     'OEM', 'Ford'),
  ('taillamp-l-1012',        '9E5Z-13405-ACP',     'OEM', 'Ford'),
  ('foglamp-cd338',          '6E5Z-15200-ACP',     'OEM', 'Ford'),
  ('front-bumper-1012',      'AE5Z-17D957-BACP',   'OEM', 'Ford'),
  ('front-bumper-1012',      'FO1000650',          'AFTERMARKET', 'Partslink'),
  ('rear-bumper-1012',       'AE5Z-17K835-AACP',   'OEM', 'Ford'),
  ('hood-1012',              '9E5Z-16612-A',       'OEM', 'Ford'),
  ('grille-upper-1012',      'AE5Z-8200-CCP',      'OEM', 'Ford'),
  ('grille-center-1012',     'AE5Z-8200-ACP',      'OEM', 'Ford'),
  ('grille-lower-1012',      'AE5Z-8200-BCP',      'OEM', 'Ford'),
  ('bumper-grille-1012',     'AE5Z-8200-DACP',     'OEM', 'Ford'),
  ('bumper-grille-sport',    'AE5Z-8200-DBCP',     'OEM', 'Ford'),
  ('bumper-grille-trim-1012','AE5Z-17K945-ACP',    'OEM', 'Ford'),
  ('mirror-r-power-1112',    'BE5Z-17682-AACP',    'OEM', 'Ford'),
  ('mirror-l-power-1112',    'BE5Z-17683-AACP',    'OEM', 'Ford'),
  ('mirror-r-heated-puddle-1112', 'BE5Z-17682-BACP', 'OEM', 'Ford'),
  ('mirror-l-heated-puddle-1112', 'BE5Z-17683-BACP', 'OEM', 'Ford'),
  ('mirror-r-blis-1012',     '9E5Z-17682-A',       'OEM', 'Ford'),
  ('mirror-r-blis-1012',     '9E5Z-17682-BCP',     'OEM', 'Ford'),
  ('mirror-l-blis-1012',     '9E5Z-17683-A',       'OEM', 'Ford'),
  ('mirror-l-blis-1012',     '9E5Z-17683-BCP',     'OEM', 'Ford'),
  ('radiator-support-1012',  'AE5Z-16138-ACP',     'OEM', 'Ford');

INSERT INTO seed_fits (key, generation_slug, year_from, year_to, engine_code, trims, notes) VALUES
  ('headlamp-r-1012',        'cd338', 2010, 2012, NULL, NULL, NULL),
  ('headlamp-l-1012',        'cd338', 2010, 2012, NULL, NULL, NULL),
  ('taillamp-r-1012',        'cd338', 2010, 2012, NULL, NULL, NULL),
  ('taillamp-l-1012',        'cd338', 2010, 2012, NULL, NULL, NULL),
  ('foglamp-cd338',          'cd338', 2006, 2012, NULL, NULL, 'Cars equipped with front fog lamps'),
  ('front-bumper-1012',      'cd338', 2010, 2012, NULL, NULL, NULL),
  ('rear-bumper-1012',       'cd338', 2010, 2012, NULL, NULL, 'Park-aid cars: drill out the sensor holes'),
  ('fender-r-1012',          'cd338', 2010, 2012, NULL, NULL, NULL),
  ('fender-l-1012',          'cd338', 2010, 2012, NULL, NULL, NULL),
  ('hood-1012',              'cd338', 2010, 2012, NULL, NULL, NULL),
  ('grille-upper-1012',      'cd338', 2010, 2012, NULL, ARRAY['S','SE','SEL','Hybrid'], NULL),
  ('grille-center-1012',     'cd338', 2010, 2012, NULL, ARRAY['S','SE','SEL','Hybrid'], NULL),
  ('grille-lower-1012',      'cd338', 2010, 2012, NULL, ARRAY['S','SE','SEL','Hybrid'], NULL),
  ('grille-upper-sport',     'cd338', 2011, 2012, NULL, ARRAY['Sport'], 'MY2010 Sport unconfirmed'),
  ('grille-center-sport',    'cd338', 2011, 2012, NULL, ARRAY['Sport'], NULL),
  ('grille-lower-sport',     'cd338', 2011, 2012, NULL, ARRAY['Sport'], NULL),
  ('bumper-grille-1012',     'cd338', 2010, 2012, NULL, ARRAY['S','SE','SEL','Hybrid'], NULL),
  ('bumper-grille-sport',    'cd338', 2010, 2012, NULL, ARRAY['Sport'], NULL),
  ('bumper-grille-trim-1012','cd338', 2010, 2012, NULL, ARRAY['S','SE','SEL','Hybrid'], NULL),
  ('bumper-grille-trim-sport','cd338', 2011, 2012, NULL, ARRAY['Sport'], NULL),
  ('mirror-r-power-1112',    'cd338', 2011, 2012, NULL, NULL, 'Power, not heated, without BLIS'),
  ('mirror-l-power-1112',    'cd338', 2011, 2012, NULL, NULL, 'Power, not heated, without BLIS'),
  ('mirror-r-heated-puddle-1112', 'cd338', 2011, 2012, NULL, NULL, 'Heated with puddle lamp, without BLIS'),
  ('mirror-l-heated-puddle-1112', 'cd338', 2011, 2012, NULL, NULL, 'Heated with puddle lamp, without BLIS'),
  ('mirror-r-heated-1112',   'cd338', 2011, 2012, NULL, NULL, 'Heated, without BLIS'),
  ('mirror-l-heated-1112',   'cd338', 2011, 2012, NULL, NULL, 'Heated, without BLIS'),
  ('mirror-r-blis-1012',     'cd338', 2010, 2012, NULL, NULL, 'Cars with BLIS blind-spot mirrors'),
  ('mirror-l-blis-1012',     'cd338', 2010, 2012, NULL, NULL, 'Cars with BLIS blind-spot mirrors'),
  ('radiator-support-1012',  'cd338', 2010, 2012, NULL, ARRAY['S','SE','SEL'], NULL),
  ('radiator-support-hev-1012','cd338', 2010, 2012, NULL, ARRAY['Hybrid'], NULL),
  ('radiator-support-sport-1012','cd338', 2010, 2012, NULL, ARRAY['Sport'], NULL),
  ('trunk-lid-1012',         'cd338', 2010, 2012, NULL, NULL, 'Without rear spoiler'),
  ('trunk-lid-spoiler-1012', 'cd338', 2010, 2012, NULL, NULL, 'With rear spoiler');

-- ---------- CD391 facelift, MY2017-2020 (carry-over parts span back to MY2013 where Ford says so) ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  ('headlamp-l-hal-1720',     'headlights',  'Fara, sol, halogen, signature işıqsız (2017-2020)',             'Фара левая, галоген, без световой подписи (2017-2020)',             'Headlamp assembly, left, halogen without signature lamps (2017-2020)',   'Ford', 'HS7Z-13008-E',  'Ford', 'FRONT_LEFT',  'Ford note "Halogen, Without Signature Lamps". Bulbs H11 low, H9 high, PWY24W amber. Cars built from 04/2016.'),
  ('headlamp-r-hal-1720',     'headlights',  'Fara, sağ, halogen, signature işıqsız (2017-2020)',             'Фара правая, галоген, без световой подписи (2017-2020)',            'Headlamp assembly, right, halogen without signature lamps (2017-2020)',  'Ford', 'HS7Z-13008-D',  'Ford', 'FRONT_RIGHT', 'Ford note "Halogen, Without Signature Lamps". Bulbs H11 low, H9 high, PWY24W amber.'),
  ('headlamp-l-halsig-1720',  'headlights',  'Fara, sol, halogen, LED signature işıqlı (2017-2020)',          'Фара левая, галоген, со световой подписью LED (2017-2020)',         'Headlamp assembly, left, halogen with LED signature lamps (2017-2020)',  'Ford', 'HS7Z-13008-H',  'Ford', 'FRONT_LEFT',  'Ford note "Halogen, With Signature Lamps". Cars built from 04/2016.'),
  ('headlamp-r-halsig-1720',  'headlights',  'Fara, sağ, halogen, LED signature işıqlı (2017-2020)',          'Фара правая, галоген, со световой подписью LED (2017-2020)',        'Headlamp assembly, right, halogen with LED signature lamps (2017-2020)', 'Ford', 'HS7Z-13008-G',  'Ford', 'FRONT_RIGHT', 'Ford note "Halogen, With Signature Lamps".'),
  ('headlamp-l-led-1720',     'headlights',  'Fara, sol, LED (2017-2020)',                                    'Фара левая, LED (2017-2020)',                                        'Headlamp assembly, left, LED (2017-2020)',                               'Ford', 'HS7Z-13008-AA', 'Ford', 'FRONT_LEFT',  'One number for the fixed and the adaptive (road-following) LED headlamp. Supersedes HS7Z-13008-C and HS7Z-13008-Z. Lighting control module DG9Z-13C788-J.'),
  ('headlamp-r-led-1720',     'headlights',  'Fara, sağ, LED (2017-2020)',                                    'Фара правая, LED (2017-2020)',                                       'Headlamp assembly, right, LED (2017-2020)',                              'Ford', 'HS7Z-13008-AB', 'Ford', 'FRONT_RIGHT', 'One number for the fixed and the adaptive LED headlamp. Supersedes HS7Z-13008-F and HS7Z-13008-Y.'),
  ('taillamp-outer-l-1720',   'tail-lights', 'Arxa fənər, xarici, sol (2017-2020)',                           'Фонарь задний наружный, левый (2017-2020)',                          'Tail lamp assembly, outer (quarter panel), left (2017-2020)',            'Ford', 'HS7Z-13405-J',  'Ford', 'REAR_LEFT',   'One outer lamp for every 2017-2020 trim. Supersedes HS7Z-13405-D and HS7Z-13405-F.'),
  ('taillamp-outer-r-1720',   'tail-lights', 'Arxa fənər, xarici, sağ (2017-2020)',                           'Фонарь задний наружный, правый (2017-2020)',                         'Tail lamp assembly, outer (quarter panel), right (2017-2020)',           'Ford', 'HS7Z-13404-J',  'Ford', 'REAR_RIGHT',  'One outer lamp for every 2017-2020 trim. Supersedes HS7Z-13404-D and HS7Z-13404-F.'),
  ('taillamp-inner-l-a-1718', 'tail-lights', 'Arxa fənər, daxili (baqaj qapağı), sol, tip A (2017-2018)',     'Фонарь задний внутренний (крышка багажника), левый, тип A (2017-2018)', 'Tail lamp, inner (trunk lid), left, type A (2017-2018)',             'Ford', 'HS7Z-13405-A',  'Ford', 'REAR_LEFT',   'Cars built 04/2016-08/2018. Ford merges the "Level 1 / Level 3" notes; sellers list type A as the halogen Level 1 lamp (unverified).'),
  ('taillamp-inner-r-a-1718', 'tail-lights', 'Arxa fənər, daxili (baqaj qapağı), sağ, tip A (2017-2018)',     'Фонарь задний внутренний (крышка багажника), правый, тип A (2017-2018)', 'Tail lamp, inner (trunk lid), right, type A (2017-2018)',           'Ford', 'HS7Z-13404-A',  'Ford', 'REAR_RIGHT',  'Cars built 04/2016-08/2018. Sellers list type A as the halogen Level 1 lamp (unverified).'),
  ('taillamp-inner-l-h-1718', 'tail-lights', 'Arxa fənər, daxili (baqaj qapağı), sol, tip H (2017-2018)',     'Фонарь задний внутренний (крышка багажника), левый, тип H (2017-2018)', 'Tail lamp, inner (trunk lid), left, type H (2017-2018)',             'Ford', 'HS7Z-13405-H',  'Ford', 'REAR_LEFT',   'Cars built 03/2017-08/2018; supersedes HS7Z-13405-B. Sellers list type H as the LED Level 3 lamp (unverified).'),
  ('taillamp-inner-r-h-1718', 'tail-lights', 'Arxa fənər, daxili (baqaj qapağı), sağ, tip H (2017-2018)',     'Фонарь задний внутренний (крышка багажника), правый, тип H (2017-2018)', 'Tail lamp, inner (trunk lid), right, type H (2017-2018)',           'Ford', 'HS7Z-13404-H',  'Ford', 'REAR_RIGHT',  'Cars built 03/2017-08/2018; supersedes HS7Z-13404-B. Sellers list type H as the LED Level 3 lamp (unverified).'),
  ('taillamp-inner-l-j-1920', 'tail-lights', 'Arxa fənər, daxili (baqaj qapağı), sol, tip J (2019-2020)',     'Фонарь задний внутренний (крышка багажника), левый, тип J (2019-2020)', 'Tail lamp, inner (trunk lid), left, type J (2019-2020)',             'Ford', 'KS7Z-13405-J',  'Ford', 'REAR_LEFT',   'Cars built from 08/2018; supersedes KS7Z-13405-F (the lower-priced of the two 2019-2020 inner lamps, listed by sellers as halogen).'),
  ('taillamp-inner-r-f-1920', 'tail-lights', 'Arxa fənər, daxili (baqaj qapağı), sağ, tip F (2019-2020)',     'Фонарь задний внутренний (крышка багажника), правый, тип F (2019-2020)', 'Tail lamp, inner (trunk lid), right, type F (2019-2020)',           'Ford', 'KS7Z-13404-F',  'Ford', 'REAR_RIGHT',  'Cars built from 08/2018; supersedes KS7Z-13404-D (lower-priced variant, listed by sellers as halogen).'),
  ('taillamp-inner-l-k-1920', 'tail-lights', 'Arxa fənər, daxili (baqaj qapağı), sol, tip K (2019-2020)',     'Фонарь задний внутренний (крышка багажника), левый, тип K (2019-2020)', 'Tail lamp, inner (trunk lid), left, type K (2019-2020)',             'Ford', 'KS7Z-13405-K',  'Ford', 'REAR_LEFT',   'Cars built from 08/2018; supersedes KS7Z-13405-G (the higher-priced variant, listed by sellers as LED).'),
  ('taillamp-inner-r-g-1920', 'tail-lights', 'Arxa fənər, daxili (baqaj qapağı), sağ, tip G (2019-2020)',     'Фонарь задний внутренний (крышка багажника), правый, тип G (2019-2020)', 'Tail lamp, inner (trunk lid), right, type G (2019-2020)',           'Ford', 'KS7Z-13404-G',  'Ford', 'REAR_RIGHT',  'Cars built from 08/2018; supersedes KS7Z-13404-E and KS7Z-13404-B (higher-priced variant, listed by sellers as LED).'),
  ('foglamp-l-1718',          'fog-lights',  'Duman farası, sol (2017-2018)',                                 'Противотуманная фара левая (2017-2018)',                             'Fog lamp assembly, left (2017-2018)',                                    'Ford', 'HS7Z-15201-A',  'Ford', 'FRONT_LEFT',  'Every trim except Sport. Bulb 1S7Z-13466-DA.'),
  ('foglamp-r-1718',          'fog-lights',  'Duman farası, sağ (2017-2018)',                                 'Противотуманная фара правая (2017-2018)',                            'Fog lamp assembly, right (2017-2018)',                                   'Ford', 'HS7Z-15200-A',  'Ford', 'FRONT_RIGHT', 'Every trim except Sport. Bulb 1S7Z-13466-DA.'),
  ('foglamp-l-sport-1719',    'fog-lights',  'Duman farası, sol (Sport, 2017-2019)',                          'Противотуманная фара левая (Sport, 2017-2019)',                      'Fog lamp assembly, left (Sport, 2017-2019)',                             'Ford', 'HS7Z-15201-G',  'Ford', 'FRONT_LEFT',  'Fusion Sport. Supersedes HS7Z-15201-B.'),
  ('foglamp-r-sport-1719',    'fog-lights',  'Duman farası, sağ (Sport, 2017-2019)',                          'Противотуманная фара правая (Sport, 2017-2019)',                     'Fog lamp assembly, right (Sport, 2017-2019)',                            'Ford', 'HS7Z-15200-G',  'Ford', 'FRONT_RIGHT', 'Fusion Sport. Supersedes HS7Z-15200-B.'),
  ('foglamp-l-hal-1920',      'fog-lights',  'Duman farası, sol, halogen (2019-2020)',                        'Противотуманная фара левая, галоген (2019-2020)',                    'Fog lamp assembly, left, halogen (2019-2020)',                           'Ford', 'KS7Z-15201-A',  'Ford', 'FRONT_LEFT',  'Ford note "2019-20, Halogen".'),
  ('foglamp-r-hal-1920',      'fog-lights',  'Duman farası, sağ, halogen (2019-2020)',                        'Противотуманная фара правая, галоген (2019-2020)',                   'Fog lamp assembly, right, halogen (2019-2020)',                          'Ford', 'KS7Z-15200-A',  'Ford', 'FRONT_RIGHT', 'Ford note "2019-20, Halogen".'),
  ('foglamp-l-led-1920',      'fog-lights',  'Duman farası, sol, LED (2019-2020)',                            'Противотуманная фара левая, LED (2019-2020)',                        'Fog lamp assembly, left, LED (2019-2020)',                               'Ford', 'KS7Z-15201-B',  'Ford', 'FRONT_LEFT',  'Ford note "2019-20, LED".'),
  ('foglamp-r-led-1920',      'fog-lights',  'Duman farası, sağ, LED (2019-2020)',                            'Противотуманная фара правая, LED (2019-2020)',                       'Fog lamp assembly, right, LED (2019-2020)',                              'Ford', 'KS7Z-15200-B',  'Ford', 'FRONT_RIGHT', 'Ford note "2019-20, LED".'),
  ('fbumper-1718',            'bumpers',     'Ön bamper, astarlanmış (2017-2018)',                            'Бампер передний, грунтованный (2017-2018)',                          'Front bumper cover, primed (2017-2018)',                                 'Ford', 'HS7Z-17D957-APTM', 'Ford', 'FRONT',    'Not Sport; without Auto Park sensors, without tow hook opening. Paint to match. Crash-part code HS7Z-17D957-ACP.'),
  ('fbumper-park-1718',       'bumpers',     'Ön bamper, astarlanmış, Auto Park sensorlu (2017-2018)',        'Бампер передний, грунтованный, с датчиками Auto Park (2017-2018)',   'Front bumper cover, primed, Auto Park sensors (2017-2018)',              'Ford', 'HS7Z-17D957-AAPTM','Ford', 'FRONT',    'Not Sport; with Auto Park, without tow hook opening.'),
  ('fbumper-tow-1718',        'bumpers',     'Ön bamper, astarlanmış, yedək qarmaq dəlikli (2017-2018)',      'Бампер передний, грунтованный, с проёмом буксирного крюка (2017-2018)', 'Front bumper cover, primed, tow hook opening (2017-2018)',            'Ford', 'HS7Z-17D957-BBPTM','Ford', 'FRONT',    'Not Sport; without Auto Park, with tow hook opening.'),
  ('fbumper-park-tow-1718',   'bumpers',     'Ön bamper, astarlanmış, Auto Park + yedək qarmaq (2017-2018)',  'Бампер передний, грунтованный, Auto Park + буксирный крюк (2017-2018)', 'Front bumper cover, primed, Auto Park sensors and tow hook (2017-2018)', 'Ford', 'HS7Z-17D957-CBPTM','Ford', 'FRONT',   'Not Sport; with Auto Park and tow hook opening.'),
  ('fbumper-sport-1719',      'bumpers',     'Ön bamper, astarlanmış (Sport, 2017-2019)',                     'Бампер передний, грунтованный (Sport, 2017-2019)',                   'Front bumper cover, primed (Sport, 2017-2019)',                          'Ford', 'HS7Z-17D957-VAPTM','Ford', 'FRONT',    'Fusion Sport fascia, without Auto Park.'),
  ('fbumper-sport-park-1719', 'bumpers',     'Ön bamper, astarlanmış, Auto Park (Sport, 2017-2019)',          'Бампер передний, грунтованный, Auto Park (Sport, 2017-2019)',        'Front bumper cover, primed, Auto Park sensors (Sport, 2017-2019)',       'Ford', 'HS7Z-17D957-VBPTM','Ford', 'FRONT',    'Fusion Sport fascia, with Auto Park. Service only.'),
  ('fbumper-1920',            'bumpers',     'Ön bamper, astarlanmış (2019-2020)',                            'Бампер передний, грунтованный (2019-2020)',                          'Front bumper cover, primed (2019-2020)',                                 'Ford', 'KS7Z-17D957-ADPTM','Ford', 'FRONT',    'MY2019 revised fascia; without Auto Park, without tow hook opening.'),
  ('fbumper-park-1920',       'bumpers',     'Ön bamper, astarlanmış, Auto Park sensorlu (2019-2020)',        'Бампер передний, грунтованный, с датчиками Auto Park (2019-2020)',   'Front bumper cover, primed, Auto Park sensors (2019-2020)',              'Ford', 'KS7Z-17D957-SAPTM','Ford', 'FRONT',    'With Auto Park sensor retainers, without tow hook opening.'),
  ('fbumper-tow-1920',        'bumpers',     'Ön bamper, astarlanmış, yedək qarmaq dəlikli (2019-2020)',      'Бампер передний, грунтованный, с проёмом буксирного крюка (2019-2020)', 'Front bumper cover, primed, tow hook opening (2019-2020)',            'Ford', 'KS7Z-17D957-SBPTM','Ford', 'FRONT',    'Without Auto Park, with tow hook opening.'),
  ('fbumper-park-tow-1920',   'bumpers',     'Ön bamper, astarlanmış, Auto Park + yedək qarmaq (2019-2020)',  'Бампер передний, грунтованный, Auto Park + буксирный крюк (2019-2020)', 'Front bumper cover, primed, Auto Park sensors and tow hook (2019-2020)', 'Ford', 'KS7Z-17D957-SCPTM','Ford', 'FRONT',   'With Auto Park sensor retainers and tow hook opening.'),
  ('rbumper-nosensor-1318',   'bumpers',     'Arxa bamper, astarlanmış, sensorsuz (2013-2018)',               'Бампер задний, грунтованный, без датчиков (2013-2018)',              'Rear bumper cover, primed, without park sensor holes (2013-2018)',       'Ford', 'DS7Z-17K835-AAPTM','Ford', 'REAR',     'Every trim incl. Sport; the exhaust cut-outs sit in the separate lower valance (DS7Z-17810-AA single black, -CAPTM single primed, -DAPTM dual primed; Sport HS7Z-17810-VAPTM). Crash-part code DS7Z-17K835-AACP.'),
  ('rbumper-sensor-1318',     'bumpers',     'Arxa bamper, astarlanmış, park sensorlu (2013-2018)',           'Бампер задний, грунтованный, с парктроником (2013-2018)',            'Rear bumper cover, primed, park sensors, without Auto Park (2013-2018)', 'Ford', 'HS7Z-17K835-VFPTM','Ford', 'REAR',     'Sensor retainers welded in. Supersedes ES7Z-17K835-BPTM.'),
  ('rbumper-autopark-1318',   'bumpers',     'Arxa bamper, astarlanmış, park sensorlu + Auto Park (2013-2018)','Бампер задний, грунтованный, парктроник + Auto Park (2013-2018)',    'Rear bumper cover, primed, park sensors and Auto Park (2013-2018)',      'Ford', 'HS7Z-17K835-VEPTM','Ford', 'REAR',     'Six sensor positions. Supersedes DS7Z-17K835-CAPTM.'),
  ('rbumper-nosensor-1920',   'bumpers',     'Arxa bamper, astarlanmış, sensorsuz (2019-2020)',               'Бампер задний, грунтованный, без датчиков (2019-2020)',              'Rear bumper cover, primed, without park sensor holes (2019-2020)',       'Ford', 'KS7Z-17K835-ADPTM','Ford', 'REAR',     'Every trim incl. Sport. Lower valances by exhaust: KS7Z-17F828-CA single, -HA single turned-down, -DA dual, -VA quasi-dual.'),
  ('rbumper-sensor-1920',     'bumpers',     'Arxa bamper, astarlanmış, park sensorlu (2019-2020)',           'Бампер задний, грунтованный, с парктроником (2019-2020)',            'Rear bumper cover, primed, park sensors, without Auto Park (2019-2020)', 'Ford', 'KS7Z-17K835-SAPTM','Ford', 'REAR',     'Four sensor holes.'),
  ('rbumper-autopark-1920',   'bumpers',     'Arxa bamper, astarlanmış, park sensorlu + Auto Park (2019-2020)','Бампер задний, грунтованный, парктроник + Auto Park (2019-2020)',    'Rear bumper cover, primed, park sensors and Auto Park (2019-2020)',      'Ford', 'KS7Z-17K835-SBPTM','Ford', 'REAR',     'Six sensor holes.'),
  ('fender-l-1720',           'fenders',     'Ön qanad, sol (2017-2020)',                                     'Крыло переднее левое (2017-2020)',                                   'Front fender, left (2017-2020)',                                         'Ford', 'HS7Z-16006-A',  'Ford', 'FRONT_LEFT',  'Every trim except the Energi plug-in (which has the charge-port fender HS7Z-16006-B).'),
  ('fender-l-energi-1720',    'fenders',     'Ön qanad, sol, Energi, şarj lyuklu (2017-2020)',                'Крыло переднее левое, Energi, с проёмом лючка зарядки (2017-2020)',  'Front fender, left, Energi with charge-port opening (2017-2020)',        'Ford', 'HS7Z-16006-B',  'Ford', 'FRONT_LEFT',  'Fusion Energi only (Ford option "Plug-In Hybrid").'),
  ('fender-r-1720',           'fenders',     'Ön qanad, sağ (2017-2020)',                                     'Крыло переднее правое (2017-2020)',                                  'Front fender, right (2017-2020)',                                        'Ford', 'HS7Z-16005-A',  'Ford', 'FRONT_RIGHT', 'Every trim incl. Energi.'),
  ('hood-1320',               'hoods',       'Kapot (2013-2020)',                                             'Капот (2013-2020)',                                                  'Hood panel (2013-2020)',                                                 'Ford', 'DS7Z-16612-B',  'Ford', 'FRONT',       'One hood for the whole CD391 run, every trim; supersedes DS7Z-16612-A. 40.6 lb.'),
  ('grille-chrome-1718',      'grilles',     'Radiator barmaqlığı, xrom (2017-2018)',                         'Решётка радиатора, хром (2017-2018)',                                'Upper radiator grille, chrome (2017-2018)',                              'Ford', 'HS7Z-8200-AA',  'Ford', 'FRONT',       'Not Sport. Crash-part code HS7Z-8200-AACP.'),
  ('grille-storm-1718',       'grilles',     'Radiator barmaqlığı, Storm Metallic (2017-2018)',               'Решётка радиатора, Storm Metallic (2017-2018)',                      'Upper radiator grille, Storm Metallic (2017-2018)',                      'Ford', 'HS7Z-8200-BA',  'Ford', 'FRONT',       'Not Sport; Thunder Storm Metallic finish.'),
  ('grille-sport-1719',       'grilles',     'Radiator barmaqlığı, parlaq qara (Sport, 2017-2019)',           'Решётка радиатора, глянцевая чёрная (Sport, 2017-2019)',             'Upper radiator grille, high-gloss black (Sport, 2017-2019)',             'Ford', 'HS7Z-8200-VA',  'Ford', 'FRONT',       'Fusion Sport.'),
  ('grille-chrome-1920',      'grilles',     'Radiator barmaqlığı, xrom (2019-2020)',                         'Решётка радиатора, хром (2019-2020)',                                'Upper radiator grille, chrome, without honeycomb (2019-2020)',           'Ford', 'KS7Z-8200-AC',  'Ford', 'FRONT',       'MY2019 revised grille, not Sport.'),
  ('grille-honeycomb-1920',   'grilles',     'Radiator barmaqlığı, xrom, pətək (2019-2020)',                  'Решётка радиатора, хром, сотовая (2019-2020)',                       'Upper radiator grille, chrome with honeycomb mesh (2019-2020)',          'Ford', 'KS7Z-8200-BB',  'Ford', 'FRONT',       'Not Sport.'),
  ('grille-black-1920',       'grilles',     'Radiator barmaqlığı, parlaq qara (2019-2020)',                  'Решётка радиатора, глянцевая чёрная (2019-2020)',                    'Upper radiator grille, high-gloss black (2019-2020)',                    'Ford', 'KS7Z-8200-DB',  'Ford', 'FRONT',       'Not Sport.'),
  ('lgrille-tex-1718',        'grilles',     'Bamper alt barmaqlığı, qara faktura (2017-2018)',               'Нижняя решётка бампера, чёрная фактурная (2017-2018)',               'Lower grille cover, textured black, no engine heater (2017-2018)',       'Ford', 'HS7Z-17B968-AA','Ford', 'FRONT',       'Not Sport, cars without the engine block heater.'),
  ('lgrille-gloss-1718',      'grilles',     'Bamper alt barmaqlığı, parlaq qara (2017-2018)',                'Нижняя решётка бампера, глянцевая чёрная (2017-2018)',               'Lower grille cover, gloss black, no engine heater (2017-2018)',          'Ford', 'HS7Z-17B968-BA','Ford', 'FRONT',       'Not Sport, cars without the engine block heater.'),
  ('lgrille-tex-heater-1718', 'grilles',     'Bamper alt barmaqlığı, qara faktura, qızdırıcı dəlikli (2017-2018)', 'Нижняя решётка бампера, чёрная фактурная, с подогревателем (2017-2018)', 'Lower grille cover, textured black, engine heater (2017-2018)',     'Ford', 'HS7Z-17B968-DA','Ford', 'FRONT',       'Not Sport, cars with the engine block heater.'),
  ('lgrille-gloss-heater-1718','grilles',    'Bamper alt barmaqlığı, parlaq qara, qızdırıcı dəlikli (2017-2018)', 'Нижняя решётка бампера, глянцевая чёрная, с подогревателем (2017-2018)', 'Lower grille cover, gloss black, engine heater (2017-2018)',          'Ford', 'HS7Z-17B968-EA','Ford', 'FRONT',       'Not Sport, cars with the engine block heater.'),
  ('lgrille-sport-1719',      'grilles',     'Bamper alt barmaqlığı, parlaq qara (Sport, 2017-2019)',         'Нижняя решётка бампера, глянцевая чёрная (Sport, 2017-2019)',        'Lower grille cover, gloss black (Sport, 2017-2019)',                     'Ford', 'HS7Z-17B968-VA','Ford', 'FRONT',       'Fusion Sport without the engine block heater.'),
  ('lgrille-sport-heater-1718','grilles',    'Bamper alt barmaqlığı, qızdırıcı dəlikli (Sport, 2017-2018)',   'Нижняя решётка бампера, с подогревателем (Sport, 2017-2018)',        'Lower grille cover, engine heater (Sport, 2017-2018)',                   'Ford', 'HS7Z-17B968-VB','Ford', 'FRONT',       'Fusion Sport with the engine block heater.'),
  ('lgrille-tex-1920',        'grilles',     'Bamper alt barmaqlığı, qara faktura (2019-2020)',               'Нижняя решётка бампера, чёрная фактурная (2019-2020)',               'Lower grille cover, textured black, no engine heater (2019-2020)',       'Ford', 'KS7Z-17B968-AA','Ford', 'FRONT',       'Not Sport, cars without the engine block heater.'),
  ('lgrille-gloss-1920',      'grilles',     'Bamper alt barmaqlığı, parlaq qara (2019-2020)',                'Нижняя решётка бампера, глянцевая чёрная (2019-2020)',               'Lower grille cover, gloss black, no engine heater (2019-2020)',          'Ford', 'KS7Z-17B968-BA','Ford', 'FRONT',       'Not Sport, cars without the engine block heater.'),
  ('lgrille-tex-heater-1920', 'grilles',     'Bamper alt barmaqlığı, qara faktura, qızdırıcı dəlikli (2019-2020)', 'Нижняя решётка бампера, чёрная фактурная, с подогревателем (2019-2020)', 'Lower grille cover, textured black, engine heater (2019-2020)',     'Ford', 'KS7Z-17B968-DA','Ford', 'FRONT',       'Not Sport, cars with the engine block heater.'),
  ('lgrille-gloss-heater-1920','grilles',    'Bamper alt barmaqlığı, parlaq qara, qızdırıcı dəlikli (2019-2020)', 'Нижняя решётка бампера, глянцевая чёрная, с подогревателем (2019-2020)', 'Lower grille cover, gloss black, engine heater (2019-2020)',          'Ford', 'KS7Z-17B968-EA','Ford', 'FRONT',       'Not Sport, cars with the engine block heater.'),
  ('lgrille-sport-heater-19', 'grilles',     'Bamper alt barmaqlığı, qızdırıcı dəlikli (Sport, 2019)',        'Нижняя решётка бампера, с подогревателем (Sport, 2019)',             'Lower grille cover, engine heater (Sport, 2019)',                        'Ford', 'KS7Z-17B968-VA','Ford', 'FRONT',       'Fusion Sport MY2019 with the engine block heater.'),
  ('mirror-l-base-1320',      'mirrors',     'Yan güzgü, sol, elektrik, qızdırıcısız, dönmə işığısız (2013-2020)', 'Зеркало наружное левое, электро, без обогрева и повторителя (2013-2020)', 'Door mirror, left, power, not heated, no signal lamp (2013-2020)', 'Ford', 'FS7Z-17683-B', 'Ford', 'FRONT_LEFT',  'Ford note "Without Signal Lamp, Without Heat"; supersedes DS7Z-17683-A and FS7Z-17683-A. Caps paint-to-match sold separately (DS7Z-17D743-BAPTM / -AAPTM).'),
  ('mirror-r-base-1320',      'mirrors',     'Yan güzgü, sağ, elektrik, qızdırıcısız, dönmə işığısız (2013-2020)', 'Зеркало наружное правое, электро, без обогрева и повторителя (2013-2020)', 'Door mirror, right, power, not heated, no signal lamp (2013-2020)', 'Ford', 'FS7Z-17682-B', 'Ford', 'FRONT_RIGHT', 'Ford note "Without Signal Lamp, Without Heat"; supersedes DS7Z-17682-A and FS7Z-17682-A. Caps sold separately (DS7Z-17D742-BAPTM / -AAPTM).'),
  ('mirror-l-heat-19',        'mirrors',     'Yan güzgü, sol, qızdırıcılı, dönmə işığısız (2019)',            'Зеркало наружное левое, с обогревом, без повторителя (2019)',        'Door mirror, left, power, heated, no signal lamp (2019)',                'Ford', 'JS7Z-17683-BB', 'Ford', 'FRONT_LEFT',  'Ford note "Without Signal Lamp, With Heat"; on the MY2019 catalog page. Likely supersedes JS7Z-17683-BA (unverified).'),
  ('mirror-r-heat-19',        'mirrors',     'Yan güzgü, sağ, qızdırıcılı, dönmə işığısız (2019)',            'Зеркало наружное правое, с обогревом, без повторителя (2019)',       'Door mirror, right, power, heated, no signal lamp (2019)',               'Ford', 'JS7Z-17682-BB', 'Ford', 'FRONT_RIGHT', 'Ford note "Without Signal Lamp, With Heat"; on the MY2019 catalog page.'),
  ('mirror-l-heat-20',        'mirrors',     'Yan güzgü, sol, qızdırıcılı, dönmə işığısız (2020)',            'Зеркало наружное левое, с обогревом, без повторителя (2020)',        'Door mirror, left, power, heated, no signal lamp (2020)',                'Ford', 'KS7Z-17683-BB', 'Ford', 'FRONT_LEFT',  'Ford note "Without Signal Lamp, With Heat"; on the MY2020 catalog page.'),
  ('mirror-r-heat-20',        'mirrors',     'Yan güzgü, sağ, qızdırıcılı, dönmə işığısız (2020)',            'Зеркало наружное правое, с обогревом, без повторителя (2020)',       'Door mirror, right, power, heated, no signal lamp (2020)',               'Ford', 'KS7Z-17682-BB', 'Ford', 'FRONT_RIGHT', 'Ford note "Without Signal Lamp, With Heat"; on the MY2020 catalog page.'),
  ('mirror-l-sig-1317',       'mirrors',     'Yan güzgü, sol, qızdırıcılı, yaddaşlı, dönmə işıqlı, BLIS-siz (2013-2017)', 'Зеркало наружное левое, обогрев, память, повторитель, без BLIS (2013-2017)', 'Door mirror, left, power, heated, memory, auto-dim, signal lamp, without BLIS or puddle lamp (2013-2017)', 'Ford', 'FS7Z-17683-BC', 'Ford', 'FRONT_LEFT', 'Primed. Ford: "Dual Power / Heat / Mem Electrochromic, Less BLIS"; supersedes DS7Z-17683-BA, DS7Z-17683-BAPTM, FS7Z-17683-BA and FS7Z-17683-BB. MY2018-2020 catalog lists JS7Z-17683-CA.'),
  ('mirror-r-sig-1317',       'mirrors',     'Yan güzgü, sağ, qızdırıcılı, yaddaşlı, dönmə işıqlı, BLIS-siz (2013-2017)', 'Зеркало наружное правое, обогрев, память, повторитель, без BLIS (2013-2017)', 'Door mirror, right, power, heated, memory, auto-dim, signal lamp, without BLIS or puddle lamp (2013-2017)', 'Ford', 'FS7Z-17682-BC', 'Ford', 'FRONT_RIGHT', 'Primed. Ford: "Dual Power / Heat / Mem Electrochromic, Less BLIS"; supersedes DS7Z-17682-BA, DS7Z-17682-BAPTM, FS7Z-17682-BA and FS7Z-17682-BB.'),
  ('mirror-l-sig-1820',       'mirrors',     'Yan güzgü, sol, dönmə işıqlı, BLIS-siz (2018-2020)',            'Зеркало наружное левое, с повторителем, без BLIS (2018-2020)',       'Door mirror, left, signal lamp, without BLIS, without puddle lamp (2018-2020)', 'Ford', 'JS7Z-17683-CA', 'Ford', 'FRONT_LEFT', 'Primed.'),
  ('mirror-r-sig-1820',       'mirrors',     'Yan güzgü, sağ, dönmə işıqlı, BLIS-siz (2018-2020)',            'Зеркало наружное правое, с повторителем, без BLIS (2018-2020)',      'Door mirror, right, signal lamp, without BLIS, without puddle lamp (2018-2020)', 'Ford', 'JS7Z-17682-CA', 'Ford', 'FRONT_RIGHT', 'Primed. Supersedes DS7Z-17682-CA and FS7Z-17682-CA (2013-2015 builds, which Ford notes as the puddle-lamp version); the catalog mirrors disagree on 2013-2016 fitment, so only MY2018-2020 is seeded.'),
  ('mirror-l-sig-puddle-17',  'mirrors',     'Yan güzgü, sol, dönmə işıqlı, işıqlı, BLIS-siz (2017)',         'Зеркало наружное левое, с повторителем и подсветкой, без BLIS (2017)', 'Door mirror, left, signal lamp and puddle lamp, without BLIS (2017)', 'Ford', 'FS7Z-17683-CC', 'Ford', 'FRONT_LEFT',  'Primed. Supersedes FS7Z-17683-CB.'),
  ('mirror-r-sig-puddle-17',  'mirrors',     'Yan güzgü, sağ, dönmə işıqlı, işıqlı, BLIS-siz (2017)',         'Зеркало наружное правое, с повторителем и подсветкой, без BLIS (2017)', 'Door mirror, right, signal lamp and puddle lamp, without BLIS (2017)', 'Ford', 'FS7Z-17682-CC', 'Ford', 'FRONT_RIGHT', 'Primed. Supersedes FS7Z-17682-CB.'),
  ('mirror-l-sig-puddle-1820','mirrors',     'Yan güzgü, sol, dönmə işıqlı, işıqlı, BLIS-siz (2018-2020)',    'Зеркало наружное левое, с повторителем и подсветкой, без BLIS (2018-2020)', 'Door mirror, left, signal lamp and puddle lamp, without BLIS (2018-2020)', 'Ford', 'JS7Z-17683-XB', 'Ford', 'FRONT_LEFT', 'Primed. Supersedes JS7Z-17683-XA (built 08/2017-09/2018). Discontinued at Ford.'),
  ('mirror-r-sig-puddle-1820','mirrors',     'Yan güzgü, sağ, dönmə işıqlı, işıqlı, BLIS-siz (2018-2020)',    'Зеркало наружное правое, с повторителем и подсветкой, без BLIS (2018-2020)', 'Door mirror, right, signal lamp and puddle lamp, without BLIS (2018-2020)', 'Ford', 'JS7Z-17682-XB', 'Ford', 'FRONT_RIGHT', 'Primed. Supersedes JS7Z-17682-XA. Discontinued at Ford.'),
  ('mirror-l-blis-mem-1719',  'mirrors',     'Yan güzgü, sol, dönmə işıqlı, BLIS, yaddaşlı (2017-2019)',      'Зеркало наружное левое, с повторителем, BLIS, память (2017-2019)',   'Door mirror, left, signal lamp, BLIS, memory (2017-2019)',               'Ford', 'JS7Z-17683-DB', 'Ford', 'FRONT_LEFT',  'Supersedes JS7Z-17683-DA and the 2013-2014 left BLIS mirror DS7Z-17683-DA / DS7Z-17683-DAPTM (Ford lists the 2013-2014 fitment only for Police / SSV, so it is not seeded there). Discontinued at Ford.'),
  ('mirror-r-blis-mem-1719',  'mirrors',     'Yan güzgü, sağ, dönmə işıqlı, BLIS, yaddaşlı (2017-2019)',      'Зеркало наружное правое, с повторителем, BLIS, память (2017-2019)',  'Door mirror, right, signal lamp, BLIS, memory (2017-2019)',              'Ford', 'JS7Z-17682-DB', 'Ford', 'FRONT_RIGHT', 'Supersedes JS7Z-17682-DA. Discontinued at Ford.'),
  ('mirror-l-blis-mem-20',    'mirrors',     'Yan güzgü, sol, dönmə işıqlı, BLIS, yaddaşlı (2020)',           'Зеркало наружное левое, с повторителем, BLIS, память (2020)',        'Door mirror, left, signal lamp, BLIS, memory (2020)',                    'Ford', 'KS7Z-17683-DAPTM','Ford', 'FRONT_LEFT', 'Primed; on the MY2020 catalog page.'),
  ('mirror-r-blis-mem-20',    'mirrors',     'Yan güzgü, sağ, dönmə işıqlı, BLIS, yaddaşlı (2020)',           'Зеркало наружное правое, с повторителем, BLIS, память (2020)',       'Door mirror, right, signal lamp, BLIS, memory (2020)',                   'Ford', 'KS7Z-17682-DAPTM','Ford', 'FRONT_RIGHT', 'Primed; on the MY2020 catalog page.'),
  ('mirror-l-blis-1920',      'mirrors',     'Yan güzgü, sol, dönmə işıqlı, BLIS, yaddaşsız (2019-2020)',     'Зеркало наружное левое, с повторителем, BLIS, без памяти (2019-2020)', 'Door mirror, left, signal lamp, BLIS, without memory (2019-2020)',    'Ford', 'KS7Z-17683-ZA', 'Ford', 'FRONT_LEFT',  'On the MY2019 and MY2020 catalog pages.'),
  ('mirror-r-blis-1920',      'mirrors',     'Yan güzgü, sağ, dönmə işıqlı, BLIS, yaddaşsız (2019-2020)',     'Зеркало наружное правое, с повторителем, BLIS, без памяти (2019-2020)', 'Door mirror, right, signal lamp, BLIS, without memory (2019-2020)',   'Ford', 'KS7Z-17682-ZA', 'Ford', 'FRONT_RIGHT', 'On the MY2019 and MY2020 catalog pages.'),
  ('radsupport-upper-i4-1720','radiator-supports', 'Ön modul dayağı, üst (4 silindr / Hybrid, 2017-2020)',    'Усилитель передней панели, верхний (4 цил. / Hybrid, 2017-2020)',    'Front end module bolster, upper radiator support (4-cyl / Hybrid, 2017-2020)', 'Ford', 'HS7Z-16138-A', 'Ford', 'FRONT',    'Ford: "Reinf Assy - Front End Module Bolster"; fit list names the 1.5, 2.0 EcoBoost, 2.5 and 2.0 Hybrid.'),
  ('radsupport-upper-v6-1719','radiator-supports', 'Ön modul dayağı, üst (2.7 V6, 2017-2019)',                'Усилитель передней панели, верхний (2.7 V6, 2017-2019)',             'Front end module bolster, upper radiator support (2.7 V6, 2017-2019)',   'Ford', 'HS7Z-16138-C', 'Ford', 'FRONT',       'Fusion Sport 2.7 EcoBoost.'),
  ('radsupport-lower-i4-1320','radiator-supports', 'Radiator alt dayağı (4 silindr / Hybrid, 2013-2020)',     'Нижняя поперечина радиатора (4 цил. / Hybrid, 2013-2020)',           'Lower radiator support tie bar (4-cyl / Hybrid, 2013-2020)',             'Ford', 'GS7Z-16138-A', 'Ford', 'FRONT',       'Supersedes DS7Z-16138-A; also fits the Lincoln MKZ. Crash-part code GS7Z-16138-ACP.'),
  ('radsupport-lower-v6-1719','radiator-supports', 'Radiator alt dayağı (2.7 V6, 2017-2019)',                 'Нижняя поперечина радиатора (2.7 V6, 2017-2019)',                    'Lower radiator support tie bar (2.7 V6, 2017-2019)',                     'Ford', 'GP5Z-16138-A', 'Ford', 'FRONT',       'Fusion Sport 2.7; supersedes DP5Z-16138-A. Shared with the Lincoln Continental and MKZ.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('headlamp-l-led-1720',     'HS7Z-13008-C',      'OEM', 'Ford'),
  ('headlamp-l-led-1720',     'HS7Z-13008-Z',      'OEM', 'Ford'),
  ('headlamp-r-led-1720',     'HS7Z-13008-F',      'OEM', 'Ford'),
  ('headlamp-r-led-1720',     'HS7Z-13008-Y',      'OEM', 'Ford'),
  ('taillamp-outer-l-1720',   'HS7Z-13405-D',      'OEM', 'Ford'),
  ('taillamp-outer-l-1720',   'HS7Z-13405-F',      'OEM', 'Ford'),
  ('taillamp-outer-r-1720',   'HS7Z-13404-D',      'OEM', 'Ford'),
  ('taillamp-outer-r-1720',   'HS7Z-13404-F',      'OEM', 'Ford'),
  ('taillamp-inner-l-h-1718', 'HS7Z-13405-B',      'OEM', 'Ford'),
  ('taillamp-inner-r-h-1718', 'HS7Z-13404-B',      'OEM', 'Ford'),
  ('taillamp-inner-l-j-1920', 'KS7Z-13405-F',      'OEM', 'Ford'),
  ('taillamp-inner-r-f-1920', 'KS7Z-13404-D',      'OEM', 'Ford'),
  ('taillamp-inner-l-k-1920', 'KS7Z-13405-G',      'OEM', 'Ford'),
  ('taillamp-inner-r-g-1920', 'KS7Z-13404-E',      'OEM', 'Ford'),
  ('taillamp-inner-r-g-1920', 'KS7Z-13404-B',      'OEM', 'Ford'),
  ('foglamp-l-sport-1719',    'HS7Z-15201-B',      'OEM', 'Ford'),
  ('foglamp-r-sport-1719',    'HS7Z-15200-B',      'OEM', 'Ford'),
  ('fbumper-1718',            'HS7Z-17D957-ACP',   'OEM', 'Ford'),
  ('rbumper-nosensor-1318',   'DS7Z-17K835-AACP',  'OEM', 'Ford'),
  ('rbumper-sensor-1318',     'ES7Z-17K835-BPTM',  'OEM', 'Ford'),
  ('rbumper-autopark-1318',   'DS7Z-17K835-CAPTM', 'OEM', 'Ford'),
  ('hood-1320',               'DS7Z-16612-A',      'OEM', 'Ford'),
  ('grille-chrome-1718',      'HS7Z-8200-AACP',    'OEM', 'Ford'),
  ('mirror-l-base-1320',      'DS7Z-17683-A',      'OEM', 'Ford'),
  ('mirror-l-base-1320',      'FS7Z-17683-A',      'OEM', 'Ford'),
  ('mirror-r-base-1320',      'DS7Z-17682-A',      'OEM', 'Ford'),
  ('mirror-r-base-1320',      'FS7Z-17682-A',      'OEM', 'Ford'),
  ('mirror-l-sig-1317',       'FS7Z-17683-BB',     'OEM', 'Ford'),
  ('mirror-l-sig-1317',       'FS7Z-17683-BA',     'OEM', 'Ford'),
  ('mirror-l-sig-1317',       'DS7Z-17683-BA',     'OEM', 'Ford'),
  ('mirror-l-sig-1317',       'DS7Z-17683-BAPTM',  'OEM', 'Ford'),
  ('mirror-r-sig-1317',       'FS7Z-17682-BB',     'OEM', 'Ford'),
  ('mirror-r-sig-1317',       'FS7Z-17682-BA',     'OEM', 'Ford'),
  ('mirror-r-sig-1317',       'DS7Z-17682-BA',     'OEM', 'Ford'),
  ('mirror-r-sig-1317',       'DS7Z-17682-BAPTM',  'OEM', 'Ford'),
  ('mirror-r-sig-1820',       'DS7Z-17682-CA',     'OEM', 'Ford'),
  ('mirror-r-sig-1820',       'FS7Z-17682-CA',     'OEM', 'Ford'),
  ('mirror-l-sig-puddle-17',  'FS7Z-17683-CB',     'OEM', 'Ford'),
  ('mirror-r-sig-puddle-17',  'FS7Z-17682-CB',     'OEM', 'Ford'),
  ('mirror-l-sig-puddle-1820','JS7Z-17683-XA',     'OEM', 'Ford'),
  ('mirror-r-sig-puddle-1820','JS7Z-17682-XA',     'OEM', 'Ford'),
  ('mirror-l-blis-mem-1719',  'JS7Z-17683-DA',     'OEM', 'Ford'),
  ('mirror-l-blis-mem-1719',  'DS7Z-17683-DA',     'OEM', 'Ford'),
  ('mirror-l-blis-mem-1719',  'DS7Z-17683-DAPTM',  'OEM', 'Ford'),
  ('mirror-r-blis-mem-1719',  'JS7Z-17682-DA',     'OEM', 'Ford'),
  ('radsupport-lower-i4-1320','GS7Z-16138-ACP',    'OEM', 'Ford'),
  ('radsupport-lower-i4-1320','DS7Z-16138-A',      'OEM', 'Ford'),
  ('radsupport-lower-v6-1719','DP5Z-16138-A',      'OEM', 'Ford');

-- Trim lists: "not Sport" and "Energi only" for the 2017-2020 variants.
INSERT INTO seed_fits (key, generation_slug, year_from, year_to, engine_code, trims, notes) VALUES
  ('headlamp-l-hal-1720',     'gen', 2017, 2020, NULL, NULL, 'Halogen headlamps without LED signature lighting'),
  ('headlamp-r-hal-1720',     'gen', 2017, 2020, NULL, NULL, 'Halogen headlamps without LED signature lighting'),
  ('headlamp-l-halsig-1720',  'gen', 2017, 2020, NULL, NULL, 'Halogen headlamps with LED signature lighting'),
  ('headlamp-r-halsig-1720',  'gen', 2017, 2020, NULL, NULL, 'Halogen headlamps with LED signature lighting'),
  ('headlamp-l-led-1720',     'gen', 2017, 2020, NULL, NULL, 'LED headlamps (fixed or adaptive)'),
  ('headlamp-r-led-1720',     'gen', 2017, 2020, NULL, NULL, 'LED headlamps (fixed or adaptive)'),
  ('taillamp-outer-l-1720',   'gen', 2017, 2020, NULL, NULL, NULL),
  ('taillamp-outer-r-1720',   'gen', 2017, 2020, NULL, NULL, NULL),
  ('taillamp-inner-l-a-1718', 'gen', 2017, 2018, NULL, NULL, 'Cars built to 08/2018; type A (sellers: halogen)'),
  ('taillamp-inner-r-a-1718', 'gen', 2017, 2018, NULL, NULL, 'Cars built to 08/2018; type A (sellers: halogen)'),
  ('taillamp-inner-l-h-1718', 'gen', 2017, 2018, NULL, NULL, 'Cars built 03/2017-08/2018; type H (sellers: LED)'),
  ('taillamp-inner-r-h-1718', 'gen', 2017, 2018, NULL, NULL, 'Cars built 03/2017-08/2018; type H (sellers: LED)'),
  ('taillamp-inner-l-j-1920', 'gen', 2019, 2020, NULL, NULL, 'Cars built from 08/2018; lower-priced variant (sellers: halogen)'),
  ('taillamp-inner-r-f-1920', 'gen', 2019, 2020, NULL, NULL, 'Cars built from 08/2018; lower-priced variant (sellers: halogen)'),
  ('taillamp-inner-l-k-1920', 'gen', 2019, 2020, NULL, NULL, 'Cars built from 08/2018; higher-priced variant (sellers: LED)'),
  ('taillamp-inner-r-g-1920', 'gen', 2019, 2020, NULL, NULL, 'Cars built from 08/2018; higher-priced variant (sellers: LED)'),
  ('foglamp-l-1718',          'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'Cars with fog lamps'),
  ('foglamp-r-1718',          'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'Cars with fog lamps'),
  ('foglamp-l-sport-1719',    'gen', 2017, 2019, NULL, ARRAY['Sport'], NULL),
  ('foglamp-r-sport-1719',    'gen', 2017, 2019, NULL, ARRAY['Sport'], NULL),
  ('foglamp-l-hal-1920',      'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'Halogen fog lamps'),
  ('foglamp-r-hal-1920',      'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'Halogen fog lamps'),
  ('foglamp-l-led-1920',      'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'LED fog lamps'),
  ('foglamp-r-led-1920',      'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'LED fog lamps'),
  ('fbumper-1718',            'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'Without Auto Park, without tow hook'),
  ('fbumper-park-1718',       'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'With Auto Park, without tow hook'),
  ('fbumper-tow-1718',        'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'Without Auto Park, with tow hook'),
  ('fbumper-park-tow-1718',   'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'With Auto Park and tow hook'),
  ('fbumper-sport-1719',      'gen', 2017, 2019, NULL, ARRAY['Sport'], 'Without Auto Park'),
  ('fbumper-sport-park-1719', 'gen', 2017, 2019, NULL, ARRAY['Sport'], 'With Auto Park'),
  ('fbumper-1920',            'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'Without Auto Park, without tow hook'),
  ('fbumper-park-1920',       'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'With Auto Park, without tow hook'),
  ('fbumper-tow-1920',        'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'Without Auto Park, with tow hook'),
  ('fbumper-park-tow-1920',   'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'With Auto Park and tow hook'),
  ('rbumper-nosensor-1318',   'gen', 2013, 2018, NULL, NULL, 'Cars without rear park sensors'),
  ('rbumper-sensor-1318',     'gen', 2013, 2018, NULL, NULL, 'Rear park sensors, without Auto Park'),
  ('rbumper-autopark-1318',   'gen', 2013, 2018, NULL, NULL, 'Rear park sensors with Auto Park'),
  ('rbumper-nosensor-1920',   'gen', 2019, 2020, NULL, NULL, 'Cars without rear park sensors'),
  ('rbumper-sensor-1920',     'gen', 2019, 2020, NULL, NULL, 'Rear park sensors, without Auto Park'),
  ('rbumper-autopark-1920',   'gen', 2019, 2020, NULL, NULL, 'Rear park sensors with Auto Park'),
  ('fender-l-1720',           'gen', 2017, 2020, NULL, ARRAY['S','SE','SEL','Titanium','Platinum','Sport','S Hybrid','SE Hybrid','SEL Hybrid','Titanium Hybrid','Platinum Hybrid'], NULL),
  ('fender-l-energi-1720',    'gen', 2017, 2020, NULL, ARRAY['SE Energi','Titanium Energi','Platinum Energi'], NULL),
  ('fender-r-1720',           'gen', 2017, 2020, NULL, NULL, NULL),
  ('hood-1320',               'gen', 2013, 2020, NULL, NULL, NULL),
  ('grille-chrome-1718',      'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'Chrome grille'),
  ('grille-storm-1718',       'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'Storm Metallic grille'),
  ('grille-sport-1719',       'gen', 2017, 2019, NULL, ARRAY['Sport'], NULL),
  ('grille-chrome-1920',      'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'Chrome grille without honeycomb'),
  ('grille-honeycomb-1920',   'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'Chrome grille with honeycomb mesh'),
  ('grille-black-1920',       'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'High-gloss black grille'),
  ('lgrille-tex-1718',        'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'Textured black, no engine heater'),
  ('lgrille-gloss-1718',      'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'Gloss black, no engine heater'),
  ('lgrille-tex-heater-1718', 'gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'Textured black, with engine heater'),
  ('lgrille-gloss-heater-1718','gen', 2017, 2018, NULL, ARRAY['S','SE','Titanium','Platinum','S Hybrid','SE Hybrid','Titanium Hybrid','Platinum Hybrid','SE Energi','Titanium Energi','Platinum Energi'], 'Gloss black, with engine heater'),
  ('lgrille-sport-1719',      'gen', 2017, 2019, NULL, ARRAY['Sport'], 'Without engine heater'),
  ('lgrille-sport-heater-1718','gen', 2017, 2018, NULL, ARRAY['Sport'], 'With engine heater'),
  ('lgrille-tex-1920',        'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'Textured black, no engine heater'),
  ('lgrille-gloss-1920',      'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'Gloss black, no engine heater'),
  ('lgrille-tex-heater-1920', 'gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'Textured black, with engine heater'),
  ('lgrille-gloss-heater-1920','gen', 2019, 2020, NULL, ARRAY['S','SE','SEL','Titanium','SE Hybrid','SEL Hybrid','Titanium Hybrid','Titanium Energi'], 'Gloss black, with engine heater'),
  ('lgrille-sport-heater-19', 'gen', 2019, 2019, NULL, ARRAY['Sport'], 'With engine heater'),
  ('mirror-l-base-1320',      'gen', 2013, 2020, NULL, NULL, 'Power, not heated, no signal lamp'),
  ('mirror-r-base-1320',      'gen', 2013, 2020, NULL, NULL, 'Power, not heated, no signal lamp'),
  ('mirror-l-heat-19',        'gen', 2019, 2019, NULL, NULL, 'Heated, no signal lamp'),
  ('mirror-r-heat-19',        'gen', 2019, 2019, NULL, NULL, 'Heated, no signal lamp'),
  ('mirror-l-heat-20',        'gen', 2020, 2020, NULL, NULL, 'Heated, no signal lamp'),
  ('mirror-r-heat-20',        'gen', 2020, 2020, NULL, NULL, 'Heated, no signal lamp'),
  ('mirror-l-sig-1317',       'gen', 2013, 2017, NULL, NULL, 'Heated, memory, auto-dim, signal lamp; without BLIS, without puddle lamp'),
  ('mirror-r-sig-1317',       'gen', 2013, 2017, NULL, NULL, 'Heated, memory, auto-dim, signal lamp; without BLIS, without puddle lamp'),
  ('mirror-l-sig-1820',       'gen', 2018, 2020, NULL, NULL, 'Signal lamp, without BLIS, without puddle lamp'),
  ('mirror-r-sig-1820',       'gen', 2018, 2020, NULL, NULL, 'Signal lamp, without BLIS, without puddle lamp'),
  ('mirror-l-sig-puddle-17',  'gen', 2017, 2017, NULL, NULL, 'Signal lamp and puddle lamp, without BLIS'),
  ('mirror-r-sig-puddle-17',  'gen', 2017, 2017, NULL, NULL, 'Signal lamp and puddle lamp, without BLIS'),
  ('mirror-l-sig-puddle-1820','gen', 2018, 2020, NULL, NULL, 'Signal lamp and puddle lamp, without BLIS'),
  ('mirror-r-sig-puddle-1820','gen', 2018, 2020, NULL, NULL, 'Signal lamp and puddle lamp, without BLIS'),
  ('mirror-l-blis-mem-1719',  'gen', 2017, 2019, NULL, NULL, 'Signal lamp, BLIS, memory'),
  ('mirror-r-blis-mem-1719',  'gen', 2017, 2019, NULL, NULL, 'Signal lamp, BLIS, memory'),
  ('mirror-l-blis-mem-20',    'gen', 2020, 2020, NULL, NULL, 'Signal lamp, BLIS, memory'),
  ('mirror-r-blis-mem-20',    'gen', 2020, 2020, NULL, NULL, 'Signal lamp, BLIS, memory'),
  ('mirror-l-blis-1920',      'gen', 2019, 2020, NULL, NULL, 'Signal lamp, BLIS, without memory'),
  ('mirror-r-blis-1920',      'gen', 2019, 2020, NULL, NULL, 'Signal lamp, BLIS, without memory'),
  ('radsupport-upper-i4-1720','gen', 2017, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('radsupport-upper-i4-1720','gen', 2017, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('radsupport-upper-i4-1720','gen', 2017, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('radsupport-upper-i4-1720','gen', 2017, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('radsupport-upper-i4-1720','gen', 2017, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('radsupport-upper-v6-1719','gen', 2017, 2019, '2.7 EcoBoost V6',   NULL, NULL),
  ('radsupport-lower-i4-1320','gen', 2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('radsupport-lower-i4-1320','gen', 2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('radsupport-lower-i4-1320','gen', 2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('radsupport-lower-i4-1320','gen', 2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('radsupport-lower-i4-1320','gen', 2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('radsupport-lower-i4-1320','gen', 2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('radsupport-lower-v6-1719','gen', 2017, 2019, '2.7 EcoBoost V6',   NULL, NULL);

-- ---------- CD391 pre-facelift, MY2013-2016 (hood, rear bumpers, lower tie bar, base mirrors and trunk lids are defined with the 2017-2020 block) ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  ('headlamp-r-1316',         'headlights',  'Fara, sağ, halogen (2013-2016)',                                'Фара правая, галоген (2013-2016)',                                   'Headlamp assembly, right, halogen (2013-2016)',                          'Ford', 'DS7Z-13008-A',  'Ford', 'FRONT_RIGHT', 'The only Fusion headlamp for 2013-2016 (no HID / LED / adaptive unit; those numbers are Lincoln MKZ). Low beam bulb BM5Z-13N021-B (formerly 2C5Z-13N021-AA). Crash-part code DS7Z-13008-ACP.'),
  ('headlamp-l-1316',         'headlights',  'Fara, sol, halogen (2013-2016)',                                'Фара левая, галоген (2013-2016)',                                    'Headlamp assembly, left, halogen (2013-2016)',                           'Ford', 'DS7Z-13008-B',  'Ford', 'FRONT_LEFT',  'The only Fusion headlamp for 2013-2016. Crash-part code DS7Z-13008-BCP.'),
  ('taillamp-outer-r-base-1316','tail-lights','Arxa fənər, xarici, sağ, LED (S / SE / Hybrid, 2013-2016)',   'Фонарь задний наружный правый, LED (S / SE / Hybrid, 2013-2016)',    'Tail lamp, outer (quarter panel), right, LED (S / SE / Hybrid, 2013-2016)', 'Ford', 'DS7Z-13404-H', 'Ford', 'REAR_RIGHT', 'Ford note "Without Energi Or Titanium". Cars built from 12/2012; supersedes DS7Z-13404-C. Crash-part code DS7Z-13404-HCP.'),
  ('taillamp-outer-l-base-1316','tail-lights','Arxa fənər, xarici, sol, LED (S / SE / Hybrid, 2013-2016)',   'Фонарь задний наружный левый, LED (S / SE / Hybrid, 2013-2016)',     'Tail lamp, outer (quarter panel), left, LED (S / SE / Hybrid, 2013-2016)', 'Ford', 'DS7Z-13405-H', 'Ford', 'REAR_LEFT',  'Ford note "Without Energi Or Titanium". Supersedes DS7Z-13405-C. Crash-part code DS7Z-13405-HCP.'),
  ('taillamp-outer-r-tit-1316','tail-lights', 'Arxa fənər, xarici, sağ, LED (Titanium / Energi, 2013-2016)',  'Фонарь задний наружный правый, LED (Titanium / Energi, 2013-2016)',  'Tail lamp, outer (quarter panel), right, LED (Titanium / Energi, 2013-2016)', 'Ford', 'DS7Z-13404-D', 'Ford', 'REAR_RIGHT', 'Ford note "With Energi Or Titanium". Titanium Hybrid assumed under Titanium. Crash-part code DS7Z-13404-DCP.'),
  ('taillamp-outer-l-tit-1316','tail-lights', 'Arxa fənər, xarici, sol, LED (Titanium / Energi, 2013-2016)',  'Фонарь задний наружный левый, LED (Titanium / Energi, 2013-2016)',   'Tail lamp, outer (quarter panel), left, LED (Titanium / Energi, 2013-2016)', 'Ford', 'DS7Z-13405-D', 'Ford', 'REAR_LEFT',  'Ford note "With Energi Or Titanium". Crash-part code DS7Z-13405-DCP.'),
  ('taillamp-inner-r-base-1316','tail-lights','Arxa fənər, daxili (baqaj qapağı), sağ (S / SE / Hybrid, 2013-2016)', 'Фонарь задний внутренний (крышка багажника), правый (S / SE / Hybrid, 2013-2016)', 'Tail / backup lamp, inner (trunk lid), right (S / SE / Hybrid, 2013-2016)', 'Ford', 'DS7Z-13404-A', 'Ford', 'REAR_RIGHT', 'Ford name "Backup Lamp Assembly", note "Without Energi Or Titanium". Crash-part code DS7Z-13404-ACP.'),
  ('taillamp-inner-l-base-1316','tail-lights','Arxa fənər, daxili (baqaj qapağı), sol (S / SE / Hybrid, 2013-2016)', 'Фонарь задний внутренний (крышка багажника), левый (S / SE / Hybrid, 2013-2016)', 'Tail / backup lamp, inner (trunk lid), left (S / SE / Hybrid, 2013-2016)',  'Ford', 'DS7Z-13405-A', 'Ford', 'REAR_LEFT',  'Ford name "Backup Lamp Assembly", note "Without Energi Or Titanium". Crash-part code DS7Z-13405-ACP.'),
  ('taillamp-inner-r-tit-1316','tail-lights', 'Arxa fənər, daxili (baqaj qapağı), sağ (Titanium / Energi, 2013-2016)', 'Фонарь задний внутренний (крышка багажника), правый (Titanium / Energi, 2013-2016)', 'Tail / backup lamp, inner (trunk lid), right (Titanium / Energi, 2013-2016)', 'Ford', 'DS7Z-13404-B', 'Ford', 'REAR_RIGHT', 'Ford note "With Energi Or Titanium".'),
  ('taillamp-inner-l-tit-1316','tail-lights', 'Arxa fənər, daxili (baqaj qapağı), sol (Titanium / Energi, 2013-2016)', 'Фонарь задний внутренний (крышка багажника), левый (Titanium / Energi, 2013-2016)', 'Tail / backup lamp, inner (trunk lid), left (Titanium / Energi, 2013-2016)',  'Ford', 'DS7Z-13405-B', 'Ford', 'REAR_LEFT',  'Ford note "With Energi Or Titanium".'),
  ('foglamp-1316',            'fog-lights',  'Duman farası, ön (sol və ya sağ, 2013-2016)',                   'Противотуманная фара передняя (левая или правая, 2013-2016)',        'Front fog lamp assembly, left or right (2013-2016)',                     'Ford', '4F9Z-15200-AA', 'Ford', 'FRONT',       'One number for both sides, qty 2; cars with front fog lamps. Supersedes CV6Z-15200-B; shared with the C-Max, Explorer, Fiesta, Focus and Mustang. Crash-part code 4F9Z-15200-AACP.'),
  ('fbumper-1316',            'bumpers',     'Ön bamper, astarlanmış (2013-2016)',                            'Бампер передний, грунтованный (2013-2016)',                          'Front bumper cover, primed (2013-2016)',                                 'Ford', 'DS7Z-17D957-AAPTM','Ford', 'FRONT',    'Every trim; without Auto Park sensors, without tow hook opening. Fog / no-fog / chrome bezel differences sit in the snap-in side grilles (17B814). Crash-part code DS7Z-17D957-AACP.'),
  ('fbumper-park-1316',       'bumpers',     'Ön bamper, astarlanmış, Auto Park sensorlu (2013-2016)',        'Бампер передний, грунтованный, с датчиками Auto Park (2013-2016)',   'Front bumper cover, primed, Auto Park sensors (2013-2016)',              'Ford', 'ES7Z-17D957-CPTM','Ford', 'FRONT',     'With Auto Park, without tow hook; sensor retainers welded in. Service only. Supersedes DS7Z-17D957-CAPTM. Crash-part code ES7Z-17D957-CCP.'),
  ('fbumper-tow-1316',        'bumpers',     'Ön bamper, astarlanmış, yedək qarmaq dəlikli (2013-2016)',      'Бампер передний, грунтованный, с проёмом буксирного крюка (2013-2016)', 'Front bumper cover, primed, tow hook opening (2013-2016)',            'Ford', 'ES7Z-17757-DAPTM','Ford', 'FRONT',     'Without Auto Park, with tow hook opening. Supersedes DS7Z-17757-DAPTM.'),
  ('fbumper-park-tow-1316',   'bumpers',     'Ön bamper, astarlanmış, Auto Park + yedək qarmaq (2013-2016)',  'Бампер передний, грунтованный, Auto Park + буксирный крюк (2013-2016)', 'Front bumper cover, primed, Auto Park sensors and tow hook (2013-2016)', 'Ford', 'ES7Z-17D957-EPTM','Ford', 'FRONT',    'With Auto Park and tow hook opening. Supersedes ES7Z-17757-EAPTM and DS7Z-17757-EAPTM.'),
  ('fender-r-1316',           'fenders',     'Ön qanad, sağ (2013-2016)',                                     'Крыло переднее правое (2013-2016)',                                  'Front fender, right (2013-2016)',                                        'Ford', 'DS7Z-16005-A',  'Ford', 'FRONT_RIGHT', 'Every trim incl. Energi.'),
  ('fender-l-1316',           'fenders',     'Ön qanad, sol (2013-2016)',                                     'Крыло переднее левое (2013-2016)',                                   'Front fender, left (2013-2016)',                                         'Ford', 'DS7Z-16006-A',  'Ford', 'FRONT_LEFT',  'Every trim except the Energi plug-in.'),
  ('fender-l-energi-1316',    'fenders',     'Ön qanad, sol, Energi, şarj lyuklu (2013-2016)',                'Крыло переднее левое, Energi, с проёмом лючка зарядки (2013-2016)',  'Front fender, left, Energi with charge-port opening (2013-2016)',        'Ford', 'DS7Z-16006-B',  'Ford', 'FRONT_LEFT',  'Fusion Energi only. Charge port ring DG9Z-10370-F and support DG9Z-16B045-A sold separately.'),
  ('grille-upper-1316',       'grilles',     'Radiator barmaqlığı, qara mesh (2013-2016)',                    'Решётка радиатора, чёрная сетчатая (2013-2016)',                     'Upper radiator grille, black mesh (2013-2016)',                          'Ford', 'DS7Z-8200-BA',  'Ford', 'FRONT',       'Every trim; the chrome bars are separate inserts (DS7Z-8200-DA to -HA). Crash-part code DS7Z-8200-BACP.'),
  ('lgrille-tex-1316',        'grilles',     'Bamper alt barmaqlığı, qara faktura (2013-2016)',               'Нижняя решётка бампера, чёрная фактурная (2013-2016)',               'Lower bumper grille, textured black (2013-2016)',                        'Ford', 'DS7Z-17K945-AB','Ford', 'FRONT',       'Cars without a fog bezel or with the colour-keyed fog bezel. Low-gloss velvet-etch texture.'),
  ('lgrille-smooth-1316',     'grilles',     'Bamper alt barmaqlığı, hamar, astarlanmış (2013-2016)',         'Нижняя решётка бампера, гладкая, грунтованная (2013-2016)',          'Lower bumper grille, smooth, paint-to-match (2013-2016)',                'Ford', 'DS7Z-17K945-BAPTM','Ford', 'FRONT',    'Cars with the chrome fog bezel and standard cruise control.'),
  ('lgrille-acc-1316',        'grilles',     'Bamper alt barmaqlığı, parlaq qara, adaptiv kruiz (2013-2016)', 'Нижняя решётка бампера, глянцевая чёрная, адаптивный круиз (2013-2016)', 'Lower bumper grille, gloss black, adaptive cruise (2013-2016)',       'Ford', 'DS7Z-17K945-CAPTM','Ford', 'FRONT',    'Cars with adaptive cruise control and the chrome fog bezel.'),
  ('mirror-r-blis-1314',      'mirrors',     'Yan güzgü, sağ, qızdırıcılı, yaddaşlı, işıqlı, BLIS (2013-2014)', 'Зеркало наружное правое, обогрев, память, подсветка, BLIS (2013-2014)', 'Door mirror, right, power, heated, memory, auto-dim, puddle lamp, BLIS (2013-2014)', 'Ford', 'JS7Z-17682-DC', 'Ford', 'FRONT_RIGHT', 'Cars built 08/2012-06/2014 ("Blind Spot Detection 2"). Supersedes DS7Z-17682-DA and DS7Z-17682-DAPTM. The left-hand 2013-2014 BLIS mirror is catalogued only for Police / SSV and is not seeded.'),
  ('radsupport-upper-herm-1316','radiator-supports','Ön modul dayağı, üst (Hermosillo istehsalı, 2013-2016)', 'Усилитель передней панели, верхний (сборка Hermosillo, 2013-2016)',  'Front end module bolster, upper radiator support (Hermosillo-built cars, 2013-2016)', 'Ford', 'DS7Z-16138-B', 'Ford', 'FRONT', 'Ford note "Hermosillo Plant Build" (Mexico-built cars; VIN 11th character R by standard Ford decoding, verify).'),
  ('radsupport-upper-fr-1416','radiator-supports','Ön modul dayağı, üst (Flat Rock istehsalı, 2014-2016)',    'Усилитель передней панели, верхний (сборка Flat Rock, 2014-2016)',   'Front end module bolster, upper radiator support (Flat Rock-built cars, 2014-2016)', 'Ford', 'DS7Z-16138-C', 'Ford', 'FRONT', 'Ford note "Flatrock Assembly Plant - USA" (VIN 11th character 5 by standard Ford decoding, verify).'),
  ('trunk-lid-1320',          'trunk-lids',  'Baqaj qapağı, spoylersiz (2013-2020)',                          'Крышка багажника, без спойлера (2013-2020)',                         'Trunk lid, without spoiler (2013-2020)',                                 'Ford', 'HS7Z-5440110-A','Ford', 'REAR',        'Supersedes DS7Z-5440110-A (cars built 08/2012-11/2015).'),
  ('trunk-lid-spoiler-1320',  'trunk-lids',  'Baqaj qapağı, spoylerli (2013-2020)',                           'Крышка багажника, со спойлером (2013-2020)',                         'Trunk lid, with rear spoiler (2013-2020)',                               'Ford', 'HS7Z-5440110-B','Ford', 'REAR',        'Supersedes DS7Z-5440110-B (cars built 08/2012-11/2015).');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('headlamp-r-1316',         'DS7Z-13008-ACP',    'OEM', 'Ford'),
  ('headlamp-l-1316',         'DS7Z-13008-BCP',    'OEM', 'Ford'),
  ('taillamp-outer-r-base-1316', 'DS7Z-13404-C',   'OEM', 'Ford'),
  ('taillamp-outer-r-base-1316', 'DS7Z-13404-HCP', 'OEM', 'Ford'),
  ('taillamp-outer-l-base-1316', 'DS7Z-13405-C',   'OEM', 'Ford'),
  ('taillamp-outer-l-base-1316', 'DS7Z-13405-HCP', 'OEM', 'Ford'),
  ('taillamp-outer-r-tit-1316',  'DS7Z-13404-DCP', 'OEM', 'Ford'),
  ('taillamp-outer-l-tit-1316',  'DS7Z-13405-DCP', 'OEM', 'Ford'),
  ('taillamp-inner-r-base-1316', 'DS7Z-13404-ACP', 'OEM', 'Ford'),
  ('taillamp-inner-l-base-1316', 'DS7Z-13405-ACP', 'OEM', 'Ford'),
  ('foglamp-1316',            'CV6Z-15200-B',      'OEM', 'Ford'),
  ('foglamp-1316',            '4F9Z-15200-AACP',   'OEM', 'Ford'),
  ('fbumper-1316',            'DS7Z-17D957-AACP',  'OEM', 'Ford'),
  ('fbumper-park-1316',       'DS7Z-17D957-CAPTM', 'OEM', 'Ford'),
  ('fbumper-park-1316',       'ES7Z-17D957-CCP',   'OEM', 'Ford'),
  ('fbumper-tow-1316',        'DS7Z-17757-DAPTM',  'OEM', 'Ford'),
  ('fbumper-park-tow-1316',   'ES7Z-17757-EAPTM',  'OEM', 'Ford'),
  ('fbumper-park-tow-1316',   'DS7Z-17757-EAPTM',  'OEM', 'Ford'),
  ('rbumper-sensor-1318',     'DS7Z-17K835-BAPTM', 'OEM', 'Ford'),
  ('grille-upper-1316',       'DS7Z-8200-BACP',    'OEM', 'Ford'),
  ('mirror-r-blis-1314',      'DS7Z-17682-DA',     'OEM', 'Ford'),
  ('mirror-r-blis-1314',      'DS7Z-17682-DAPTM',  'OEM', 'Ford'),
  ('trunk-lid-1320',          'DS7Z-5440110-A',    'OEM', 'Ford'),
  ('trunk-lid-spoiler-1320',  'DS7Z-5440110-B',    'OEM', 'Ford');

INSERT INTO seed_fits (key, generation_slug, year_from, year_to, engine_code, trims, notes) VALUES
  ('headlamp-r-1316',         'gen', 2013, 2016, NULL, NULL, NULL),
  ('headlamp-l-1316',         'gen', 2013, 2016, NULL, NULL, NULL),
  ('taillamp-outer-r-base-1316', 'gen', 2013, 2016, NULL, ARRAY['S','SE','S Hybrid','SE Hybrid'], NULL),
  ('taillamp-outer-l-base-1316', 'gen', 2013, 2016, NULL, ARRAY['S','SE','S Hybrid','SE Hybrid'], NULL),
  ('taillamp-outer-r-tit-1316',  'gen', 2013, 2016, NULL, ARRAY['Titanium','Titanium Hybrid','SE Energi','Titanium Energi'], 'Titanium Hybrid assumed under Ford''s "Titanium"'),
  ('taillamp-outer-l-tit-1316',  'gen', 2013, 2016, NULL, ARRAY['Titanium','Titanium Hybrid','SE Energi','Titanium Energi'], 'Titanium Hybrid assumed under Ford''s "Titanium"'),
  ('taillamp-inner-r-base-1316', 'gen', 2013, 2016, NULL, ARRAY['S','SE','S Hybrid','SE Hybrid'], NULL),
  ('taillamp-inner-l-base-1316', 'gen', 2013, 2016, NULL, ARRAY['S','SE','S Hybrid','SE Hybrid'], NULL),
  ('taillamp-inner-r-tit-1316',  'gen', 2013, 2016, NULL, ARRAY['Titanium','Titanium Hybrid','SE Energi','Titanium Energi'], 'Titanium Hybrid assumed under Ford''s "Titanium"'),
  ('taillamp-inner-l-tit-1316',  'gen', 2013, 2016, NULL, ARRAY['Titanium','Titanium Hybrid','SE Energi','Titanium Energi'], 'Titanium Hybrid assumed under Ford''s "Titanium"'),
  ('foglamp-1316',            'gen', 2013, 2016, NULL, NULL, 'Cars equipped with front fog lamps'),
  ('fbumper-1316',            'gen', 2013, 2016, NULL, NULL, 'Without Auto Park, without tow hook'),
  ('fbumper-park-1316',       'gen', 2013, 2016, NULL, NULL, 'With Auto Park, without tow hook'),
  ('fbumper-tow-1316',        'gen', 2013, 2016, NULL, NULL, 'Without Auto Park, with tow hook'),
  ('fbumper-park-tow-1316',   'gen', 2013, 2016, NULL, NULL, 'With Auto Park and tow hook'),
  ('fender-r-1316',           'gen', 2013, 2016, NULL, NULL, NULL),
  ('fender-l-1316',           'gen', 2013, 2016, NULL, ARRAY['S','SE','Titanium','S Hybrid','SE Hybrid','Titanium Hybrid'], NULL),
  ('fender-l-energi-1316',    'gen', 2013, 2016, NULL, ARRAY['SE Energi','Titanium Energi'], NULL),
  ('grille-upper-1316',       'gen', 2013, 2016, NULL, NULL, NULL),
  ('lgrille-tex-1316',        'gen', 2013, 2016, NULL, NULL, 'No fog bezel or colour-keyed fog bezel'),
  ('lgrille-smooth-1316',     'gen', 2013, 2016, NULL, NULL, 'Chrome fog bezel, standard cruise control'),
  ('lgrille-acc-1316',        'gen', 2013, 2016, NULL, NULL, 'Chrome fog bezel, adaptive cruise control'),
  ('mirror-r-blis-1314',      'gen', 2013, 2014, NULL, NULL, 'BLIS mirror, cars built to 06/2014'),
  ('radsupport-upper-herm-1316','gen', 2013, 2016, NULL, NULL, 'Hermosillo-built cars'),
  ('radsupport-upper-fr-1416','gen', 2014, 2016, NULL, NULL, 'Flat Rock-built cars'),
  ('trunk-lid-1320',          'gen', 2013, 2020, NULL, NULL, 'Without rear spoiler'),
  ('trunk-lid-spoiler-1320',  'gen', 2013, 2020, NULL, NULL, 'With rear spoiler');


-- ============================================================
-- Sanity: every category slug and engine_code used above must exist.
-- ============================================================
DO $$
DECLARE missing text;
BEGIN
    SELECT string_agg(DISTINCT sp.category_slug, ', ') INTO missing
      FROM seed_parts sp LEFT JOIN categories c ON c.slug = sp.category_slug
     WHERE c.id IS NULL;
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'unknown category slug(s): %', missing;
    END IF;

    SELECT string_agg(DISTINCT sf.engine_code, ', ') INTO missing
      FROM seed_fits sf
     WHERE sf.engine_code IS NOT NULL
       AND NOT EXISTS (
        SELECT 1 FROM vehicle_variants vv
          JOIN vehicle_generations g ON g.id = vv.generation_id
          JOIN vehicle_models m ON m.id = g.model_id
          JOIN vehicle_makes mk ON mk.id = m.make_id
         WHERE mk.slug = 'ford' AND m.slug = 'fusion' AND g.slug IN ('cd338', 'gen')
           AND vv.engine_code = sf.engine_code);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'unknown engine_code(s): %', missing;
    END IF;
END $$;

-- ============================================================
-- Parts: create only those whose oem_key is not in part_numbers yet.
-- Ids are generated up front so key -> part_id never depends on names.
-- ============================================================
CREATE TEMP TABLE seed_new ON COMMIT DROP AS
SELECT sp.key, gen_random_uuid() AS part_id
  FROM seed_parts sp
 WHERE NOT EXISTS (
        SELECT 1 FROM part_numbers pn
          JOIN parts p ON p.id = pn.part_id AND p.deleted_at IS NULL
         WHERE pn.number = sp.oem_key AND pn.type = 'OEM');

INSERT INTO parts (id, category_id, name_az, name_ru, name_en, brand, description, created_by, updated_by)
SELECT n.part_id, c.id, sp.name_az, sp.name_ru, sp.name_en, sp.brand, sp.description,
       'seed-ford-fusion-body-lighting', 'seed-ford-fusion-body-lighting'
  FROM seed_new n
  JOIN seed_parts sp ON sp.key = n.key
  JOIN categories c ON c.slug = sp.category_slug;

INSERT INTO part_numbers (part_id, number, type, source, created_by, updated_by)
SELECT n.part_id, sp.oem_key, 'OEM', sp.oem_key_source,
       'seed-ford-fusion-body-lighting', 'seed-ford-fusion-body-lighting'
  FROM seed_new n
  JOIN seed_parts sp ON sp.key = n.key;

-- key -> part_id (new and pre-existing alike)
CREATE TEMP TABLE seed_part_ids ON COMMIT DROP AS
SELECT sp.key, pn.part_id
  FROM seed_parts sp
  JOIN part_numbers pn ON pn.number = sp.oem_key AND pn.type = 'OEM'
  JOIN parts p ON p.id = pn.part_id AND p.deleted_at IS NULL;

DO $$
DECLARE missing text;
BEGIN
    SELECT string_agg(sp.key, ', ') INTO missing
      FROM seed_parts sp LEFT JOIN seed_part_ids ids ON ids.key = sp.key
     WHERE ids.part_id IS NULL;
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'could not resolve part id for: %', missing;
    END IF;
    IF (SELECT count(*) FROM seed_part_ids) <> (SELECT count(*) FROM seed_parts) THEN
        RAISE EXCEPTION 'an oem_key matches more than one part';
    END IF;
END $$;

-- ============================================================
-- Parts shared with an earlier seed (matched by oem_key, e.g. the 2.3 / 2.5
-- water pump and thermostat also used on the CD391) take this seed's
-- generation-neutral wording instead of staying named after the CD391.
-- ============================================================
UPDATE parts p
   SET name_az = sp.name_az, name_ru = sp.name_ru, name_en = sp.name_en, description = sp.description,
       updated_at = now(), updated_by = 'seed-ford-fusion-body-lighting'
  FROM seed_parts sp
  JOIN seed_part_ids ids ON ids.key = sp.key
 WHERE p.id = ids.part_id
   AND NOT EXISTS (SELECT 1 FROM seed_new n WHERE n.key = sp.key)
   AND (p.name_az, p.name_ru, p.name_en, p.description)
       IS DISTINCT FROM (sp.name_az, sp.name_ru, sp.name_en, sp.description);

-- ============================================================
-- Numbers
-- ============================================================
INSERT INTO part_numbers (part_id, number, type, source, created_by, updated_by)
SELECT ids.part_id, sn.number, sn.type, sn.source,
       'seed-ford-fusion-body-lighting', 'seed-ford-fusion-body-lighting'
  FROM seed_numbers sn
  JOIN seed_part_ids ids ON ids.key = sn.key
ON CONFLICT (number, type, part_id) DO NOTHING;

-- ============================================================
-- Fitments, per variant
-- ============================================================
INSERT INTO fitments (part_id, vehicle_variant_id, position, notes, created_by, updated_by)
SELECT DISTINCT ids.part_id, vv.id, sp.position, sf.notes,
       'seed-ford-fusion-body-lighting', 'seed-ford-fusion-body-lighting'
  FROM seed_fits sf
  JOIN seed_parts sp ON sp.key = sf.key
  JOIN seed_part_ids ids ON ids.key = sf.key
  JOIN vehicle_generations g ON g.slug = sf.generation_slug
  JOIN vehicle_models m ON m.id = g.model_id AND m.slug = 'fusion'
  JOIN vehicle_makes mk ON mk.id = m.make_id AND mk.slug = 'ford'
  JOIN vehicle_variants vv ON vv.generation_id = g.id
                          AND (sf.engine_code IS NULL OR vv.engine_code = sf.engine_code)
                          AND vv.year BETWEEN sf.year_from AND sf.year_to
                          AND (sf.trims IS NULL OR vv.trim = ANY (sf.trims))
 WHERE NOT EXISTS (
        SELECT 1 FROM fitments f
         WHERE f.part_id = ids.part_id
           AND f.vehicle_variant_id = vv.id
           AND f.position IS NOT DISTINCT FROM sp.position
           AND f.notes IS NOT DISTINCT FROM sf.notes);

COMMIT;

-- ============================================================
-- Verify
-- ============================================================
SELECT c.slug AS category, p.name_en, p.brand,
       (SELECT string_agg(pn.number, ', ' ORDER BY pn.type, pn.number)
          FROM part_numbers pn WHERE pn.part_id = p.id) AS numbers,
       (SELECT count(*) FROM fitments f WHERE f.part_id = p.id) AS fitments
  FROM parts p
  JOIN categories c ON c.id = p.category_id
 WHERE p.created_by = 'seed-ford-fusion-body-lighting'
 ORDER BY c.slug, p.name_en;

SELECT vv.year, vv.trim, vv.engine_code, count(DISTINCT f.part_id) AS parts
  FROM vehicle_variants vv
  JOIN vehicle_generations g ON g.id = vv.generation_id AND g.slug IN ('cd338', 'gen')
  JOIN vehicle_models m ON m.id = g.model_id AND m.slug = 'fusion'
  LEFT JOIN fitments f ON f.vehicle_variant_id = vv.id AND f.created_by = 'seed-ford-fusion-body-lighting'
 GROUP BY vv.year, vv.trim, vv.engine_code
 ORDER BY vv.year, vv.engine_code, vv.trim;
SQL
