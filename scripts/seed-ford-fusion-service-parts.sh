#!/usr/bin/env bash
# Seed service parts, batch 1: Ford Fusion II (CD391, US market, MY2013-2020),
# per engine, with Motorcraft OEM numbers + aftermarket cross-references and
# fitments per vehicle variant. TODO.md task 4.
#
# How the data is organised (three temp tables, filled below, then merged):
#   seed_parts    one row per physical part. `oem_key` is the OEM number (current
#                 Ford service number, or Motorcraft) that identifies the part
#                 for idempotency: a re-run finds the existing part by that OEM
#                 number and inserts nothing new.
#   seed_numbers  OEM / AFTERMARKET numbers per part (source = maker).
#   seed_fits     applicability rules per part: model-year range, engine_code,
#                 optional trim list (NULL = every trim), optional note
#                 (e.g. 'AWD only' — FWD/AWD is not part of the variant key,
#                 so drivetrain-specific parts attach to the same variant with
#                 the drivetrain in fitments.notes).
#
# Every statement is idempotent: parts are guarded by oem_key, numbers by the
# (number, type, part_id) unique constraint, fitments by an explicit NOT EXISTS
# (the unique constraint on fitments does not catch NULL positions).
#
# Requires: ford/fusion generation slug 'gen' (CD391) with its variants
# (scripts/seed-ford-fusion-variants.sh) and the canonical category tree
# (scripts/seed-category-tree.sh).
#
# Run locally:  ./scripts/seed-ford-fusion-service-parts.sh
# Run on prod:  print the heredoc body and paste it into a DB client:
#   awk '/^docker exec/{f=1;next} /^SQL$/{f=0} f' scripts/seed-ford-fusion-service-parts.sh
#
# Research date: 2026-11-10. Market: US (not EU/CIS). Confidence bar: 90%; everything
# below it is listed under LEFT OUT and not seeded. Motorcraft retail numbers are
# often superseded into Ford service numbers; both are stored as OEM numbers so a
# lookup by either works. Ford EPC mirrors (fordpartsgiant / fordpartsdeal) carry
# Ford's own fitment notes (Sport / Hybrid / Energi / AWD / wheel size).
#
# Sources (per claim):
#   Filters & ignition (Ford owner's manuals, Motorcraft Parts tables, then Ford EPC mirrors):
#     https://www.manualsdir.com/manuals/602076/ford-2013-fusion-v3.html?page=297  (MY2013)
#     https://www.manualsdir.com/manuals/602075/ford-2013-fusion-v2.html?page=293  (MY2013 plugs; gaps p.292)
#     https://www.manualsdir.com/manuals/602024/ford-2014-fusion-v2.html?page=287  (MY2014)
#     https://www.manualsdir.com/manuals/601988/ford-2015-fusion.html?page=316     (MY2015)
#     https://www.manualsdir.com/manuals/601989/ford-2015-fusion-hybrid.html?page=314 (MY2015 Hybrid: FA-1911, FL-910-S, SP-530, FP-71; gap p.313)
#     https://www.dezosmanuals.com/wp-content/uploads/2021/07/2017-Ford-Fusion.pdf (MY2017, pp.325-331 incl. 2.7L FL-2062 / SP-542)
#     https://www.dezosmanuals.com/wp-content/uploads/2021/07/2020-Ford-Fusion.pdf (MY2020, pp.320-326; lifetime fuel filter p.269; plug interval p.439)
#     https://www.fordpartsgiant.com/parts/ford-oil-filter_ku2z-6731-a.html        (KU2Z-6731-A <- FT4Z-6731-A, FL-2062; 2.7L)
#     https://www.fordpartsgiant.com/parts/ford-air-filter_ds7z-9601-d.html        (DS7Z-9601-D <- DS7Z-9601-A, FA-1912)
#     https://www.fordpartsgiant.com/parts/ford-air-filter_dg9z-9601-a.html        (DG9Z-9601-A, 2.0L Duratec Hybrid)
#     https://www.fordpartsgiant.com/parts/ford-cabin-air-filter_dg9z-19n619-a.html
#     https://www.fordpartsgiant.com/parts/ford-spark-plug_ayfs-32y-rx.html        (= SP530X <- SP-530)
#     https://www.fordpartsgiant.com/parts/ford-spark-plug_cyfs-12y-pctx.html      (= SP550X <- SP-550, SP-527; 2.0 EcoBoost 2013-2020)
#     https://www.fordpartsgiant.com/parts/ford-spark-plug_cyfs-13y-rcx.html       (<- SP-532; 1.6L)
#     https://www.fordpartsgiant.com/parts/ford-spark-plug_hyfs-094-yecx.html      (<- SP-539; 1.5L)
#     https://www.fordpartsgiant.com/parts/ford-spark-plug_cyfs-12y-rt3.html       (= SP594, 2.7L 2017-2019; conflicts with manuals, not used)
#     https://www.ford.com/product/ignition-coil-p4000092891                       (Motorcraft DG562 = CM5Z-12029-K)
#     https://www.fordpartsgiant.com/parts/ford-ignition-coil_cm5z-12029-k.html    (<- CM5Z-12029-A, DG-546; 2.0 EcoBoost)
#     https://www.fordpartsgiant.com/parts/ford-ignition-coil_ds7z-12029-b.html    (<- DG-552, DS7Z-12029-A; 1.5L)
#     https://www.fordpartsdeal.com/oem/ford~coil-assembly-ignition~ds7z-12029-b
#     https://www.fordpartsgiant.com/parts/ford-ignition-coil_9e5z-12029-a.html    (2.5L / 2.0 Duratec Hybrid)
#     https://www.fordpartsgiant.com/parts/ford-ignition-coil_ft4z-12029-a.html    (2.7L, qty 6)
#     https://www.fordpartsgiant.com/parts/ford-ignition-coil_bm5z-12029-b.html    (1.6L)
#     https://www.fordpartsgiant.com/oem-2018-ford-fusion-ignition_coil.html , .../oem-2013-ford-fusion-ignition_coil.html
#   Filter aftermarket cross-references:
#     https://www.fram.com/fram-extra-guard-oil-filter-spin-on-ph3614              (PH3614 <-> FL-910S)
#     https://www.rockauto.com/en/catalog/ford,2015,fusion,2.5l+l4,3308878,engine,oil+filter,5340 (WIX 51348, MY2015 2.5L)
#     https://www.fram.com/fram-extra-guard-air-filter-flex-panel-ca11480          (CA11480 <-> FA-1912/A)
#     https://www.wheelerfleet.com/amp/product/air-filter/105373                   (FA1912A <-> WIX WA10048, Baldwin PA4471)
#     https://www.fram.com/fram-extra-guard-air-filter-flex-panel-ca11482          (CA11482 <-> FA-1911)
#     https://www.fram.com/fram-fresh-breeze-cabin-air-filter-cf11775              (CF11775 <-> FP-71/A)
#     https://www.wheelerfleet.com/amp/product/cabin-filter/120600                 (FP71A <-> DG9Z19N619AA, 2013-2020)
#   Belts, cooling, battery, wipers (ford.com Motorcraft pages pair SKU with Ford number; EPC mirrors for fitment):
#     https://www.ford.com/product/serpentine-belt-p4000138098                (JK4542B = CV6Z-8620-E)
#     https://www.fordpartsgiant.com/parts/ford-v-belt_cv6z-8620-e.html , .../ford-v-belt_da8z-8620-g.html , .../ford-a-c-belt_da8z-8620-a.html
#     https://www.ford.com/product/serpentine-belt-p4000149261                (JK6424B = GS7Z-8620-C)
#     https://fordpartsgiant.com/parts/ford-kit-drive-belts_gs7z-8620-c.html
#     https://www.fordpartsgiant.com/parts-list/2014-ford-fusion/engine/pulleys_and_drive_belts.html
#     https://www.fordpartsgiant.com/parts/ford-belt_ds7z-8620-a.html , .../ford-v-belt_f2gz-8620-a.html
#     https://www.carparts.com/details/accessory-belt-tensioner/motorcraft/mibt121 , .../mibt123  (BT121 = DS7Z6A228A, BT123 = DS7Z6A228B)
#     https://www.fordpartsgiant.com/parts/ford-pulley-asy-tension_ds7z-6a228-a.html , .../ds7z-6a228-b.html , .../bm5z-6a228-a.html , .../f2gz-6a228-b.html
#     https://www.fordpartsgiant.com/parts/ford-thermostat-asy_3m4z-8575-b.html
#     https://www.fordpartsgiant.com/parts-list/2016-ford-fusion/engine/thermostat_housing_related_parts.html
#     https://www.fordpartsdeal.com/oem/ford~thermostat-assembly~cj5z-8575-a
#     https://www.ford.com/product/engine-coolant-thermostat-p4000155782      (RT1233 = FR3Z-8575-A)
#     https://www.fordpartsgiant.com/parts/ford-thermostat_fr3z-8575-a.html
#     https://fordpartsgiant.com/parts/ford-connection-water-outlet_ds7z-8592-f.html
#     https://www.fordpartsgiant.com/parts/ford-thermostat-asy_br3z-8575-f.html , .../ford-thermostat-asy_ds7z-8575-c.html
#     https://www.ford.com/product/engine-water-pump-p4000149161              (PW624 = 4S4Z-8501-E)
#     https://www.ford.com/product/engine-water-pump-p4000131727              (PW579 = 1S7Z-8501-K)
#     https://www.ford.com/product/engine-water-pump-p4000117596              (PW578 = EJ7Z-8501-F)
#     https://www.ford.com/product/engine-water-pump-p4000014444              (PW556 = DS7Z-8501-E)
#     https://www.ford.com/product/engine-water-pump-p4000070242              (PW545 = 7S7Z-8501-C)
#     https://www.ford.com/product/engine-water-pump-p4000007360              (PW576 = FT4Z-8501-C)
#     https://www.ford.com/product/heater-water-pump-p4000065655              (PW589 = DS7Z-8C419-E)
#     https://www.fordpartsgiant.com/parts/ford-pump-asy-water_4s4z-8501-e.html , .../1s7z-8501-k.html , .../ej7z-8501-f.html , .../7s7z-8501-c.html , .../ft4z-8501-c.html
#     https://www.fordpartsgiant.com/parts-list/2016-ford-fusion/engine/water_pump.html , .../2014-ford-fusion/engine/water_pump.html
#     https://www.fordpartsgiant.com/parts/ford-pump-asy_ds7z-8c419-e.html
#     https://www.ford.com/product/vehicle-battery-p4000012224 (BXT-90T5-590) , .../p4000013443 (BXT-90T5-500) , .../p4000110605 (BXT-99RT4-A)
#     https://www.fordpartsgiant.com/parts-list/2013-ford-fusion/electrical/battery_and_mountings.html , .../2016-ford-fusion/electrical/battery_and_mountings.html
#     https://www.fordpartsgiant.com/parts/ford-battery_bxt-99rt4-a.html , .../ford-battery_bagm-48h6-760.html
#     https://www.manualsdir.com/manuals/602025/ford-2014-fusion-v3.html?page=291  (MY2014: BXT-90T5-500/-590, WW-2601 driver, WW-2700 passenger)
#     https://www.manualsdir.com/manuals/601988/ford-2015-fusion.html?page=316     (MY2015: + BAGM-48H6-760)
#     https://www.manualsdir.com/manuals/601989/ford-2015-fusion-hybrid.html?page=314 (Hybrid/Energi: BXT-99RT4-390, WW-2601, WW-2700)
#     https://www.ford.com/product/wiper-blade-p4000141328 (WW2601A, 26 in LH) , https://www.ford.com/product/wiper-blade-p4000064564 (WW2700A, 27 in RH)
#     https://www.fordpartsgiant.com/parts/ford-blade-assembly-wiper_ds7z-17528-aa.html
#     https://www.fordpartsdeal.com/oem/ford~blade-asy-wiper~ds7z-17528-ba
#     https://www.fordpartsgiant.com/parts-list/2013-ford-fusion/body_and_paint/windshield_wiper.html (front blades only, no rear wiper)
#   Brakes (dealer mirrors of Ford EPC with Sport / Hybrid / Energi / AWD notes;
#   Motorcraft BRF-/BRRF- numbers are the superseded equivalents listed there):
#     https://www.fordpartsdeal.com/parts-select/<year>-ford-fusion-brake-pads  (2013, 2015-2020)
#     https://www.fordpartsdeal.com/parts-select/2015-ford-fusion-brake-disc , .../2018-ford-fusion-brake-disc
#     https://www.fordpartsgiant.com/parts/ford-kit-brake-lining_dg9z-2001-f.html  (BRF-1501, BRF-31)
#     https://www.fordpartsgiant.com/parts/ford-kit-brake-lining_lg9z-2001-a.html
#     https://www.fordpartsgiant.com/parts/ford-kit-brake-lining_dg9z-2001-m.html  (-> DG9Z-2001-Q; BRF-1502/1533/33)
#     https://www.fordpartsgiant.com/parts/ford-kit-brake-lining_g3gz-2001-c.html  (BRF-1536)
#     https://www.fordpartsgiant.com/parts/ford-pad-brake_dg9z-2200-n.html   (BRF-1498, BRF-29)
#     https://www.fordpartsgiant.com/parts/ford-pad-brake_dg9z-2200-ma.html  (BRF-1499/1555/30)
#     https://www.fordpartsgiant.com/parts/ford-pad-brake_dg9z-2200-r.html   (BRF-35/1497/1492)
#     https://www.fordpartsgiant.com/parts/ford-pad-brake_dg9z-2200-f.html   (BRF-1434/1500)
#     https://www.fordpartsdeal.com/oem/ford~rotor-asy-brake~ks7z-1125-a      (BRRF-307/330/117/328)
#     https://www.fordpartsdeal.com/oem/ford~brake-rotor-assembly~k2gz-1125-b (BRRF-316/319/250)
#     https://www.fordpartsgiant.com/parts-list/2018-ford-fusion/chassis/rear_brake_discs_and_calipers.html (DG9Z-2C026-C, BRRF-119)
#     https://www.fordpartsgiant.com/parts-list/2015-ford-fusion/chassis/rear_brake_discs_and_calipers.html
#     https://www.fordpartsgiant.com/parts-list/2019-ford-fusion/chassis/rear_brake_discs_and_calipers.html
#   Brake aftermarket cross-references:
#     https://www.salmonspeedworx.com/products/brembo-13-20-ford-fusion-19-20-police-responder-hybrid-front-premium-nao-ceramic-oe-equivalent-pad
#     https://fiperformance.com/products/power-stop-13-19-ford-fusion-front-z16-evolution-ceramic-brake-pads
#     https://fiperformance.com/products/power-stop-17-18-ford-edge-rear-z16-evolution-ceramic-brake-pads
#     https://www.steeda.com/stoptech-305-1653-fusion-select-front-brake-pads
#     https://www.steeda.com/brembo-p24175-fusion-prime-low-met-rear-brake-pads
#   Suspension (ford.com pairs Motorcraft AST/ASH SKUs with Ford numbers; splits from Ford EPC mirrors):
#     https://www.fordpartsgiant.com/parts-list/2015-ford-fusion/chassis/front_suspension_struts_and_springs.html
#     https://www.fordpartsgiant.com/parts-list/2018-ford-fusion/chassis/front_suspension_struts_and_springs.html
#     https://www.fordpartsgiant.com/parts-list/2020-ford-fusion/front-suspension-control-arm-stabilizer-bar.html
#     https://www.ford.com/product/suspension-strut-assembly-p4000051654  (AST84751 = HG9Z-18124-F)
#     https://www.ford.com/product/suspension-strut-assembly-p4000153576  (AST24737 = HG9Z-18124-A)
#     https://www.ford.com/product/suspension-strut-assembly-p4000134923  (AST84752 = HG9Z-18124-G)
#     https://www.ford.com/product/suspension-strut-assembly-p4000162527  (AST84756 = HG9Z-18124-L)
#     https://www.ford.com/product/suspension-strut-assembly-p4000084953  (AST24679 = DG9Z-18124-Z)
#     https://www.ford.com/product/suspension-strut-assembly-p4000165795  (AST12364 = DG9Z-18124-Q)
#     https://www.ford.com/product/suspension-strut-assembly-p4000116027  (AST12367 = DG9Z-18124-T)
#     https://www.ford.com/product/suspension-strut-assembly-p4000012119  (AST86034 = HG9Z-18124-AT)
#     https://www.ford.com/product/suspension-strut-assembly-p4000150107  (AST86033 = HG9Z-18124-AS)
#     https://www.ford.com/product/suspension-strut-assembly-p4000130356  (AST24749 = HG9Z-18124-D)
#     https://www.fordpartsgiant.com/parts/ford-shock-absorber-asy-front_hg9z-18124-f.html
#     https://www.fordpartsgiant.com/parts/ford-shock-absorber-asy_hg9z-18124-a.html
#     https://www.fordpartsdeal.com/oem/ford~shock-absorber-assembly-front~hg9z-18124-g
#     https://www.fordpartsdeal.com/oem/ford~shock-absorber-assembly~hg9z-18124-l
#     https://www.fordpartsgiant.com/parts/ford-shock-absorber-asy-front_dg9z-18124-q.html
#     https://www.fordpartsdeal.com/oem/ford~strut-suspension~hg9z-18124-at , .../hg9z-18124-as
#     https://www.fordpartsgiant.com/parts/ford-strut-suspension_hg9z-18124-d.html , .../hg9z-18124-b.html
#     https://www.fordpartsgiant.com/parts-list/2015-ford-fusion/chassis/rear_springs_and_shock_absorbers.html
#     https://fordpartsgiant.com/parts-list/2017-ford-fusion/chassis/rear_springs_and_shock_absorbers.html
#     https://www.ford.com/product/suspension-shock-absorber-p4000047638  (ASH24572 = DG9Z-18125-K)
#     https://www.ford.com/product/suspension-shock-absorber-p4000068490  (ASH24682 = DG9Z-18125-V)
#     https://www.fordpartsdeal.com/oem/ford~shock-absorber-assembly~dg9z-18125-t , .../dg9z-18125-k
#     https://fordpartsdeal.com/parts-list/2019-ford-fusion/suspension/rear-suspension-control-arm
#     https://www.fordpartsdeal.com/oem/ford~link~dg9z-5k484-a , https://www.fordpartsgiant.com/parts/ford-link_dg9z-5k484-a.html
#     https://www.fordpartsdeal.com/oem/ford~link-stabilizer-bar~dg9z-5c486-a
#     https://www.fordpartsdeal.com/parts-select/2017-ford-fusion-wheel-hub , .../2019-ford-fusion-wheel-hub
#     https://www.fordpartsdeal.com/oem/ford~hub-asy-wheel~dg9z-1104-t
#     https://www.fordpartsgiant.com/parts/ford-hub-asy-wheel_dg9z-1109-c.html
#     https://www.autopartsprime.com/ford/hub-asy-wheel/oe-dg9z1109c
#     https://www.fordpartsgiant.com/oem-2015-ford-fusion-wheel_hub.html
#     https://www.fordpartsdeal.com/oem/ford~mounting-assembly~dg9z-3a197-ab
#     https://fordpartsgiant.com/oem-2018-ford-fusion-shock_and_strut_mount.html
#   Suspension aftermarket cross-references:
#     https://cart.bilsteinus.com/strut-22-250315.html , https://cart.bilsteinus.com/strut-22-250322.html
#     https://cart.bilsteinus.com/shock-19-250335.html
#     https://www.carparts.com/Sway-Bar-Link/TRW/TRWJTS1540  (TRW JTS1540 replaces DG9Z5K484A; Moog K750740 interchange)
#
# Deliberately LEFT OUT (could not verify, < 90% confidence, or no clean supersession):
#   Filters & ignition:
#   -- Fuel filter: lifetime filter integrated in the fuel tank, not a service item (MY2020 manual p.269).
#   -- 2.7 V6 spark plug MY2018-2019: manuals say SP-542 (2017) / SP-545 (2020), Ford EPC says SP594; only MY2017 seeded.
#   -- 2.0 EcoBoost: exact year SP-537 -> SP-550 unknown (no MY2018/2019 manual); SP550X covers all years anyway.
#   -- Motorcraft DG numbers for the 2.5/Hybrid (DG-522?), 2.7 (DG555?) and 1.6 coils: search snippets only.
#   -- 1.5 EcoBoost coil current Motorcraft box (DG554?): snippet only; DG-552 cited.
#   -- Ford engineering number for FL-910S (BE8Z-6731-AB): marketplace listings only.
#   -- Aftermarket spark plugs and coils (NGK, Denso, Bosch, Delphi, SMP): every catalog site blocked fetches.
#   -- Aftermarket for FL-2062; Bosch 3330 / Mahle OC338 / Purolator TL10241 for FL-910S (single RockAuto page); WIX 610 hybrid air filter (snippet).
#   Belts, cooling, battery, wipers:
#   -- Aftermarket cross-references, all parts: only search snippets of blocked pages (Gates 39351 / Continental 49827
#      for BT121; Gates 90K-39351A/B kits; Gates K040346SF for DA8Z-8620-A; Gates 41120 for PW579; Bando 37266FS). Unverified.
#   -- Current Motorcraft SKUs seen only in snippets: JK4546A, JK4365, RT-1193, RT-1221, RH-224, RT-1251, BT-139.
#   -- 1.5 EcoBoost belt MY2014-2016: GS7Z-8620-C catalogued 2017-2020 only; earlier DS7Z-8620-B / JK6-626 superseded.
#   -- 1.6 EcoBoost and 2.7 V6 Motorcraft belt/tensioner numbers: none tied to the Ford numbers.
#   -- Hybrid/Energi accessory belt and tensioner: diagram lists none (likely no belt), no positive statement found.
#   -- Hybrid/Energi main electric engine coolant pump: catalog refers to radiator section with no part data.
#   -- 2.7 V6 12 V battery: battery diagrams read (MY2013, MY2016) predate the Sport.
#   -- Gas battery fitment 2017-2020 extrapolated from MY2013/MY2016 diagrams.
#   Brakes:
#   -- Rear pads, 2.0 EcoBoost AWD non-Sport: every Ford rear-pad note says "Without AWD";
#      no AWD non-Sport rear pad on the year pages (possibly DG9Z-2200-F, unsourced).
#   -- Front rotor, Energi: KS7Z-1125-C vs DG9Z-1125-H conflict, no supersession chain (88%).
#   -- Rear rotor, Sport: E1GZ-2C026-E is tagged "With Police Suspension", ambiguous (85%).
#   -- Rear rotor, Energi: DG9Z-2C026-B / -D / KJ5Z-2C026-A, no clean chain.
#   -- Rear rotor, MY2020 (all) and 1.6 EcoBoost: no diagram data retrieved.
#   -- Motorcraft retail BR-1653 / BR-1665-B: marketplace listings only.
#   -- Rotor diameters: no Ford spec sheet reachable; aftermarket listings conflict.
#   -- Sport aftermarket pads and all rotor aftermarket numbers: no fetchable fitment page.
#   Suspension:
#   -- Front lower control arms: two parallel Ford families for 2013-2020 (GS7Z-3078-B/-3079-B and
#      FG9Z-3078-H/-3079-H, plus HG9Z-3078-A/-3079-A for hybrid and 2.7) with identical engine lists
#      and no stated deciding factor; MCF- numbers they supersede are in the agent notes. Check by VIN.
#   -- Rear shocks 2017-2020 (all I4 and hybrids): split by assembly plant (Flat Rock / Hermosillo),
#      High Ride and wheels; candidates HG9Z-18125-P/-L/-G/-H/-F/-N/-J and their AE/AJ/AD/AG/AF/AH successors.
#   -- Rear shock 2013-2016 for 2.0 EcoBoost AWD and 2.0 HEV: lead ASH24665 = DG9Z-18125-S (85%).
#   -- Front strut right 2013-2016 for HEV/PHEV: catalogs disagree whether DG9Z-18124-Z covers hybrids.
#   -- Front stabilizer link on Sport: fordpartsdeal lists it, fordpartsgiant 2020 diagram says "no Sport".
#   -- Rear stabilizer link AWD / Sport: lead Motorcraft MEF-241, page returned 403.
#   -- Rear hub AWD: probably DG9Z-1104-T (same as front), not stated explicitly.
#   -- Rear hub 2013 FWD and all Energi: DG9Z-1109-C fitment starts 2014 "without Energi".
#   -- Current Motorcraft HUB-/MEF-/AD- SKUs: none found on ford.com; only superseded ones listed.
#   -- Hub aftermarket (Moog 512497/512498, Timken HA590480/481/601, SKF BR930874/913): resellers contradict.
#   -- KYB 334983/334984 (no OE numbers on reachable page); Monroe, Gabriel, Delphi TC3424, Mevotech MS408118 unreachable.

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
    year_from   smallint NOT NULL,
    year_to     smallint NOT NULL,
    engine_code text NOT NULL,
    trims       text[],          -- NULL = all trims of that engine
    notes       text
) ON COMMIT DROP;

-- ============================================================
-- DATA
-- ============================================================
-- ---------- Filters & ignition ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  ('oil-filter-4cyl',     'oil-filters',    'Mühərrik yağ filtri',                        'Масляный фильтр двигателя',                     'Engine oil filter',                            'Motorcraft', 'FL-910S',       'Motorcraft', NULL, 'All four-cylinder engines incl. Hybrid and Energi, MY2013-2020; no mid-cycle change. Manuals: if unavailable use a filter meeting SAE/USCAR-36.'),
  ('oil-filter-27v6',     'oil-filters',    'Mühərrik yağ filtri (2.7 EcoBoost V6)',      'Масляный фильтр двигателя (2.7 EcoBoost V6)',   'Engine oil filter (2.7 EcoBoost V6)',          'Motorcraft', 'FL-2062',       'Motorcraft', NULL, 'Fusion Sport 2.7 EcoBoost only; current Ford number KU2Z-6731-A.'),
  ('air-filter-gas',      'air-filters',    'Mühərrik hava filtri',                       'Воздушный фильтр двигателя',                    'Engine air filter',                            'Motorcraft', 'FA-1912',       'Motorcraft', NULL, 'All gasoline engines incl. 2.7 V6, MY2013-2020; FA-1912A is the current revision (Ford DS7Z-9601-D). Not for Hybrid/Energi.'),
  ('air-filter-hybrid',   'air-filters',    'Mühərrik hava filtri (Hybrid / Energi)',     'Воздушный фильтр двигателя (Hybrid / Energi)',  'Engine air filter (Hybrid / Energi)',          'Motorcraft', 'FA-1911',       'Motorcraft', NULL, 'Fusion Hybrid and Energi only (Ford DG9Z-9601-A); does not interchange with FA-1912.'),
  ('cabin-filter',        'cabin-filters',  'Salon filtri',                               'Салонный фильтр',                               'Cabin air filter',                             'Motorcraft', 'FP-71',         'Motorcraft', NULL, 'One cabin filter for the whole CD391 line, MY2013-2020; FP-71A is the current revision. Glovebox comes out to fit it.'),
  ('spark-plug-25-hev',   'spark-plugs',    'Alışdırma şamı (2.5 Duratec / Hybrid)',      'Свеча зажигания (2.5 Duratec / Hybrid)',        'Spark plug (2.5 Duratec / Hybrid / Energi)',   'Motorcraft', 'SP-530',        'Motorcraft', NULL, '4 per car. Gap 2.5L: 1.25-1.35 mm; Hybrid 2.0 Atkinson: 1.3 mm +/- 0.05. Current iridium supersession SP530X (AYFS-32Y-RX). Interval 100,000 mi / 60,000 mi severe.'),
  ('spark-plug-20eb',     'spark-plugs',    'Alışdırma şamı (2.0 EcoBoost)',              'Свеча зажигания (2.0 EcoBoost)',                'Spark plug (2.0 EcoBoost)',                    'Motorcraft', 'SP550X',        'Motorcraft', NULL, '4 per car. Gap 0.70-0.80 mm. Spec changed during the run (SP-527 MY2013, SP-537 MY2014-2017, SP-550 MY2020); Ford now supplies SP550X (CYFS-12Y-PCTX) for all years.'),
  ('spark-plug-16eb',     'spark-plugs',    'Alışdırma şamı (1.6 EcoBoost)',              'Свеча зажигания (1.6 EcoBoost)',                'Spark plug (1.6 EcoBoost)',                    'Motorcraft', 'SP-532',        'Motorcraft', NULL, '4 per car. Gap 0.70-0.80 mm. Current Ford number CYFS-13Y-RCX.'),
  ('spark-plug-15eb',     'spark-plugs',    'Alışdırma şamı (1.5 EcoBoost)',              'Свеча зажигания (1.5 EcoBoost)',                'Spark plug (1.5 EcoBoost)',                    'Motorcraft', 'SP-539',        'Motorcraft', NULL, '4 per car. Gap 0.65-0.75 mm. Current Ford number HYFS-094-YECX.'),
  ('spark-plug-27v6',     'spark-plugs',    'Alışdırma şamı (2.7 EcoBoost V6)',           'Свеча зажигания (2.7 EcoBoost V6)',             'Spark plug (2.7 EcoBoost V6)',                 'Motorcraft', 'SP-542',        'Motorcraft', NULL, '6 per car. Gap 0.7-0.8 mm. MY2017 owner''s manual spec; MY2018-2019 sources conflict (SP-545 / SP594), confirm with a Ford counter before stocking.'),
  ('coil-20eb',           'ignition-coils', 'Alışdırma bobini (2.0 EcoBoost)',            'Катушка зажигания (2.0 EcoBoost)',              'Ignition coil (2.0 EcoBoost)',                 'Motorcraft', 'CM5Z-12029-K',  'Ford',       NULL, 'Coil-on-plug, 4 per car. Motorcraft DG562; original fit DG-546.'),
  ('coil-15eb',           'ignition-coils', 'Alışdırma bobini (1.5 EcoBoost)',            'Катушка зажигания (1.5 EcoBoost)',              'Ignition coil (1.5 EcoBoost)',                 'Motorcraft', 'DS7Z-12029-B',  'Ford',       NULL, 'Coil-on-plug, 4 per car. Motorcraft DG-552 (superseded).'),
  ('coil-25-hev',         'ignition-coils', 'Alışdırma bobini (2.5 Duratec / Hybrid)',    'Катушка зажигания (2.5 Duratec / Hybrid)',      'Ignition coil (2.5 Duratec / Hybrid / Energi)','Ford',       '9E5Z-12029-A',  'Ford',       NULL, 'Coil-on-plug, 4 per car. Motorcraft DG number not verified.'),
  ('coil-27v6',           'ignition-coils', 'Alışdırma bobini (2.7 EcoBoost V6)',         'Катушка зажигания (2.7 EcoBoost V6)',           'Ignition coil (2.7 EcoBoost V6)',              'Ford',       'FT4Z-12029-A',  'Ford',       NULL, 'Coil-on-plug, 6 per car. Motorcraft DG number not verified.'),
  ('coil-16eb',           'ignition-coils', 'Alışdırma bobini (1.6 EcoBoost)',            'Катушка зажигания (1.6 EcoBoost)',              'Ignition coil (1.6 EcoBoost)',                 'Ford',       'BM5Z-12029-B',  'Ford',       NULL, 'Coil-on-plug, 4 per car. Motorcraft DG number not found.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('oil-filter-4cyl',   'PH3614',         'AFTERMARKET', 'FRAM'),
  ('oil-filter-4cyl',   '51348',          'AFTERMARKET', 'WIX'),
  ('oil-filter-27v6',   'KU2Z-6731-A',    'OEM', 'Ford'),
  ('oil-filter-27v6',   'FT4Z-6731-A',    'OEM', 'Ford'),
  ('air-filter-gas',    'FA-1912A',       'OEM', 'Motorcraft'),
  ('air-filter-gas',    'DS7Z-9601-D',    'OEM', 'Ford'),
  ('air-filter-gas',    'DS7Z-9601-A',    'OEM', 'Ford'),
  ('air-filter-gas',    'CA11480',        'AFTERMARKET', 'FRAM'),
  ('air-filter-gas',    'WA10048',        'AFTERMARKET', 'WIX'),
  ('air-filter-gas',    'PA4471',         'AFTERMARKET', 'Baldwin'),
  ('air-filter-hybrid', 'DG9Z-9601-A',    'OEM', 'Ford'),
  ('air-filter-hybrid', 'CA11482',        'AFTERMARKET', 'FRAM'),
  ('cabin-filter',      'FP-71A',         'OEM', 'Motorcraft'),
  ('cabin-filter',      'DG9Z-19N619-A',  'OEM', 'Ford'),
  ('cabin-filter',      'DG9Z-19N619-AA', 'OEM', 'Ford'),
  ('cabin-filter',      'CF11775',        'AFTERMARKET', 'FRAM'),
  ('spark-plug-25-hev', 'SP530X',         'OEM', 'Motorcraft'),
  ('spark-plug-25-hev', 'AYFS-32Y-RX',    'OEM', 'Ford'),
  ('spark-plug-25-hev', 'AYFS-32Y-R',     'OEM', 'Ford'),
  ('spark-plug-20eb',   'SP-527',         'OEM', 'Motorcraft'),
  ('spark-plug-20eb',   'SP-537',         'OEM', 'Motorcraft'),
  ('spark-plug-20eb',   'SP-550',         'OEM', 'Motorcraft'),
  ('spark-plug-20eb',   'CYFS-12Y-PCTX',  'OEM', 'Ford'),
  ('spark-plug-20eb',   'CYFS-12Y-PCT',   'OEM', 'Ford'),
  ('spark-plug-20eb',   'CYFS-12Y-PC',    'OEM', 'Ford'),
  ('spark-plug-20eb',   'CYFS-12Y-2',     'OEM', 'Ford'),
  ('spark-plug-16eb',   'CYFS-13Y-RCX',   'OEM', 'Ford'),
  ('spark-plug-16eb',   'CYFS-13Y-RC',    'OEM', 'Ford'),
  ('spark-plug-15eb',   'HYFS-094-YECX',  'OEM', 'Ford'),
  ('spark-plug-15eb',   'HYFS-094-YEC',   'OEM', 'Ford'),
  ('coil-20eb',         'DG562',          'OEM', 'Motorcraft'),
  ('coil-20eb',         'DG-546',         'OEM', 'Motorcraft'),
  ('coil-20eb',         'CM5Z-12029-A',   'OEM', 'Ford'),
  ('coil-15eb',         'DG-552',         'OEM', 'Motorcraft'),
  ('coil-15eb',         'DS7Z-12029-A',   'OEM', 'Ford');

INSERT INTO seed_fits (key, year_from, year_to, engine_code, trims, notes) VALUES
  ('oil-filter-4cyl',   2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('oil-filter-4cyl',   2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('oil-filter-4cyl',   2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('oil-filter-4cyl',   2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('oil-filter-4cyl',   2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('oil-filter-4cyl',   2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('oil-filter-27v6',   2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('air-filter-gas',    2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('air-filter-gas',    2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('air-filter-gas',    2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('air-filter-gas',    2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('air-filter-gas',    2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('air-filter-hybrid', 2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('air-filter-hybrid', 2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('cabin-filter',      2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('cabin-filter',      2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('cabin-filter',      2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('cabin-filter',      2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('cabin-filter',      2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('cabin-filter',      2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('cabin-filter',      2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('spark-plug-25-hev', 2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('spark-plug-25-hev', 2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('spark-plug-25-hev', 2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('spark-plug-20eb',   2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('spark-plug-16eb',   2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('spark-plug-15eb',   2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('spark-plug-27v6',   2017, 2017, '2.7 EcoBoost V6',   ARRAY['Sport'], 'MY2017 manual spec; MY2018-2019 unconfirmed'),
  ('coil-20eb',         2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('coil-15eb',         2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('coil-25-hev',       2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('coil-25-hev',       2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('coil-25-hev',       2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('coil-27v6',         2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('coil-16eb',         2013, 2014, '1.6 EcoBoost',      NULL, NULL);

-- ---------- Belts, cooling, battery, wipers ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  -- belts & tensioners
  ('belt-main-25',        'drive-belts',  'Generator qayışı, əsas uzun (2.5 Duratec)',               'Ремень приводной основной, длинный (2.5 Duratec)',            'Serpentine belt, main long belt (2.5 Duratec)',               'Motorcraft', 'CV6Z-8620-E',   'Ford',       NULL, 'Motorcraft JK4542B. Main accessory belt, first pulley groove; the 2.5 also has a separate short A/C belt (DA8Z-8620-A). Not for cars with Power Point Plug.'),
  ('belt-main-20eb',      'drive-belts',  'Generator qayışı, əsas uzun (2.0 EcoBoost)',              'Ремень приводной основной, длинный (2.0 EcoBoost)',           'Serpentine belt, main long belt (2.0 EcoBoost)',              'Ford',       'DA8Z-8620-G',   'Ford',       NULL, 'Supersedes Motorcraft JK4-546 / JK4-546-B. Ford also lists CV6Z-8620-E against some 2.0 EcoBoost cars; VIN-check. Separate short A/C belt DA8Z-8620-A.'),
  ('belt-ac-20-25',       'drive-belts',  'Kondisioner kompressoru qayışı, qısa (2.0 EcoBoost / 2.5)','Ремень компрессора кондиционера, короткий (2.0 EcoBoost / 2.5)','A/C compressor belt, short (2.0 EcoBoost / 2.5)',           'Ford',       'DA8Z-8620-A',   'Ford',       NULL, 'Stretch belt, no tensioner, second pulley groove. Motorcraft number not verified.'),
  ('belt-kit-15eb',       'drive-belts',  'Qayış dəsti, stretch qayış + alət (1.5 EcoBoost)',        'Комплект ремня, stretch-ремень + инструмент (1.5 EcoBoost)',  'Serpentine belt kit, stretch belt + tool (1.5 EcoBoost)',     'Motorcraft', 'GS7Z-8620-C',   'Ford',       NULL, 'Motorcraft JK6424B. Kit: stretch belt, service tool, instruction sheet. Catalogued for MY2017-2020; earlier years not confirmed.'),
  ('belt-16eb',           'drive-belts',  'Generator qayışı (1.6 EcoBoost)',                         'Ремень приводной (1.6 EcoBoost)',                             'Serpentine belt (1.6 EcoBoost)',                              'Ford',       'DS7Z-8620-A',   'Ford',       NULL, 'No Motorcraft number found (JK6407A is a Fiesta part, do not substitute).'),
  ('belt-27v6',           'drive-belts',  'Generator qayışı (2.7 EcoBoost V6)',                      'Ремень приводной (2.7 EcoBoost V6)',                          'Serpentine belt (2.7 EcoBoost V6)',                           'Ford',       'F2GZ-8620-A',   'Ford',       NULL, 'Fusion Sport. No Motorcraft number confirmed.'),
  ('tensioner-20-25',     'drive-belts',  'Qayış dartıcısı (2.0 EcoBoost / 2.5)',                    'Натяжитель ремня (2.0 EcoBoost / 2.5)',                       'Belt tensioner (2.0 EcoBoost / 2.5)',                         'Motorcraft', 'DS7Z-6A228-A',  'Ford',       NULL, 'Motorcraft BT121. Tensions the main belt; the A/C stretch belt has none.'),
  ('tensioner-15eb',      'drive-belts',  'Qayış dartıcısı (1.5 EcoBoost)',                          'Натяжитель ремня (1.5 EcoBoost)',                             'Belt tensioner (1.5 EcoBoost)',                               'Motorcraft', 'DS7Z-6A228-B',  'Ford',       NULL, 'Motorcraft BT123.'),
  ('tensioner-16eb',      'drive-belts',  'Qayış dartıcısı (1.6 EcoBoost)',                          'Натяжитель ремня (1.6 EcoBoost)',                             'Belt tensioner (1.6 EcoBoost)',                               'Ford',       'BM5Z-6A228-A',  'Ford',       NULL, 'No Motorcraft number found (BT181 is a different Ford number).'),
  ('tensioner-27v6',      'drive-belts',  'Qayış dartıcısı (2.7 EcoBoost V6)',                       'Натяжитель ремня (2.7 EcoBoost V6)',                          'Belt tensioner (2.7 EcoBoost V6)',                            'Ford',       'F2GZ-6A228-B',  'Ford',       NULL, 'Supersedes Motorcraft BT-129. Current Motorcraft SKU reportedly BT-139 (unverified).'),
  -- thermostats
  ('thermostat-25',       'thermostats',  'Termostat, korpusla, 82°C (2.5 Duratec)',                 'Термостат с корпусом, 82°C (2.5 Duratec)',                    'Thermostat with water outlet housing, 82 C (2.5 Duratec)',    'Ford',       '3M4Z-8575-B',   'Ford',       NULL, 'Includes gasket. Motorcraft RT-1193 likely but unverified.'),
  ('thermostat-20eb-a',   'thermostats',  'Termostat, qapaqla (2.0 EcoBoost, 2013-2016)',            'Термостат с крышкой корпуса (2.0 EcoBoost, 2013-2016)',       'Thermostat assembly with housing cover (2.0 EcoBoost, 2013-2016)', 'Ford',  'CJ5Z-8575-A',   'Ford',       NULL, 'Mid-cycle change: FR3Z-8575-A / RT1233 from MY2017. Motorcraft RT-1221 likely but unverified.'),
  ('thermostat-20eb-b',   'thermostats',  'Termostat, korpusla (2.0 EcoBoost, 2017-2020)',           'Термостат с корпусом (2.0 EcoBoost, 2017-2020)',              'Thermostat unit with housing (2.0 EcoBoost, 2017-2020)',      'Motorcraft', 'FR3Z-8575-A',   'Ford',       NULL, 'Motorcraft RT1233.'),
  ('thermostat-15eb',     'thermostats',  'Termostat, inteqrasiya olunmuş korpusla (1.5 EcoBoost)',  'Термостат с интегрированным корпусом (1.5 EcoBoost)',         'Thermostat unit, integrated water outlet (1.5 EcoBoost)',     'Ford',       'DS7Z-8592-F',   'Ford',       NULL, 'For vehicles built on 3/21/2013 and later. Motorcraft RH-224 likely but unverified.'),
  ('thermostat-27v6',     'thermostats',  'Termostat (2.7 EcoBoost V6)',                             'Термостат (2.7 EcoBoost V6)',                                 'Thermostat assembly (2.7 EcoBoost V6)',                       'Ford',       'BR3Z-8575-F',   'Ford',       NULL, 'Supersedes Motorcraft RT-1217 / RT-1227; current SKU reportedly RT-1251 (unverified).'),
  ('thermostat-hev',      'thermostats',  'Termostat (Hybrid / Energi)',                             'Термостат (Hybrid / Energi)',                                 'Thermostat assembly (Hybrid / Energi)',                       'Ford',       'DS7Z-8575-C',   'Ford',       NULL, 'Supersedes Motorcraft RT-1223 / RT-1226. Housing DS7Z-8A586-D sold separately.'),
  -- water pumps
  ('waterpump-25',        'water-pumps',  'Su nasosu, qasnaqla (2.5 Duratec)',                       'Водяной насос (помпа) со шкивом (2.5 Duratec)',               'Engine water pump with 3-bolt pulley (2.5 Duratec)',          'Motorcraft', '4S4Z-8501-E',   'Ford',       NULL, 'Motorcraft PW624. Belt-driven; gasket 1S7Z-8507-AE sold separately.'),
  ('waterpump-20eb-a',    'water-pumps',  'Su nasosu (2.0 EcoBoost, 2013-2016)',                     'Водяной насос (помпа) (2.0 EcoBoost, 2013-2016)',             'Engine water pump (2.0 EcoBoost, 2013-2016)',                 'Motorcraft', '1S7Z-8501-K',   'Ford',       NULL, 'Motorcraft PW579. Mid-cycle change to EJ7Z-8501-F / PW578 at MY2017.'),
  ('waterpump-20eb-b',    'water-pumps',  'Su nasosu (2.0 EcoBoost, 2017-2020)',                     'Водяной насос (помпа) (2.0 EcoBoost, 2017-2020)',             'Engine water pump (2.0 EcoBoost, 2017-2020)',                 'Motorcraft', 'EJ7Z-8501-F',   'Ford',       NULL, 'Motorcraft PW578.'),
  ('waterpump-15eb',      'water-pumps',  'Su nasosu (1.5 EcoBoost)',                                'Водяной насос (помпа) (1.5 EcoBoost)',                        'Engine water pump (1.5 EcoBoost)',                            'Motorcraft', 'DS7Z-8501-E',   'Ford',       NULL, 'Motorcraft PW556. Belt-driven (own pulley DS7Z-8509-A); has a wiring connector, Ford advises splicing the new connector.'),
  ('waterpump-16eb',      'water-pumps',  'Su nasosu (1.6 EcoBoost)',                                'Водяной насос (помпа) (1.6 EcoBoost)',                        'Engine water pump (1.6 EcoBoost)',                            'Motorcraft', '7S7Z-8501-C',   'Ford',       NULL, 'Motorcraft PW545. Belt-driven; gasket BE8Z-8507-A not included.'),
  ('waterpump-27v6',      'water-pumps',  'Su nasosu (2.7 EcoBoost V6)',                             'Водяной насос (помпа) (2.7 EcoBoost V6)',                     'Engine water pump (2.7 EcoBoost V6)',                         'Motorcraft', 'FT4Z-8501-C',   'Ford',       NULL, 'Motorcraft PW576. For 4-bolt pulley flange.'),
  ('auxpump-hev',         'water-pumps',  'Əlavə elektrik soyuducu nasosu (Hybrid)',                 'Дополнительный электрический насос ОЖ (Hybrid)',              'Auxiliary electric coolant pump (Hybrid)',                    'Motorcraft', 'DS7Z-8C419-E',  'Ford',       NULL, 'Motorcraft PW589, attaches to radiator. Energi applicability not stated separately.'),
  -- batteries
  ('battery-gas-ia',      'batteries',    'Akkumulyator 12V, qrup 90, 590 CCA (Intelligent Access)', 'Аккумулятор 12 В, группа 90, 590 CCA (Intelligent Access)',   '12 V battery, BCI group 90, 590 CCA (Intelligent Access)',    'Motorcraft', 'BXT-90T5-590',  'Motorcraft', NULL, 'Gas cars with keyless entry/start. Early MY2013-2014 manual printings list BXT-96R-590 instead; check the fitted battery.'),
  ('battery-gas-base',    'batteries',    'Akkumulyator 12V, qrup 90, 500 CCA',                      'Аккумулятор 12 В, группа 90, 500 CCA',                        '12 V battery, BCI group 90, 500 CCA',                         'Motorcraft', 'BXT-90T5-500',  'Motorcraft', NULL, 'Gas cars without keyless entry. Early MY2013-2014 manual printings list BXT-96R-500 instead.'),
  ('battery-gas-ss',      'batteries',    'Akkumulyator 12V AGM, qrup 48 (H6), 760 CCA, 70 Ah (Start-Stop)', 'Аккумулятор 12 В AGM, группа 48 (H6), 760 CCA, 70 Ач (Start-Stop)', '12 V AGM battery, group 48 (H6), 760 CCA, 70 Ah (Auto Start-Stop)', 'Motorcraft', 'BAGM-48H6-760', 'Motorcraft', NULL, 'Only cars fitted with Auto Start-Stop. Supersedes BAGM-48-760, BEF-48H6, BEF-48H6-A, BHEF-48H6.'),
  ('battery-hybrid-12v',  'batteries',    'Akkumulyator 12V köməkçi, qrup 99R (Hybrid / Energi)',    'Аккумулятор 12 В вспомогательный, группа 99R (Hybrid / Energi)', '12 V auxiliary battery, BCI group 99R (Hybrid / Energi)',  'Motorcraft', 'BXT-99RT4-A',   'Motorcraft', NULL, 'Owner''s manual number BXT-99RT4-390, superseded by BXT-99RT4-A. Differs from gas cars (group 99R vs 90).'),
  -- wipers (no rear wiper on CD391)
  ('wiper-front-left',    'wiper-blades', 'Şüşəsilən fırçası, ön sol (sürücü), 26" / 660 mm',        'Щётка стеклоочистителя передняя левая (водительская), 26" / 660 мм', 'Front wiper blade, driver side, 26 in / 660 mm',       'Motorcraft', 'WW2601A',       'Motorcraft', 'FRONT_LEFT',  'Owner''s manual: WW-2601 (driver side). Ford DS7Z-17528-AA. Standard blade; premium flat blade AU2Z-17V528-JA also catalogued.'),
  ('wiper-front-right',   'wiper-blades', 'Şüşəsilən fırçası, ön sağ (sərnişin), 27"',              'Щётка стеклоочистителя передняя правая (пассажирская), 27"',   'Front wiper blade, passenger side, 27 in',                    'Motorcraft', 'WW2700A',       'Motorcraft', 'FRONT_RIGHT', 'Owner''s manual: WW-2700 (passenger side). Ford DS7Z-17528-BA. Ford 2013 diagram describes the original blade as 26 in; Motorcraft sells 27 in.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('belt-main-25',       'JK4542B',        'OEM', 'Motorcraft'),
  ('belt-main-25',       'JK4-542',        'OEM', 'Motorcraft'),
  ('belt-main-25',       'JK4-542-A',      'OEM', 'Motorcraft'),
  ('belt-main-25',       'CV6Z-8620-A',    'OEM', 'Ford'),
  ('belt-main-25',       'CV6Z-8620-C',    'OEM', 'Ford'),
  ('belt-main-25',       'CV6Z-8620-D',    'OEM', 'Ford'),
  ('belt-main-20eb',     'JK4-546',        'OEM', 'Motorcraft'),
  ('belt-main-20eb',     'JK4-546-B',      'OEM', 'Motorcraft'),
  ('belt-main-20eb',     'DA8Z-8620-B',    'OEM', 'Ford'),
  ('belt-main-20eb',     'DA8Z-8620-H',    'OEM', 'Ford'),
  ('belt-kit-15eb',      'JK6424B',        'OEM', 'Motorcraft'),
  ('belt-kit-15eb',      'JK6-626',        'OEM', 'Motorcraft'),
  ('belt-kit-15eb',      'DS7Z-8620-B',    'OEM', 'Ford'),
  ('tensioner-20-25',    'BT121',          'OEM', 'Motorcraft'),
  ('tensioner-15eb',     'BT123',          'OEM', 'Motorcraft'),
  ('tensioner-27v6',     'BT-129',         'OEM', 'Motorcraft'),
  ('tensioner-27v6',     'F2GZ-6A228-A',   'OEM', 'Ford'),
  ('thermostat-25',      '3M4Z-8575-A',    'OEM', 'Ford'),
  ('thermostat-25',      '3M4Z-8575-AB',   'OEM', 'Ford'),
  ('thermostat-20eb-b',  'RT1233',         'OEM', 'Motorcraft'),
  ('thermostat-27v6',    'RT-1217',        'OEM', 'Motorcraft'),
  ('thermostat-27v6',    'RT-1227',        'OEM', 'Motorcraft'),
  ('thermostat-27v6',    'BR3Z-8575-C',    'OEM', 'Ford'),
  ('thermostat-27v6',    'BR3Z-8575-E',    'OEM', 'Ford'),
  ('thermostat-hev',     'RT-1223',        'OEM', 'Motorcraft'),
  ('thermostat-hev',     'RT-1226',        'OEM', 'Motorcraft'),
  ('thermostat-hev',     'DS7Z-8575-A',    'OEM', 'Ford'),
  ('thermostat-hev',     'DS7Z-8575-B',    'OEM', 'Ford'),
  ('waterpump-25',       'PW624',          'OEM', 'Motorcraft'),
  ('waterpump-25',       'PW-447',         'OEM', 'Motorcraft'),
  ('waterpump-25',       'PW-465',         'OEM', 'Motorcraft'),
  ('waterpump-25',       '4S4Z-8501-AA',   'OEM', 'Ford'),
  ('waterpump-25',       '4S4Z-8501-D',    'OEM', 'Ford'),
  ('waterpump-25',       '1S7Z-8501-AK',   'OEM', 'Ford'),
  ('waterpump-25',       '6M8Z-8501-AC',   'OEM', 'Ford'),
  ('waterpump-20eb-a',   'PW579',          'OEM', 'Motorcraft'),
  ('waterpump-20eb-a',   'PW-501',         'OEM', 'Motorcraft'),
  ('waterpump-20eb-a',   'PW-572',         'OEM', 'Motorcraft'),
  ('waterpump-20eb-a',   '1S7Z-8501-A',    'OEM', 'Ford'),
  ('waterpump-20eb-a',   '1S7Z-8501-D',    'OEM', 'Ford'),
  ('waterpump-20eb-b',   'PW578',          'OEM', 'Motorcraft'),
  ('waterpump-20eb-b',   'PW-548',         'OEM', 'Motorcraft'),
  ('waterpump-20eb-b',   'PW-559',         'OEM', 'Motorcraft'),
  ('waterpump-20eb-b',   'EJ7Z-8501-A',    'OEM', 'Ford'),
  ('waterpump-20eb-b',   'EJ7Z-8501-C',    'OEM', 'Ford'),
  ('waterpump-15eb',     'PW556',          'OEM', 'Motorcraft'),
  ('waterpump-15eb',     'PW-541',         'OEM', 'Motorcraft'),
  ('waterpump-15eb',     'DS7Z-8501-D',    'OEM', 'Ford'),
  ('waterpump-16eb',     'PW545',          'OEM', 'Motorcraft'),
  ('waterpump-16eb',     'PW-537',         'OEM', 'Motorcraft'),
  ('waterpump-16eb',     '7S7Z-8501-A',    'OEM', 'Ford'),
  ('waterpump-27v6',     'PW576',          'OEM', 'Motorcraft'),
  ('waterpump-27v6',     'PW-554',         'OEM', 'Motorcraft'),
  ('waterpump-27v6',     'FT4Z-8501-A',    'OEM', 'Ford'),
  ('auxpump-hev',        'PW589',          'OEM', 'Motorcraft'),
  ('auxpump-hev',        'PW-528',         'OEM', 'Motorcraft'),
  ('auxpump-hev',        'DS7Z-8C419-A',   'OEM', 'Ford'),
  ('battery-gas-ss',     'BAGM-48-760',    'OEM', 'Motorcraft'),
  ('battery-gas-ss',     'BEF-48H6',       'OEM', 'Motorcraft'),
  ('battery-gas-ss',     'BEF-48H6-A',     'OEM', 'Motorcraft'),
  ('battery-gas-ss',     'BHEF-48H6',      'OEM', 'Motorcraft'),
  ('battery-hybrid-12v', 'BXT-99RT4-390',  'OEM', 'Motorcraft'),
  ('wiper-front-left',   'WW-2601',        'OEM', 'Motorcraft'),
  ('wiper-front-left',   'DS7Z-17528-AA',  'OEM', 'Ford'),
  ('wiper-front-left',   'DS7Z-17528-A',   'OEM', 'Ford'),
  ('wiper-front-right',  'WW-2700',        'OEM', 'Motorcraft'),
  ('wiper-front-right',  'DS7Z-17528-BA',  'OEM', 'Ford'),
  ('wiper-front-right',  'DS7Z-17528-B',   'OEM', 'Ford');

INSERT INTO seed_fits (key, year_from, year_to, engine_code, trims, notes) VALUES
  -- belts & tensioners
  ('belt-main-25',       2013, 2020, '2.5 Duratec iVCT',  NULL, 'Without Power Point Plug'),
  ('belt-main-20eb',     2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('belt-ac-20-25',      2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('belt-ac-20-25',      2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('belt-kit-15eb',      2017, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('belt-16eb',          2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('belt-27v6',          2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('tensioner-20-25',    2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('tensioner-20-25',    2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('tensioner-15eb',     2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('tensioner-16eb',     2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('tensioner-27v6',     2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  -- thermostats
  ('thermostat-25',      2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('thermostat-20eb-a',  2013, 2016, '2.0 EcoBoost',      NULL, NULL),
  ('thermostat-20eb-b',  2017, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('thermostat-15eb',    2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('thermostat-27v6',    2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('thermostat-hev',     2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('thermostat-hev',     2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  -- water pumps
  ('waterpump-25',       2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('waterpump-20eb-a',   2013, 2016, '2.0 EcoBoost',      NULL, NULL),
  ('waterpump-20eb-b',   2017, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('waterpump-15eb',     2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('waterpump-16eb',     2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('waterpump-27v6',     2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('auxpump-hev',        2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  -- batteries
  ('battery-gas-ia',     2013, 2020, '2.5 Duratec iVCT',  NULL, 'With Intelligent Access (keyless)'),
  ('battery-gas-ia',     2013, 2020, '2.0 EcoBoost',      NULL, 'With Intelligent Access (keyless)'),
  ('battery-gas-ia',     2014, 2020, '1.5 EcoBoost',      NULL, 'With Intelligent Access (keyless)'),
  ('battery-gas-ia',     2013, 2014, '1.6 EcoBoost',      NULL, 'With Intelligent Access (keyless)'),
  ('battery-gas-base',   2013, 2020, '2.5 Duratec iVCT',  NULL, 'Without keyless entry'),
  ('battery-gas-base',   2013, 2020, '2.0 EcoBoost',      NULL, 'Without keyless entry'),
  ('battery-gas-base',   2014, 2020, '1.5 EcoBoost',      NULL, 'Without keyless entry'),
  ('battery-gas-base',   2013, 2014, '1.6 EcoBoost',      NULL, 'Without keyless entry'),
  ('battery-gas-ss',     2013, 2020, '2.5 Duratec iVCT',  NULL, 'Auto Start-Stop cars only'),
  ('battery-gas-ss',     2013, 2020, '2.0 EcoBoost',      NULL, 'Auto Start-Stop cars only'),
  ('battery-gas-ss',     2014, 2020, '1.5 EcoBoost',      NULL, 'Auto Start-Stop cars only'),
  ('battery-gas-ss',     2013, 2014, '1.6 EcoBoost',      NULL, 'Auto Start-Stop cars only'),
  ('battery-hybrid-12v', 2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('battery-hybrid-12v', 2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  -- wipers
  ('wiper-front-left',   2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('wiper-front-left',   2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('wiper-front-left',   2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('wiper-front-left',   2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('wiper-front-left',   2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('wiper-front-left',   2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('wiper-front-left',   2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('wiper-front-right',  2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('wiper-front-right',  2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('wiper-front-right',  2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('wiper-front-right',  2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('wiper-front-right',  2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('wiper-front-right',  2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('wiper-front-right',  2013, 2020, '2.0 Atkinson PHEV', NULL, NULL);

-- ---------- Brakes ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  ('front-pads-std-2013-2016', 'brake-pads', 'Ön əyləc kolodkaları dəsti',                   'Колодки тормозные передние, комплект',                    'Front brake pad set',                    'Motorcraft', 'DG9Z-2001-F',  'Ford', 'FRONT', 'Standard brakes (non-Sport, non-hybrid), MY2013-2016. Ford note: "Without Sport, Without Hybrid Or Energi".'),
  ('front-pads-std-2017-2020', 'brake-pads', 'Ön əyləc kolodkaları dəsti',                   'Колодки тормозные передние, комплект',                    'Front brake pad set',                    'Ford',       'LG9Z-2001-A',  'Ford', 'FRONT', 'Standard brakes (non-Sport, non-hybrid), MY2017-2020. Ford note: "Without Sport, Without Hybrid Or Energi".'),
  ('front-pads-hev-phev',      'brake-pads', 'Ön əyləc kolodkaları dəsti (Hybrid / Energi)', 'Колодки тормозные передние, комплект (Hybrid / Energi)',  'Front brake pad set (Hybrid / Energi)',  'Motorcraft', 'DG9Z-2001-Q',  'Ford', 'FRONT', 'Fusion Hybrid and Energi, MY2013-2020. Ford note: "Without Sport, With Hybrid Or Energi".'),
  ('front-pads-sport',         'brake-pads', 'Ön əyləc kolodkaları dəsti (Sport)',           'Колодки тормозные передние, комплект (Sport)',            'Front brake pad set (Sport)',            'Motorcraft', 'G3GZ-2001-C',  'Ford', 'FRONT', 'Fusion Sport 2.7 EcoBoost (6F55), larger front brakes. Ford note: "With Sport".'),
  ('rear-pads-std',            'brake-pads', 'Arxa əyləc kolodkaları dəsti',                 'Колодки тормозные задние, комплект',                      'Rear brake pad set',                     'Motorcraft', 'DG9Z-2200-N',  'Ford', 'REAR',  'Standard FWD gas cars, MY2013-2020, electric parking brake. Ford note: "Without AWD, Without Hybrid, Without Energi".'),
  ('rear-pads-hev',            'brake-pads', 'Arxa əyləc kolodkaları dəsti (Hybrid)',        'Колодки тормозные задние, комплект (Hybrid)',             'Rear brake pad set (Hybrid)',            'Motorcraft', 'DG9Z-2200-MA', 'Ford', 'REAR',  'Fusion Hybrid, MY2013-2020. Ford note: "Without AWD, With Hybrid, Without Sport".'),
  ('rear-pads-phev',           'brake-pads', 'Arxa əyləc kolodkaları dəsti (Energi)',        'Колодки тормозные задние, комплект (Energi)',             'Rear brake pad set (Energi)',            'Motorcraft', 'DG9Z-2200-R',  'Ford', 'REAR',  'Fusion Energi plug-in, MY2013-2020. Ford note: "Without AWD, With Energi".'),
  ('rear-pads-sport',          'brake-pads', 'Arxa əyləc kolodkaları dəsti (Sport)',         'Колодки тормозные задние, комплект (Sport)',              'Rear brake pad set (Sport)',             'Motorcraft', 'DG9Z-2200-F',  'Ford', 'REAR',  'Fusion Sport 2.7 EcoBoost (6F55). Ford note: "With Sport".'),
  ('front-rotor-std',          'brake-discs','Ön əyləc diski',                               'Тормозной диск передний',                                 'Front brake disc',                       'Motorcraft', 'KS7Z-1125-A',  'Ford', 'FRONT', 'Standard front rotor, sold singly (2 per car). Ford note: "Without Sport, Without Energi".'),
  ('front-rotor-sport',        'brake-discs','Ön əyləc diski (Sport)',                       'Тормозной диск передний (Sport)',                         'Front brake disc (Sport)',               'Motorcraft', 'K2GZ-1125-B',  'Ford', 'FRONT', 'Fusion Sport front rotor, sold singly (2 per car), shared with Lincoln MKZ 3.0 and Edge. Ford note: "With Sport".'),
  ('rear-rotor-std',           'brake-discs','Arxa əyləc diski',                             'Тормозной диск задний',                                   'Rear brake disc',                        'Motorcraft', 'DG9Z-2C026-C', 'Ford', 'REAR',  'Standard rear rotor, sold singly (2 per car), gas and Hybrid with standard suspension. Not Energi, not Sport.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  -- front pads, standard 2013-2016
  ('front-pads-std-2013-2016', 'BRF-1501',     'OEM', 'Motorcraft'),
  ('front-pads-std-2013-2016', 'BRF-31',       'OEM', 'Motorcraft'),
  ('front-pads-std-2013-2016', 'DG9Z-2001-A',  'OEM', 'Ford'),
  ('front-pads-std-2013-2016', 'DG9Z-2001-C',  'OEM', 'Ford'),
  ('front-pads-std-2013-2016', 'P24173N',      'AFTERMARKET', 'Brembo'),
  ('front-pads-std-2013-2016', 'PSB16-1653',   'AFTERMARKET', 'Power Stop'),
  ('front-pads-std-2013-2016', '305.1653',     'AFTERMARKET', 'StopTech'),
  -- front pads, standard 2017-2020
  ('front-pads-std-2017-2020', 'P24173N',      'AFTERMARKET', 'Brembo'),
  ('front-pads-std-2017-2020', 'PSB16-1653',   'AFTERMARKET', 'Power Stop'),
  ('front-pads-std-2017-2020', '305.1653',     'AFTERMARKET', 'StopTech'),
  -- front pads, hybrid / energi
  ('front-pads-hev-phev',      'DG9Z-2001-M',  'OEM', 'Ford'),
  ('front-pads-hev-phev',      'DG9Z-2001-B',  'OEM', 'Ford'),
  ('front-pads-hev-phev',      'DG9Z-2001-D',  'OEM', 'Ford'),
  ('front-pads-hev-phev',      'BRF-1502',     'OEM', 'Motorcraft'),
  ('front-pads-hev-phev',      'BRF-1533',     'OEM', 'Motorcraft'),
  ('front-pads-hev-phev',      'BRF-33',       'OEM', 'Motorcraft'),
  ('front-pads-hev-phev',      'P24173N',      'AFTERMARKET', 'Brembo'),
  ('front-pads-hev-phev',      'PSB16-1653',   'AFTERMARKET', 'Power Stop'),
  -- front pads, sport
  ('front-pads-sport',         'BRF-1536',     'OEM', 'Motorcraft'),
  ('front-pads-sport',         'G3GZ-2001-B',  'OEM', 'Ford'),
  -- rear pads, standard
  ('rear-pads-std',            'BRF-1498',     'OEM', 'Motorcraft'),
  ('rear-pads-std',            'BRF-29',       'OEM', 'Motorcraft'),
  ('rear-pads-std',            'DG9Z-2200-A',  'OEM', 'Ford'),
  ('rear-pads-std',            'DG9Z-2200-J',  'OEM', 'Ford'),
  ('rear-pads-std',            'PSB16-1665',   'AFTERMARKET', 'Power Stop'),
  ('rear-pads-std',            'P24175',       'AFTERMARKET', 'Brembo'),
  -- rear pads, hybrid
  ('rear-pads-hev',            'BRF-1499',     'OEM', 'Motorcraft'),
  ('rear-pads-hev',            'BRF-1555',     'OEM', 'Motorcraft'),
  ('rear-pads-hev',            'BRF-30',       'OEM', 'Motorcraft'),
  ('rear-pads-hev',            'DG9Z-2200-M',  'OEM', 'Ford'),
  ('rear-pads-hev',            'DG9Z-2200-B',  'OEM', 'Ford'),
  ('rear-pads-hev',            'DG9Z-2200-K',  'OEM', 'Ford'),
  ('rear-pads-hev',            'PSB16-1665',   'AFTERMARKET', 'Power Stop'),
  -- rear pads, energi
  ('rear-pads-phev',           'BRF-35',       'OEM', 'Motorcraft'),
  ('rear-pads-phev',           'BRF-1497',     'OEM', 'Motorcraft'),
  ('rear-pads-phev',           'BRF-1492',     'OEM', 'Motorcraft'),
  ('rear-pads-phev',           'DG9Z-2200-C',  'OEM', 'Ford'),
  ('rear-pads-phev',           'DG9Z-2200-H',  'OEM', 'Ford'),
  ('rear-pads-phev',           'DG9Z-2200-G',  'OEM', 'Ford'),
  -- rear pads, sport
  ('rear-pads-sport',          'BRF-1434',     'OEM', 'Motorcraft'),
  ('rear-pads-sport',          'BRF-1500',     'OEM', 'Motorcraft'),
  ('rear-pads-sport',          'DG9Z-2200-D',  'OEM', 'Ford'),
  -- front rotor, standard
  ('front-rotor-std',          'BRRF-307',     'OEM', 'Motorcraft'),
  ('front-rotor-std',          'BRRF-330',     'OEM', 'Motorcraft'),
  ('front-rotor-std',          'BRRF-117',     'OEM', 'Motorcraft'),
  ('front-rotor-std',          'BRRF-328',     'OEM', 'Motorcraft'),
  ('front-rotor-std',          'DG9Z-1125-A',  'OEM', 'Ford'),
  ('front-rotor-std',          'DG9Z-1125-C',  'OEM', 'Ford'),
  ('front-rotor-std',          'DG9Z-1125-G',  'OEM', 'Ford'),
  ('front-rotor-std',          'DG9Z-1125-GA', 'OEM', 'Ford'),
  -- front rotor, sport
  ('front-rotor-sport',        'BRRF-316',     'OEM', 'Motorcraft'),
  ('front-rotor-sport',        'BRRF-319',     'OEM', 'Motorcraft'),
  ('front-rotor-sport',        'BRRF-250',     'OEM', 'Motorcraft'),
  ('front-rotor-sport',        'G3GZ-1125-B',  'OEM', 'Ford'),
  ('front-rotor-sport',        'F2GZ-1125-D',  'OEM', 'Ford'),
  ('front-rotor-sport',        'F2GZ-1125-E',  'OEM', 'Ford'),
  -- rear rotor, standard
  ('rear-rotor-std',           'BRRF-119',     'OEM', 'Motorcraft'),
  ('rear-rotor-std',           'DG9Z-2C026-A', 'OEM', 'Ford');

INSERT INTO seed_fits (key, year_from, year_to, engine_code, trims, notes) VALUES
  -- front pads, standard 2013-2016
  ('front-pads-std-2013-2016', 2013, 2016, '2.5 Duratec iVCT',  NULL, NULL),
  ('front-pads-std-2013-2016', 2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('front-pads-std-2013-2016', 2014, 2016, '1.5 EcoBoost',      NULL, NULL),
  ('front-pads-std-2013-2016', 2013, 2016, '2.0 EcoBoost',      NULL, NULL),
  -- front pads, standard 2017-2020
  ('front-pads-std-2017-2020', 2017, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('front-pads-std-2017-2020', 2017, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('front-pads-std-2017-2020', 2017, 2020, '2.0 EcoBoost',      NULL, NULL),
  -- front pads, hybrid / energi
  ('front-pads-hev-phev',      2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('front-pads-hev-phev',      2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  -- front pads, sport
  ('front-pads-sport',         2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  -- rear pads, standard (FWD only; AWD non-Sport rear pad unverified)
  ('rear-pads-std',            2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('rear-pads-std',            2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('rear-pads-std',            2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('rear-pads-std',            2013, 2020, '2.0 EcoBoost',      NULL, 'FWD only'),
  -- rear pads, hybrid / energi / sport
  ('rear-pads-hev',            2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('rear-pads-phev',           2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('rear-pads-sport',          2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  -- front rotor, standard
  ('front-rotor-std',          2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('front-rotor-std',          2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('front-rotor-std',          2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('front-rotor-std',          2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('front-rotor-std',          2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  -- front rotor, sport
  ('front-rotor-sport',        2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  -- rear rotor, standard (MY2020 and 1.6 EcoBoost not confirmed)
  ('rear-rotor-std',           2013, 2019, '2.5 Duratec iVCT',  NULL, NULL),
  ('rear-rotor-std',           2014, 2019, '1.5 EcoBoost',      NULL, NULL),
  ('rear-rotor-std',           2013, 2019, '2.0 EcoBoost',      NULL, NULL),
  ('rear-rotor-std',           2013, 2019, '2.0 Atkinson HEV',  NULL, NULL);

-- ---------- Suspension ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  -- front struts (bare strut, not a complete spring assembly; qty 1 per side)
  ('fstrut-l-i4',            'shock-absorbers', 'Ön amortizator dayağı, sol (1.5 / 1.6 / 2.5)',                          'Стойка амортизатора передняя левая (1.5 / 1.6 / 2.5)',                         'Front strut, left (1.5 / 1.6 / 2.5)',                              'Motorcraft', 'HG9Z-18124-F',  'Ford', 'FRONT_LEFT',  'Motorcraft AST84751. Standard suspension (not High Ride). Bare strut, qty 1.'),
  ('fstrut-r-i4',            'shock-absorbers', 'Ön amortizator dayağı, sağ (1.5 / 1.6 / 2.5)',                          'Стойка амортизатора передняя правая (1.5 / 1.6 / 2.5)',                        'Front strut, right (1.5 / 1.6 / 2.5)',                             'Motorcraft', 'HG9Z-18124-A',  'Ford', 'FRONT_RIGHT', 'Motorcraft AST24737. Standard suspension (not High Ride). Bare strut, qty 1.'),
  ('fstrut-l-20-16-18',      'shock-absorbers', 'Ön amortizator dayağı, sol (2.0 EcoBoost / Hybrid, 16-18" təkər)',      'Стойка амортизатора передняя левая (2.0 EcoBoost / Hybrid, колёса 16-18")',    'Front strut, left (2.0 EcoBoost / Hybrid, 16-18 in wheels)',       'Motorcraft', 'HG9Z-18124-G',  'Ford', 'FRONT_LEFT',  'Motorcraft AST84752. Cars on 16/17/18 in wheels only; 19 in wheels use HG9Z-18124-AT / DG9Z-18124-Q. Qty 1.'),
  ('fstrut-r-20eb-16-18-a',  'shock-absorbers', 'Ön amortizator dayağı, sağ (2.0 EcoBoost, 16-18" təkər, 2013-2016)',    'Стойка амортизатора передняя правая (2.0 EcoBoost, колёса 16-18", 2013-2016)', 'Front strut, right (2.0 EcoBoost, 16-18 in wheels, 2013-2016)',    'Motorcraft', 'DG9Z-18124-Z',  'Ford', 'FRONT_RIGHT', 'Motorcraft AST24679. Cars on 16/17/18 in wheels only. Hybrid coverage for 2013-2016 unconfirmed. Qty 1.'),
  ('fstrut-r-20-16-18-b',    'shock-absorbers', 'Ön amortizator dayağı, sağ (2.0 EcoBoost / Hybrid, 16-18" təkər, 2017-2020)', 'Стойка амортизатора передняя правая (2.0 EcoBoost / Hybrid, колёса 16-18", 2017-2020)', 'Front strut, right (2.0 EcoBoost / Hybrid, 16-18 in wheels, 2017-2020)', 'Motorcraft', 'HG9Z-18124-L',  'Ford', 'FRONT_RIGHT', 'Motorcraft AST84756. Cars on 16/17/18 in wheels, standard suspension. Qty 1.'),
  ('fstrut-l-20eb-19-a',     'shock-absorbers', 'Ön amortizator dayağı, sol (2.0 EcoBoost, 19" təkər, 2013-2016)',       'Стойка амортизатора передняя левая (2.0 EcoBoost, колёса 19", 2013-2016)',     'Front strut, left (2.0 EcoBoost, 19 in wheels, 2013-2016)',        'Motorcraft', 'DG9Z-18124-Q',  'Ford', 'FRONT_LEFT',  'Motorcraft AST12364. Cars on 19 in wheels only. Qty 1.'),
  ('fstrut-r-20eb-19-a',     'shock-absorbers', 'Ön amortizator dayağı, sağ (2.0 EcoBoost, 19" təkər, 2013-2016)',       'Стойка амортизатора передняя правая (2.0 EcoBoost, колёса 19", 2013-2016)',    'Front strut, right (2.0 EcoBoost, 19 in wheels, 2013-2016)',       'Motorcraft', 'DG9Z-18124-T',  'Ford', 'FRONT_RIGHT', 'Motorcraft AST12367. Cars on 19 in wheels only. Qty 1.'),
  ('fstrut-l-20eb-19-b',     'shock-absorbers', 'Ön amortizator dayağı, sol (2.0 EcoBoost, 19" təkər, 2017-2020)',       'Стойка амортизатора передняя левая (2.0 EcoBoost, колёса 19", 2017-2020)',     'Front strut, left (2.0 EcoBoost, 19 in wheels, 2017-2020)',        'Motorcraft', 'HG9Z-18124-AT', 'Ford', 'FRONT_LEFT',  'Motorcraft AST86034. Cars on 19 in wheels, standard suspension. Qty 1.'),
  ('fstrut-r-20eb-19-b',     'shock-absorbers', 'Ön amortizator dayağı, sağ (2.0 EcoBoost, 19" təkər, 2017-2020)',       'Стойка амортизатора передняя правая (2.0 EcoBoost, колёса 19", 2017-2020)',    'Front strut, right (2.0 EcoBoost, 19 in wheels, 2017-2020)',       'Motorcraft', 'HG9Z-18124-AS', 'Ford', 'FRONT_RIGHT', 'Motorcraft AST86033. Cars on 19 in wheels. Qty 1.'),
  ('fstrut-l-sport',         'shock-absorbers', 'Ön amortizator dayağı, sol (Sport 2.7 V6)',                             'Стойка амортизатора передняя левая (Sport 2.7 V6)',                            'Front strut, left (Sport 2.7 V6)',                                 'Motorcraft', 'HG9Z-18124-D',  'Ford', 'FRONT_LEFT',  'Motorcraft AST24749. Fusion Sport, continuously controlled damping. Qty 1.'),
  ('fstrut-r-sport',         'shock-absorbers', 'Ön amortizator dayağı, sağ (Sport 2.7 V6)',                             'Стойка амортизатора передняя правая (Sport 2.7 V6)',                           'Front strut, right (Sport 2.7 V6)',                                'Ford',       'HG9Z-18124-B',  'Ford', 'FRONT_RIGHT', 'Fusion Sport, continuously controlled damping. No Motorcraft number cited. Qty 1.'),
  -- rear shocks (qty 2 unless a side is stated)
  ('rshock-i4-2013-2016',    'shock-absorbers', 'Arxa amortizator (1.5 / 1.6 / 2.5, 2013-2016)',                        'Амортизатор задний (1.5 / 1.6 / 2.5, 2013-2016)',                              'Rear shock absorber (1.5 / 1.6 / 2.5, 2013-2016)',                 'Ford',       'DG9Z-18125-U',  'Ford', 'REAR',        'Same part both sides, qty 2. 2017-2020 rear shocks depend on assembly plant and are not seeded.'),
  ('rshock-20eb-fwd-16-18',  'shock-absorbers', 'Arxa amortizator (2.0 EcoBoost FWD, 16-18" təkər, 2013-2016)',         'Амортизатор задний (2.0 EcoBoost FWD, колёса 16-18", 2013-2016)',              'Rear shock absorber (2.0 EcoBoost FWD, 16-18 in wheels, 2013-2016)','Ford',      'DG9Z-18125-T',  'Ford', 'REAR',        'FWD, 16/17/18 in wheels, qty 2. Supersedes Motorcraft ASH-24573 / ASH-24519.'),
  ('rshock-20eb-19',         'shock-absorbers', 'Arxa amortizator (2.0 EcoBoost, 19" təkər, 2013-2016)',                'Амортизатор задний (2.0 EcoBoost, колёса 19", 2013-2016)',                     'Rear shock absorber (2.0 EcoBoost, 19 in wheels, 2013-2016)',      'Motorcraft', 'DG9Z-18125-K',  'Ford', 'REAR',        'Motorcraft ASH24572. 19 in wheels only, qty 2.'),
  ('rshock-phev-2013-2016',  'shock-absorbers', 'Arxa amortizator (Energi, 2013-2016)',                                  'Амортизатор задний (Energi, 2013-2016)',                                       'Rear shock absorber (Energi, 2013-2016)',                          'Motorcraft', 'DG9Z-18125-V',  'Ford', 'REAR',        'Motorcraft ASH24682. Fusion Energi plug-in, qty 2.'),
  ('rshock-l-sport',         'shock-absorbers', 'Arxa amortizator, sol (Sport 2.7 V6)',                                  'Амортизатор задний левый (Sport 2.7 V6)',                                      'Rear shock absorber, left (Sport 2.7 V6)',                         'Ford',       'HG9Z-18125-E',  'Ford', 'REAR_LEFT',   'Fusion Sport, continuously controlled damping, qty 1. Sport uses its own upper bracket HG9Z-18A161-A.'),
  ('rshock-r-sport',         'shock-absorbers', 'Arxa amortizator, sağ (Sport 2.7 V6)',                                  'Амортизатор задний правый (Sport 2.7 V6)',                                     'Rear shock absorber, right (Sport 2.7 V6)',                        'Ford',       'HG9Z-18125-C',  'Ford', 'REAR_RIGHT',  'Fusion Sport, continuously controlled damping, qty 1.'),
  -- stabilizer links
  ('stab-link-front',        'stabilizer-links','Ön stabilizator dartqısı',                                              'Стойка стабилизатора передняя',                                                'Front stabilizer bar link',                                        'Ford',       'DG9Z-5K484-A',  'Ford', 'FRONT',       'Left and right identical, qty 2. Sport fitment conflicting, not included.'),
  ('stab-link-rear-fwd',     'stabilizer-links','Arxa stabilizator dartqısı (FWD)',                                      'Стойка стабилизатора задняя (FWD)',                                            'Rear stabilizer bar link (FWD)',                                   'Ford',       'DG9Z-5C486-A',  'Ford', 'REAR',        'FWD cars only, qty 2. AWD and Sport use a different link (unverified).'),
  -- wheel hubs
  ('hub-front',              'wheel-bearings',  'Ön təkər topu, podşipniklə',                                            'Ступица передняя в сборе с подшипником',                                       'Front wheel hub and bearing assembly',                             'Ford',       'DG9Z-1104-T',   'Ford', 'FRONT',       'All except Sport; left and right identical, qty 2. Supersedes Motorcraft HUB-309 / HUB-419 / HUB-270 / HUB-203 / HUB-410 / HUB-202.'),
  ('hub-front-sport',        'wheel-bearings',  'Ön təkər topu, podşipniklə (Sport)',                                    'Ступица передняя в сборе с подшипником (Sport)',                               'Front wheel hub and bearing assembly (Sport)',                     'Ford',       'K2GZ-1104-A',   'Ford', 'FRONT',       'Fusion Sport 2.7 V6 only, qty 2.'),
  ('hub-rear-fwd',           'wheel-bearings',  'Arxa təkər topu, podşipniklə (FWD)',                                    'Ступица задняя в сборе с подшипником (FWD)',                                   'Rear wheel hub and bearing assembly (FWD)',                        'Ford',       'DG9Z-1109-C',   'Ford', 'REAR',        'FWD only, from MY2014, not Energi; qty 2. Supersedes Motorcraft HUB-411 / HUB-259 / HUB-310.'),
  -- strut mounts
  ('strut-mount-front',      'strut-mounts',    'Ön amortizator üst dayağı',                                             'Опора передней стойки верхняя',                                                'Front strut upper mount',                                          'Ford',       'DG9Z-3A197-AB', 'Ford', 'FRONT',       'Left and right identical, qty 2. Bearing DG9Z-18198-A sold separately.'),
  ('strut-bearing-front',    'strut-mounts',    'Ön amortizator dayaq podşipniki',                                       'Подшипник опоры передней стойки',                                              'Front strut bearing',                                              'Ford',       'DG9Z-18198-A',  'Ford', 'FRONT',       'Left and right identical, qty 2.'),
  ('rshock-bracket',         'strut-mounts',    'Arxa amortizator üst kronşteyni',                                       'Кронштейн верхний заднего амортизатора',                                       'Rear shock absorber upper mounting bracket',                       'Ford',       'DG9Z-18A161-C', 'Ford', 'REAR',        'Qty 2. Supersedes Motorcraft AD-1107 / AD-1104. Sport uses HG9Z-18A161-A.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('fstrut-l-i4',           'AST84751',      'OEM', 'Motorcraft'),
  ('fstrut-l-i4',           'DG9Z-18124-AA', 'OEM', 'Ford'),
  ('fstrut-l-i4',           'DG9Z-18124-C',  'OEM', 'Ford'),
  ('fstrut-l-i4',           'DG9Z-18124-N',  'OEM', 'Ford'),
  ('fstrut-l-i4',           'AST-12362',     'OEM', 'Motorcraft'),
  ('fstrut-l-i4',           'AST-24680',     'OEM', 'Motorcraft'),
  ('fstrut-l-i4',           'AST-12282',     'OEM', 'Motorcraft'),
  ('fstrut-l-i4',           '22-250315',     'AFTERMARKET', 'Bilstein'),
  ('fstrut-r-i4',           'AST24737',      'OEM', 'Motorcraft'),
  ('fstrut-r-i4',           'DG9Z-18124-Y',  'OEM', 'Ford'),
  ('fstrut-r-i4',           'DG9Z-18124-G',  'OEM', 'Ford'),
  ('fstrut-r-i4',           'DG9Z-18124-R',  'OEM', 'Ford'),
  ('fstrut-r-i4',           'AST-12288',     'OEM', 'Motorcraft'),
  ('fstrut-r-i4',           'AST-24678',     'OEM', 'Motorcraft'),
  ('fstrut-r-i4',           'AST-12365',     'OEM', 'Motorcraft'),
  ('fstrut-r-i4',           '22-250322',     'AFTERMARKET', 'Bilstein'),
  ('fstrut-l-20-16-18',     'AST84752',      'OEM', 'Motorcraft'),
  ('fstrut-l-20-16-18',     'DG9Z-18124-AB', 'OEM', 'Ford'),
  ('fstrut-l-20-16-18',     'DG9Z-18124-D',  'OEM', 'Ford'),
  ('fstrut-l-20-16-18',     'DG9Z-18124-P',  'OEM', 'Ford'),
  ('fstrut-l-20-16-18',     'AST-12363',     'OEM', 'Motorcraft'),
  ('fstrut-l-20-16-18',     'AST-24681',     'OEM', 'Motorcraft'),
  ('fstrut-l-20-16-18',     'AST-12283',     'OEM', 'Motorcraft'),
  ('fstrut-l-20-16-18',     '22-250315',     'AFTERMARKET', 'Bilstein'),
  ('fstrut-r-20eb-16-18-a', 'AST24679',      'OEM', 'Motorcraft'),
  ('fstrut-r-20eb-16-18-a', '22-250322',     'AFTERMARKET', 'Bilstein'),
  ('fstrut-r-20-16-18-b',   'AST84756',      'OEM', 'Motorcraft'),
  ('fstrut-r-20-16-18-b',   '22-250322',     'AFTERMARKET', 'Bilstein'),
  ('fstrut-l-20eb-19-a',    'AST12364',      'OEM', 'Motorcraft'),
  ('fstrut-l-20eb-19-a',    'DG9Z-18124-L',  'OEM', 'Ford'),
  ('fstrut-l-20eb-19-a',    'DG9Z-18124-E',  'OEM', 'Ford'),
  ('fstrut-l-20eb-19-a',    'AST-12284',     'OEM', 'Motorcraft'),
  ('fstrut-l-20eb-19-a',    'AST-12360',     'OEM', 'Motorcraft'),
  ('fstrut-l-20eb-19-a',    '22-250315',     'AFTERMARKET', 'Bilstein'),
  ('fstrut-r-20eb-19-a',    'AST12367',      'OEM', 'Motorcraft'),
  ('fstrut-r-20eb-19-a',    '22-250322',     'AFTERMARKET', 'Bilstein'),
  ('fstrut-l-20eb-19-b',    'AST86034',      'OEM', 'Motorcraft'),
  ('fstrut-l-20eb-19-b',    'HG9Z-18124-H',  'OEM', 'Ford'),
  ('fstrut-l-20eb-19-b',    'AST-84753',     'OEM', 'Motorcraft'),
  ('fstrut-l-20eb-19-b',    '22-250315',     'AFTERMARKET', 'Bilstein'),
  ('fstrut-r-20eb-19-b',    'AST86033',      'OEM', 'Motorcraft'),
  ('fstrut-r-20eb-19-b',    'HG9Z-18124-M',  'OEM', 'Ford'),
  ('fstrut-r-20eb-19-b',    'AST-84757',     'OEM', 'Motorcraft'),
  ('fstrut-r-20eb-19-b',    '22-250322',     'AFTERMARKET', 'Bilstein'),
  ('fstrut-l-sport',        'AST24749',      'OEM', 'Motorcraft'),
  ('rshock-i4-2013-2016',   '19-250335',     'AFTERMARKET', 'Bilstein'),
  ('rshock-20eb-fwd-16-18', 'ASH-24573',     'OEM', 'Motorcraft'),
  ('rshock-20eb-fwd-16-18', 'ASH-24519',     'OEM', 'Motorcraft'),
  ('rshock-20eb-fwd-16-18', 'DG9Z-18125-F',  'OEM', 'Ford'),
  ('rshock-20eb-fwd-16-18', 'DG9Z-18125-L',  'OEM', 'Ford'),
  ('rshock-20eb-fwd-16-18', '19-250335',     'AFTERMARKET', 'Bilstein'),
  ('rshock-20eb-19',        'ASH24572',      'OEM', 'Motorcraft'),
  ('rshock-20eb-19',        'AST-12355',     'OEM', 'Motorcraft'),
  ('rshock-20eb-19',        'ASH-24517',     'OEM', 'Motorcraft'),
  ('rshock-20eb-19',        'DG9Z-18125-E',  'OEM', 'Ford'),
  ('rshock-20eb-19',        'DG9Z-18125-G',  'OEM', 'Ford'),
  ('rshock-20eb-19',        '19-250335',     'AFTERMARKET', 'Bilstein'),
  ('rshock-phev-2013-2016', 'ASH24682',      'OEM', 'Motorcraft'),
  ('rshock-phev-2013-2016', '19-250335',     'AFTERMARKET', 'Bilstein'),
  ('stab-link-front',       'JTS1540',       'AFTERMARKET', 'TRW'),
  ('stab-link-front',       'K750740',       'AFTERMARKET', 'Moog'),
  ('hub-front',             'HUB-309',       'OEM', 'Motorcraft'),
  ('hub-front',             'HUB-419',       'OEM', 'Motorcraft'),
  ('hub-front',             'HUB-270',       'OEM', 'Motorcraft'),
  ('hub-front',             'HUB-203',       'OEM', 'Motorcraft'),
  ('hub-front',             'HUB-410',       'OEM', 'Motorcraft'),
  ('hub-front',             'HUB-202',       'OEM', 'Motorcraft'),
  ('hub-front',             'DG9Z-1104-A',   'OEM', 'Ford'),
  ('hub-front',             'DG9Z-1104-B',   'OEM', 'Ford'),
  ('hub-front',             'DG9Z-1104-D',   'OEM', 'Ford'),
  ('hub-front',             'DG9Z-1104-E',   'OEM', 'Ford'),
  ('hub-front',             'DG9Z-1104-S',   'OEM', 'Ford'),
  ('hub-front',             'DG9Z-1104-U',   'OEM', 'Ford'),
  ('hub-rear-fwd',          'HUB-411',       'OEM', 'Motorcraft'),
  ('hub-rear-fwd',          'HUB-259',       'OEM', 'Motorcraft'),
  ('hub-rear-fwd',          'HUB-310',       'OEM', 'Motorcraft'),
  ('hub-rear-fwd',          'DG9Z-1109-A',   'OEM', 'Ford'),
  ('hub-rear-fwd',          'DG9Z-1104-C',   'OEM', 'Ford'),
  ('hub-rear-fwd',          'DG9Z-1104-F',   'OEM', 'Ford'),
  ('strut-mount-front',     'DG9Z-3A197-A',  'OEM', 'Ford'),
  ('rshock-bracket',        'AD-1107',       'OEM', 'Motorcraft'),
  ('rshock-bracket',        'AD-1104',       'OEM', 'Motorcraft'),
  ('rshock-bracket',        'DG9Z-18A161-A', 'OEM', 'Ford'),
  ('rshock-bracket',        'DG9Z-18A161-B', 'OEM', 'Ford');

INSERT INTO seed_fits (key, year_from, year_to, engine_code, trims, notes) VALUES
  -- front struts
  ('fstrut-l-i4',           2013, 2020, '2.5 Duratec iVCT',  NULL, 'Standard suspension'),
  ('fstrut-l-i4',           2013, 2014, '1.6 EcoBoost',      NULL, 'Standard suspension'),
  ('fstrut-l-i4',           2014, 2020, '1.5 EcoBoost',      NULL, 'Standard suspension'),
  ('fstrut-r-i4',           2013, 2020, '2.5 Duratec iVCT',  NULL, 'Standard suspension'),
  ('fstrut-r-i4',           2013, 2014, '1.6 EcoBoost',      NULL, 'Standard suspension'),
  ('fstrut-r-i4',           2014, 2020, '1.5 EcoBoost',      NULL, 'Standard suspension'),
  ('fstrut-l-20-16-18',     2013, 2020, '2.0 EcoBoost',      NULL, '16-18 in wheels'),
  ('fstrut-l-20-16-18',     2013, 2020, '2.0 Atkinson HEV',  NULL, '16-18 in wheels'),
  ('fstrut-l-20-16-18',     2013, 2020, '2.0 Atkinson PHEV', NULL, '16-18 in wheels'),
  ('fstrut-r-20eb-16-18-a', 2013, 2016, '2.0 EcoBoost',      NULL, '16-18 in wheels'),
  ('fstrut-r-20-16-18-b',   2017, 2020, '2.0 EcoBoost',      NULL, '16-18 in wheels'),
  ('fstrut-r-20-16-18-b',   2017, 2020, '2.0 Atkinson HEV',  NULL, '16-18 in wheels'),
  ('fstrut-r-20-16-18-b',   2017, 2020, '2.0 Atkinson PHEV', NULL, '16-18 in wheels'),
  ('fstrut-l-20eb-19-a',    2013, 2016, '2.0 EcoBoost',      NULL, '19 in wheels'),
  ('fstrut-r-20eb-19-a',    2013, 2016, '2.0 EcoBoost',      NULL, '19 in wheels'),
  ('fstrut-l-20eb-19-b',    2017, 2020, '2.0 EcoBoost',      NULL, '19 in wheels'),
  ('fstrut-r-20eb-19-b',    2017, 2020, '2.0 EcoBoost',      NULL, '19 in wheels'),
  ('fstrut-l-sport',        2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('fstrut-r-sport',        2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  -- rear shocks
  ('rshock-i4-2013-2016',   2013, 2016, '2.5 Duratec iVCT',  NULL, NULL),
  ('rshock-i4-2013-2016',   2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('rshock-i4-2013-2016',   2014, 2016, '1.5 EcoBoost',      NULL, NULL),
  ('rshock-20eb-fwd-16-18', 2013, 2016, '2.0 EcoBoost',      NULL, 'FWD only, 16-18 in wheels'),
  ('rshock-20eb-19',        2013, 2016, '2.0 EcoBoost',      NULL, '19 in wheels'),
  ('rshock-phev-2013-2016', 2013, 2016, '2.0 Atkinson PHEV', NULL, NULL),
  ('rshock-l-sport',        2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('rshock-r-sport',        2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  -- stabilizer links
  ('stab-link-front',       2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('stab-link-front',       2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('stab-link-front',       2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('stab-link-front',       2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('stab-link-front',       2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('stab-link-front',       2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('stab-link-rear-fwd',    2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('stab-link-rear-fwd',    2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('stab-link-rear-fwd',    2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('stab-link-rear-fwd',    2013, 2020, '2.0 EcoBoost',      NULL, 'FWD only'),
  ('stab-link-rear-fwd',    2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('stab-link-rear-fwd',    2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  -- hubs
  ('hub-front',             2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('hub-front',             2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('hub-front',             2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('hub-front',             2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('hub-front',             2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('hub-front',             2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('hub-front-sport',       2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('hub-rear-fwd',          2014, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('hub-rear-fwd',          2014, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('hub-rear-fwd',          2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('hub-rear-fwd',          2014, 2020, '2.0 EcoBoost',      NULL, 'FWD only'),
  ('hub-rear-fwd',          2014, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  -- strut mounts
  ('strut-mount-front',     2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('strut-mount-front',     2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('strut-mount-front',     2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('strut-mount-front',     2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('strut-mount-front',     2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('strut-mount-front',     2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('strut-mount-front',     2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('strut-bearing-front',   2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('strut-bearing-front',   2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('strut-bearing-front',   2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('strut-bearing-front',   2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('strut-bearing-front',   2017, 2019, '2.7 EcoBoost V6',   ARRAY['Sport'], NULL),
  ('strut-bearing-front',   2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('strut-bearing-front',   2013, 2020, '2.0 Atkinson PHEV', NULL, NULL),
  ('rshock-bracket',        2013, 2020, '2.5 Duratec iVCT',  NULL, NULL),
  ('rshock-bracket',        2013, 2014, '1.6 EcoBoost',      NULL, NULL),
  ('rshock-bracket',        2014, 2020, '1.5 EcoBoost',      NULL, NULL),
  ('rshock-bracket',        2013, 2020, '2.0 EcoBoost',      NULL, NULL),
  ('rshock-bracket',        2013, 2020, '2.0 Atkinson HEV',  NULL, NULL),
  ('rshock-bracket',        2013, 2020, '2.0 Atkinson PHEV', NULL, NULL);


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
     WHERE NOT EXISTS (
        SELECT 1 FROM vehicle_variants vv
          JOIN vehicle_generations g ON g.id = vv.generation_id
          JOIN vehicle_models m ON m.id = g.model_id
          JOIN vehicle_makes mk ON mk.id = m.make_id
         WHERE mk.slug = 'ford' AND m.slug = 'fusion' AND g.slug = 'gen'
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
       'seed-ford-fusion-service-parts', 'seed-ford-fusion-service-parts'
  FROM seed_new n
  JOIN seed_parts sp ON sp.key = n.key
  JOIN categories c ON c.slug = sp.category_slug;

INSERT INTO part_numbers (part_id, number, type, source, created_by, updated_by)
SELECT n.part_id, sp.oem_key, 'OEM', sp.oem_key_source,
       'seed-ford-fusion-service-parts', 'seed-ford-fusion-service-parts'
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
-- Numbers
-- ============================================================
INSERT INTO part_numbers (part_id, number, type, source, created_by, updated_by)
SELECT ids.part_id, sn.number, sn.type, sn.source,
       'seed-ford-fusion-service-parts', 'seed-ford-fusion-service-parts'
  FROM seed_numbers sn
  JOIN seed_part_ids ids ON ids.key = sn.key
ON CONFLICT (number, type, part_id) DO NOTHING;

-- ============================================================
-- Fitments, per variant
-- ============================================================
INSERT INTO fitments (part_id, vehicle_variant_id, position, notes, created_by, updated_by)
SELECT DISTINCT ids.part_id, vv.id, sp.position, sf.notes,
       'seed-ford-fusion-service-parts', 'seed-ford-fusion-service-parts'
  FROM seed_fits sf
  JOIN seed_parts sp ON sp.key = sf.key
  JOIN seed_part_ids ids ON ids.key = sf.key
  JOIN vehicle_generations g ON g.slug = 'gen'
  JOIN vehicle_models m ON m.id = g.model_id AND m.slug = 'fusion'
  JOIN vehicle_makes mk ON mk.id = m.make_id AND mk.slug = 'ford'
  JOIN vehicle_variants vv ON vv.generation_id = g.id
                          AND vv.engine_code = sf.engine_code
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
 WHERE p.created_by = 'seed-ford-fusion-service-parts'
 ORDER BY c.slug, p.name_en;

SELECT vv.year, vv.trim, vv.engine_code, count(DISTINCT f.part_id) AS parts
  FROM vehicle_variants vv
  JOIN vehicle_generations g ON g.id = vv.generation_id AND g.slug = 'gen'
  JOIN vehicle_models m ON m.id = g.model_id AND m.slug = 'fusion'
  LEFT JOIN fitments f ON f.vehicle_variant_id = vv.id
 GROUP BY vv.year, vv.trim, vv.engine_code
 ORDER BY vv.year, vv.engine_code, vv.trim;
SQL
