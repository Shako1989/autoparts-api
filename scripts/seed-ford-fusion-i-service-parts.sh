#!/usr/bin/env bash
# Seed service parts, batch 2: Ford Fusion I (CD338, US market, MY2006-2012),
# per engine, with Motorcraft OEM numbers + aftermarket cross-references and
# fitments per vehicle variant. TODO.md task 5. Same layout and rules as
# scripts/seed-ford-fusion-service-parts.sh (batch 1, CD391): three temp tables
# (seed_parts identified by an OEM number, seed_numbers, seed_fits), every
# statement idempotent, fitments per variant. FWD/AWD is not part of the
# variant key, so drivetrain-specific parts carry it in fitments.notes.
#
# Parts shared with the CD391 (same OEM number: the 2.3 / 2.5 water pump
# 4S4Z-8501-E and thermostat 3M4Z-8575-B, the FL-910S oil filter, the
# AYFS-32Y-RX spark plug, the 9E5Z-12029-A coil) are not duplicated: the row
# resolves to the existing part, which takes this seed's generation-neutral
# wording and gets the CD338 fitments on top of its CD391 ones.
#
# Requires: ford/fusion generation slug 'cd338' with its 41 variants
# (scripts/seed-ford-fusion-i-variants.sh), batch 1 for the shared parts
# (scripts/seed-ford-fusion-service-parts.sh) and the canonical category tree
# (scripts/seed-category-tree.sh).
#
# Run locally:  ./scripts/seed-ford-fusion-i-service-parts.sh
# Run on prod:  print the heredoc body and run it from a DB client (seed-only change, no VM rebuild):
#   awk '/^docker exec/{f=1;next} /^SQL$/{f=0} f' scripts/seed-ford-fusion-i-service-parts.sh > ~/Downloads/seed-ford-fusion-i-service-parts.sql
#
# Research date: 2026-11-10. Market: US. Confidence bar: 90%; everything below
# it is listed under LEFT OUT and not seeded. Sources: Ford owner's guides
# (Motorcraft part-number tables), ford.com Motorcraft product pages, Ford EPC
# mirrors (fordpartsgiant / fordpartsdeal, which carry Ford's own fitment notes
# and "Replaces" lists), RockAuto catalog pages and Brembo's catalog for
# cross-references. Most aftermarket catalogs blocked fetches, so cross-references
# are thin outside filters and brakes. Ford's catalog supersedes nearly every
# original CD338 number into one current number per position, which is why most
# brake and suspension parts here cover the whole 2006-2012 run.
#
# Sources (per claim):
#   Filters & ignition (owner's guide Motorcraft tables, ford.com, Ford EPC mirrors; RockAuto pages for cross-references):
#     https://www.manualsdir.com/manuals/602351/ford-2006-fusion-v1.html?page=242   (MY2006: FL2017-A or FL910, FL-820-S, FA-1683, FA-1771, O-ring 1S7G-6885-AC)
#     https://www.manualsdir.com/manuals/602322/ford-2007-fusion-v2.html?page=264   (MY2007: FL-2017-B, FL-820-S, FA-1683, FA-1771)
#     https://www.manualsdir.com/manuals/602280/ford-2008-fusion.html?page=286      (MY2008)
#     https://www.manualsdir.com/manuals/602246/ford-2009-fusion-v2.html?page=300   (MY2009: FL-2017-B, FL-500-S, FA-1785, FA-1786)
#     https://www.manualsdir.com/manuals/602200/ford-2010-fusion-v3.html?page=323 , https://www.manualsdir.com/manuals/602201/ford-2010-fusion-v4.html?page=320 (MY2010: FL-910, FL-500-S, FA-1785/1786/1884)
#     https://www.manualsdir.com/manuals/602157/ford-2011-fusion-v3.html?page=333   (MY2011: FL-910S, FL-500-S, FA-1785/1786/1884, FP-67)
#     https://www.manualsdir.com/manuals/602112/ford-2012-fusion-v1.html?page=333 , https://www.manualsdir.com/manuals/602113/ford-2012-fusion-v2.html?page=334 (MY2012)
#     https://lawnandgarden.manualsonline.com/manuals/mfg/ford/2010_fusion_hybrid.html?p=297 (Hybrid: FP-67; oil filter conflicting, see LEFT OUT)
#     https://www.fordpartsgiant.com/oem-2008-ford-fusion-oil_filter.html , .../oem-2009-ford-fusion-oil_filter.html (3S7Z-6731-A <- 3M4Z-6744-AC; F1AZ-6731-BD <- F1AZ-6731-A)
#     https://www.fordpartsgiant.com/oem-2010-ford-fusion-oil_filter.html , .../oem-2012-ford-fusion-oil_filter.html (BE8Z-6731-AB <- 1S7Z-6731-DA; AA5Z-6714-A for 3.0 and 3.5)
#     https://www.rockauto.com/en/catalog/ford,2008,fusion,2.3l+l4,1441686,engine,oil+filter,5340 (cartridge and spin-on cross-references)
#     https://www.rockauto.com/en/catalog/ford,2010,fusion,2.5l+l4,1444309,engine,oil+filter,5340 (FL-910S cross-references)
#     https://www.rockauto.com/en/catalog/ford,2011,fusion,3.0l+v6,3015243,engine,oil+filter,5340 (FL-500-S cross-references, 3.0 only)
#     https://www.fordpartsgiant.com/oem-2009-ford-fusion-air_filter.html , .../oem-2011-ford-fusion-air_filter.html (6E5Z-9601-EA 2.3/2.5, 6E5Z-9601-GA 3.0, 7T4Z-9601-A 3.5)
#     https://www.fordpartsgiant.com/parts/ford-filter-odour-and-particles_ae5z-19n619-a.html (FP-67 = AE5Z-19N619-A, 2010-2012; "2009 and earlier models are not equipped from the factory with a cabin air filter")
#     https://www.fordpartsdeal.com/parts-select/2010-ford-fusion-cabin-air-filter
#     https://www.fordpartsdeal.com/oem/ford~spark-plug~ayfs-32y-rx                 (replaces AYFS-32Y-R, AYSF-32Y-PC, SP-490, SP-530; 2.3, 2.5, 2.5 hybrid)
#     https://www.fordpartsgiant.com/oem-2008-ford-fusion-spark_plug.html , .../oem-2011-ford-fusion-spark_plug.html (quantities, AGSF-32W-MF4 -> AGSF-32W-MX, CGSF-22N -> CGSF-22N-A1X, AYFS-22F-M -> AYFS-22F-MX)
#     https://www.ford.com/product/spark-plug-p4000161942                           (SP433X = AGSF32WMX, interchangeable with SP 433)
#     https://www.fordpartsdeal.com/oem/ford~spark-plug~agsf-32w-mx , .../ford~spark-plug~cgsf-22n-a1x , .../ford~spark-plug~ayfs-22f-mx
#     https://www.wheelerfleet.com/product/motorcraft-ignition-coil-for-ford/105311  (DG514 = 6E5Z12029BA, Fusion 2006-2012)
#     https://www.fordpartsdeal.com/oem/ford~coil-assembly-ignition~6e5z-12029-ba , .../6e5z-12029-aa (discontinued) , .../9e5z-12029-a , .../7t4z-12029-e
#     https://www.fordpartsgiant.com/oem-2008-ford-fusion-ignition_coil.html , .../oem-2011-ford-fusion-ignition_coil.html
#   Belts, cooling, battery, wipers (Ford EPC mirrors and owner's manuals; ford.com pairs Motorcraft SKUs with Ford numbers):
#     https://www.ford.com/product/serpentine-belt-p4000062444                      (JK6-889-A = 6E5Z-8620-AE, 2.3L AT)
#     https://www.fordpartsdeal.com/oem/ford~v-belt~6e5z-8620-ae                     (replaces 6E5Z-8620-B, JK6-887-A)
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/engine/pulleys_and_drive_belts.html (6E5Z-8620-B "Automatic transmission", 6E5Z-8620-C manual)
#     https://www.ford.com/product/serpentine-belt-p4000050490                      (JK6-892-A = 6E5Z-8620-C, 2.3L MT)
#     https://www.ford.com/product/serpentine-belt-p4000019771                      (JK6-931 = 6E5Z-8620-BB, 3.0L 2006-2009)
#     https://www.fordpartsgiant.com/parts/ford-v-belt_6e5z-8620-bb.html            (FWD and AWD)
#     https://www.fordpartsdeal.com/oem/ford~v-belt~6e5z-8620-ca                     (3.0L water pump belt 2006-2009)
#     https://www.fordpartsdeal.com/oem/ford~v-belt~9e5z-8620-a                      (2.5L 2010-2012)
#     https://www.fordpartsdeal.com/oem/ford~v-belt~ae5z-8620-a , https://www.fordpartsgiant.com/parts/ford-v-belt_ae5z-8620-a.html (Hybrid)
#     https://www.fordpartsgiant.com/parts/ford-v-belt_gb5z-8620-a.html             (3.0L main belt 2010-2012, FWD and AWD)
#     https://www.fordpartsdeal.com/oem/ford~v-belt~9l8z-8620-a                      (3.0L water pump belt 2010-2012)
#     https://www.fordpartsdeal.com/oem/ford~v-belt~bt4z-8620-a                      (3.5L main belt; replaces 7T4Z-8620-C, 8T4Z-8620-A)
#     https://www.fordpartsgiant.com/parts-list/2010-ford-fusion/engine/pulleys_and_drive_belts.html (3.5L callouts; 7T4Z-8620-A "For In Dealership Repairs Only"; tensioner production dates)
#     https://www.fordpartsdeal.com/oem/ford~v-belt~7t4z-8620-a                      (3.5L secondary belt)
#     https://www.fordpartsdeal.com/oem/ford~tensioner~6e5z-6a228-b                  (2.3 / 2.5 tensioner; replaces 3S4Z-6A228-AA, 6E5Z-6A228-BA, 6E5Z-6A228-AA)
#     https://www.fordpartsdeal.com/oem/ford~tensioner~ae5z-6a228-a                  (Hybrid tensioner, discontinued)
#     https://www.fordpartsdeal.com/oem/ford~tensioner~4l8z-6b209-aa , .../ford~tensioner~9l8z-6b209-a , .../ford~tensioner~bt4z-6b209-b
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/engine/thermostat_housing_related_parts.html (3M4Z-8575-B, 1X4Z-8575-EB, gaskets)
#     https://www.fordpartsgiant.com/parts-list/2010-ford-fusion/engine/thermostat_housing_related_parts.html (incl. 2.5 FHEV)
#     https://www.fordpartsdeal.com/oem/ford~thermostat~3m4z-8575-b , .../ford~thermostat~1x4z-8575-eb , .../ford~thermostat~1x4z-8575-b
#     https://www.fordpartsdeal.com/oem/ford~water-pump~4s4z-8501-e                  (2.3 / 2.5 / FHEV; replaces 1S7Z-8501-AK, 4S4Z-8501-D/-AA, 6M8Z-8501-AC, PW-465, PW-447)
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/engine/water_pump.html , .../2010-ford-fusion/engine/water_pump.html (gaskets)
#     https://www.fordpartsdeal.com/oem/ford~water-pump~eu2z-8501-d                  (3.0L 2006-2009; replaces 3M4Z-8501-BG/-BJ, 5M8Z-8501-A/-B, PW-481, PW-437, PW-440)
#     https://www.fordpartsdeal.com/oem/ford~water-pump~9l8z-8501-a , .../ford~water-pump~9l8z-8501-c (3.0L 2010-2012 pump and housing)
#     https://www.fordpartsdeal.com/oem/ford~water-pump~aa5z-8501-f                  (3.5L; replaces 7T4Z-8501-D, AA5Z-8501-A/-D, PW-495, PW-489, PW-538, PW-498)
#     https://www.fordpartsdeal.com/oem/ford~pump-assembly~9e5z-8c419-b              (Hybrid inverter coolant pump; replaces 9E5Z-8C419-A)
#     https://www.manualsdir.com/manuals/602351/ford-2006-fusion-v1.html?page=242   (MY2006: BXT-40-R)
#     https://www.fordpartsdeal.com/oem/ford~battery~bxt-40r                         (replaces BXL-40-R)
#     https://www.fordpartsdeal.com/oem/ford~battery~bxt-96r-500                     (2007-2012; replaces BXT-96-R)
#     https://www.manualsdir.com/manuals/602280/ford-2008-fusion.html?page=286 , https://www.manualsdir.com/manuals/602246/ford-2009-fusion-v2.html?page=300 (2.3: BXT-96R)
#     https://www.manualsdir.com/manuals/602200/ford-2010-fusion-v3.html?page=323   (MY2010: BXT-96-R)
#     https://www.manualsdir.com/manuals/602157/ford-2011-fusion-v3.html?page=333   (MY2011: BXT-96R-500, all engines)
#     https://www.manualsdir.com/manuals/602112/ford-2012-fusion-v1.html?page=333 , https://www.manualsdir.com/manuals/602113/ford-2012-fusion-v2.html?page=334 (MY2012: BXT-96R-500; wipers WW-1901-PF)
#     https://www.ford.com/product/vehicle-battery-p4000120288                      (BXT-96R-500: 500 CCA)
#     https://www.fordpartsgiant.com/parts-list/2010-ford-fusion/electrical/battery_and_mountings.html (90 RC; BXT-67R 390 A / 65 RC)
#     https://www.fordpartsdeal.com/oem/ford~battery~bxt-67r , https://lawnandgarden.manualsonline.com/manuals/mfg/ford/2010_fusion_hybrid.html?p=297 (Hybrid 12 V: BXT-67-R)
#     https://www.fordpartsgiant.com/parts-list/2007-ford-fusion/body_and_paint/windshield_wiper.html , .../2010-ford-fusion/body_and_paint/windshield_wiper.html
#     https://www.fordpartsgiant.com/parts/ford-blade-assy-wiper_6e5z-17528-aa.html (driver, 24 in, 2006-2012)
#     https://www.fordpartsgiant.com/parts/ford-blade-assy-wiper_6e5z-17528-ab.html (passenger, 19 in, 2006-2012)
#   Brakes (Ford EPC mirrors; one part per position for the whole CD338 run, FWD and AWD alike):
#     https://www.fordpartsdeal.com/oem/ford~brake-lining-kit~6u2z-2v001-f         (front pads; replaces 6E5Z-2001-B/-C, 7E5Z-2001-A, 9E5Z-2001-A, BR-1164-B, BRF-1164; current T3MZ-2V001-S)
#     https://www.fordpartsdeal.com/parts-select/2008-ford-fusion-brake-pads , .../2009-ford-fusion-brake-pads , .../2011-ford-fusion-brake-pads
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/chassis/front_brake_discs_and_calipers.html (6U2Z-2V001-D, G2MZ-2V001-AF)
#     https://www.fordpartsdeal.com/oem/ford~brake-lining-kit~6u2z-2v200-b         (rear pads; replaces 6E5Z-2200-B/-C, 9E5Z-2200-A, BE5Z-2200-A, BRF-24; current T3MZ-2V200-R; "Without AWD" and "With AWD")
#     https://www.fordpartsgiant.com/parts-list/2009-ford-fusion/chassis/rear_brake_discs_and_calipers.html (J2MZ-2V200-J, 9E5Z-2C026-A, 6E5Z-2C026-AA)
#     https://www.fordpartsdeal.com/oem/ford~rotor~6u2z-1v125-k                    (front disc; replaces 6E5Z-1125-AA, 9E5Z-1125-A/-B/-C, 6U2Z-1V125-E/-H, BRRF-116, BRRF-30, BRR-144, BRR-295; current T3MZ-1V125-CA)
#     https://www.fordpartsdeal.com/parts-select/2008-ford-fusion-brake-disc , .../2011-ford-fusion-brake-disc , .../2012-ford-fusion-brake-disc (G2MZ-1V125-JA)
#     https://www.fordpartsgiant.com/parts/ford-rotor-asy_brrf-116.html
#     https://www.ford.com/product/disc-brake-rotor-p4000060658                   (BRRF29 = 9E5Z2C026B, rear)
#     https://www.fordpartsdeal.com/oem/ford~rotor-assembly-brake~9e5z-2c026-b
#   Brake aftermarket cross-references (retailer fitment lists 2006-2012 S/SE/SEL + 2010-2012 Hybrid/Sport; Brembo catalog for dimensions):
#     https://4wheelingplus.com/products/power-stop-06-12-ford-fusion-front-z23-evolution-sport-brake-pads-w-hardware (Z23-1164)
#     https://fiperformance.com/products/power-stop-06-12-ford-fusion-rear-z23-evolution-sport-brake-pads-w-hardware (Z23-1161)
#     https://fiperformance.com/products/brembo-06-12-ford-fusion-07-12-lincoln-mkz-front-premium-uv-coated-oe-equivalent-rotor (09.B543.11)
#     https://www.bremboparts.com/america/en/catalogue/disc/09-B543-11            (299 x 25 mm, min 23 mm)
#     https://fiperformance.com/products/brembo-06-12-ford-fusion-07-12-lincoln-mkz-03-07-mazda-6-rear-premium-uv-coated-oe-equivalent-rotor (08.N226.11)
#     https://www.bremboparts.com/america/en/catalogue/disc/08-N226-11            (280 x 10 mm, min 8 mm, solid)
#   Suspension (Ford EPC mirrors; every original number is superseded to one current Ford number per position, no current Motorcraft SKU found):
#     https://www.fordpartsgiant.com/parts-list/2009-ford-fusion/chassis/front_suspension_struts_and_springs.html
#     https://www.fordpartsgiant.com/parts/ford-kit-front-suspension-strut_7e5z-18124-lh.html , .../7e5z-18124-rh.html (2006-2009 struts; replaces 6E5Z-18124-AL/-BL, 8E5Z-18124-L, 6H6Z/7H6Z/8H6Z, AST-159..389)
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/chassis/front_suspension_struts_and_springs.html
#     https://www.fordpartsgiant.com/parts/ford-shock-absorber-assy-front_ah6z-18124-d.html , .../ford-shock-absorber-assy_ah6z-18124-c.html (2010-2012 struts; replaces AE5Z-18124-A..K, AST-420..471)
#     https://www.fordpartsgiant.com/parts/ford-strut-loaded-assembly_gu2z-18a092-be.html (loaded strut 2008-2009 LH; replaces GU2Z-18A092-Z, ASTL-27)
#     https://www.fordpartsgiant.com/parts/ford-strut-loaded-assembly_ju2z-18a092-b.html , .../gu2z-18a092-v.html (loaded struts 2010-2012)
#     https://www.fordpartsgiant.com/parts/ford-shock-absorber-assy_6e5z-18125-ba.html (rear shock; replaces 6E5Z-18125-AA, 7E5Z/8E5Z-18125-A, AE5Z-18125-A..G, AH6Z-18125-A/-B, 6H6Z/7H6Z, ASH-420..440, AST-177..338)
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/chassis/rear_springs_and_shock_absorbers.html , .../2011-ford-fusion/chassis/rear_springs_and_shock_absorbers.html
#     https://www.fordpartsgiant.com/parts/ford-bush_6e5z-18183-b.html , https://www.fordpartsgiant.com/parts-list/2006-ford-fusion/chassis/front_suspension_struts_and_springs.html (upper mount 2006-2008, discontinued)
#     https://www.fordpartsgiant.com/parts/ford-bush_8e5z-18183-a.html , https://www.fordpartsdeal.com/oem/ford~bush~8e5z-18183-a (upper mount 2008-2012)
#     https://www.fordpartsgiant.com/parts/ford-damper-assy_ae5z-3f690-a.html , https://www.fordpartsdeal.com/oem/ford~damper-assembly~ae5z-3f690-a (mount damper; replaces 6E5Z-3F690-A)
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/chassis/front_susp_arms_stabilizer_x_member.html (arms, links, bearing AE5Z-18198-A <- 6E5Z-18198-A)
#     https://www.fordpartsgiant.com/parts/ford-arm-assy-front-suspension_be5z-3079-a.html , .../be5z-3078-b.html (rearward arms with ball joint; replaces 5M8Z/6M8Z/7E5Z, MCSOE kits)
#     https://www.fordpartsgiant.com/parts/ford-arm-assy-front-suspension_ae5z-3078-a.html (forward arm; replaces 7E5Z-3078-R 08/2006-08/2010, BE5Z-3078-A 08/2010-04/2012, MCF-8, MCSOE-40)
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/chassis/front_susp_arms_stabilizer_x_member.html , https://www.fordpartsgiant.com/parts/ford-link_3m8z-5k483-l.html (front links 2006-2009)
#     https://www.fordpartsgiant.com/parts/ford-link_ae5z-5k483-a.html , https://www.fordpartsdeal.com/oem/ford~link~ae5z-5k483-a (front link 2010-2012)
#     https://www.fordpartsgiant.com/parts/ford-kit-repair_5m8z-5a486-a.html , https://www.fordpartsdeal.com/oem/ford~kit-repair~5m8z-5a486-a (rear link kit)
#     https://www.fordpartsgiant.com/parts-list/2011-ford-fusion/chassis/front_knuckle_and_hub.html
#     https://www.fordpartsgiant.com/parts/ford-bearing-assy-wheel-hub_3m8z-1215-a.html (front bearing; replaces F32Z-1215-A)
#     https://www.fordpartsgiant.com/parts/ford-hub-assy-wheel_6e5z-1104-ab.html (front hub flange; also rear on AWD per the rear knuckle list)
#     https://www.fordpartsgiant.com/parts-list/2008-ford-fusion/chassis/rear_knuckle_and_suspension_arms.html (and the 2011 page)
#     https://www.fordpartsgiant.com/parts/ford-hub-assy-wheel_6e5z-1104-ba.html , https://www.fordpartsdeal.com/oem/ford~hub-assembly-wheel~6e5z-1104-ba (rear FWD hub; replaces 6E5Z-1104-AA, HUB-128)
#
# Deliberately LEFT OUT (could not verify, < 90% confidence, or no clean supersession):
#   Filters & ignition:
#   -- Fuel filter: no separately serviced filter for MY2006-2012 (in-tank pump module); no fuel-filter row.
#   -- Hybrid oil filter: the 2010 Fusion Hybrid guide prints FL-2017-B (cartridge), the 2011 MKZ Hybrid guide FL-910, the EPC BE8Z-6731-AB, RockAuto FL910S; 85%, confirm by VIN.
#   -- Hybrid engine air filter: "long-life, designed to last the life of the vehicle", no number in the guide; EPC lists none for Gas/Electric.
#   -- Motorcraft <-> Ford pairings (FL-2017-B = 3S7Z-6731-A, FL-910S = BE8Z-6731-AB, FL-500-S = AA5Z-6714-A, FL-820-S = F1AZ-6731-BD, FA-1785 = 6E5Z-9601-EA,
#      FA-1786 = 6E5Z-9601-GA, FA-1884 = 7T4Z-9601-A, FP-67 = AE5Z-19N619-A): each number verified for the engine on its own; the pairing itself is snippet-level, so both are stored as OEM numbers of one part.
#   -- FL-500-S on the 3.0 for MY2006-2008: likely interchangeable with FL-820-S, no Fusion source for those years.
#   -- Other Motorcraft filter SKUs RockAuto lists for the application (VFL8, VFL2, FL2114, FL2123, FL2121, VFL1): not the same part, not stored.
#   -- Current Motorcraft plug numbers SP-530-X (I4) and SP-411-X (3.5): snippets only; none found for CGSF-22N-A1X.
#   -- Spark plug gaps and intervals: the guide tables point to the scheduled-maintenance chapter, not opened; the 3.0 2006-2009 gap prints as both 1.4 mm and .056 in on ford.com.
#   -- Coil Motorcraft numbers DG-516 (2.3), DG-522 (2.5), DG-520 (3.5): snippets only. 3.5 coil quantity not stated.
#   -- Aftermarket plugs, coils (Delphi GN10251 / GN10507, SMP UF516 / UF621 / UF486, NGK U5192, Denso 673-6012, Bosch 6710) and air filters (Pro-Tec PXA49053, Purolator C36099): snippets only.
#   -- Oil filter aftermarket for FL-820-S and for FL-500-S on the 3.5: RockAuto blocked after four pages.
#   Belts, cooling, battery, wipers:
#   -- Motorcraft retail numbers seen only in listings or snippets: JK6-875-A (2.5 belt), JK6-833 (Hybrid belt), JK6-455-D (3.0 belt 2010-2012),
#      BT-97 (3.5 tensioner), BT-81 (3.0 tensioner 2006-2009), RT-1175 (3.0 thermostat), RT-1253 (3.5 thermostat).
#   -- 2.3 manual-transmission belt JK6-892-A: only the MY2008 catalog page confirms it, so it is fitted to MY2008 only.
#   -- BT4Z-8620-A on the 2010-2012 3.0: listed by one mirror, but GB5Z-8620-A and 9L8Z-8620-A already cover that engine; kept for the 3.5 only.
#   -- 3.0 V6 battery MY2007-2009: manuals say BXT-40R (2008, 2009) or print BXL-96R-590 (2007), the mirror says BXT-96R-500; not seeded for the V6 in those years.
#   -- BXT-96R-590 (2010 catalog list): no Fusion fitment on its own page. BXL-96-RA retail "Tested Tough Plus" (2010 list, not for warranty): not seeded as a separate part.
#   -- EU2Z-8501-E / Motorcraft PW-594 as a successor of the 3.0 pump EU2Z-8501-D: ford.com titles it "2.5L/3.0L Flex" but nothing ties it to the Fusion.
#   -- 7T4Z-8501-C (3.5L pump, production 09/2007-07/2010): relation to AA5Z-8501-F not stated; probably MKZ-only before 2010.
#   -- Idler pulleys (4S7Z-8678-A, 9L8Z-8678-A -> AL8Z-8678-AA, 6E5Z-8678-AA -> -AC): diagram lists give no engine fitment.
#   -- Hybrid cabin-heater electric pump: not found. Coolant hoses and radiator fans: not researched.
#   -- Driver wiper WW-1801-PF (MY2012 manual) contradicts the 24 in EPC blade; left out. Blade lengths of Motorcraft retail numbers unverified.
#   -- Aftermarket cross-references (Gates, Dayco, Bando, Bosch, Trico, RockAuto): every page blocked or snippet-only.
#   Brakes:
#   -- Current Motorcraft retail pads BR1164C (front) / BR1161B (rear): ford.com search snippets only, product pages 404.
#   -- BRRC-82 as the current Motorcraft front rotor: third-party snippet only, not on Ford's 6U2Z-1V125-K page.
#   -- G2MZ-2V026-BBA rear disc (non-warranty) and its stated replacement T3MZ-1V125-G: a front-style number replacing a rear disc, not trusted.
#   -- Calipers (6E5Z-2B120-C / 2B121-C, reman 6E5Z-2V120-CRM / 2V121-CRM, rear reman 6E5Z-2V552-CRM / 2V553-CRM -> G2MZ-2V552/553-ERM) and parking brake: diagram pages tie no engine/AWD fitment to them, not researched further.
#   -- Wagner QC1164, Raybestos SGD1164C / SGD1161C / EHT1164H, Detroit Axle P-1164, Power Stop JBR1154 rotor: snippets only (finditparts 403, coyotedirect 404).
#   -- Pad set contents from Ford/Motorcraft: not stated on any reachable page.
#   Suspension:
#   -- Current Motorcraft retail SKUs (AST, ASH, MCF, MEF, HUB) for any part: they appear only as superseded numbers in Ford "Replaces" lists; which AST/ASH belonged to which engine or side is not stated.
#   -- Rear wheel bearing on AWD cars (3M8Z-1215-A paired with the AWD hub flange): inference from the rear knuckle list, 85%.
#   -- Front lower forward arm for cars built before 08/2006 (snippet lead Motorcraft MCF-24): unverified.
#   -- Loaded struts GU2Z-18A092-BB / -BC (2006 list only): part pages timed out, year range unverified.
#   -- Front upper arms (6E5Z-3085-BA discontinued, AE5Z-3084/3085-A..D caster-offset service arms): out of scope, fitment muddled.
#   -- H2MZ-1109-G "High Level Service Design" rear FWD hub (discontinued, 2006-2011): 85%.
#   -- Aftermarket, all snippet-only or retailer-only: Bilstein 19-112862 (rear, 85%), Monroe 5784, KYB 344363 / 349033 / 341405 / 341406 / SR4271,
#      Moog RK620492 / RK620149 / K750029, Dorman SL85625, Mevotech MS76814; Moog, KYB, Monroe, finditparts and RockAuto pages blocked.

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
-- Rows whose oem_key already exists from batch 1 (FL-910S, AYFS-32Y-RX, 9E5Z-12029-A)
-- resolve to the CD391 part: no duplicate, the part gets these names and the CD338 fitments.
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  ('oil-filter-23',       'oil-filters',    'Mühərrik yağ filtri, kartric (2.3 Duratec)',        'Масляный фильтр двигателя, картридж (2.3 Duratec)',      'Engine oil filter, cartridge (2.3 Duratec)',             'Motorcraft', 'FL-2017-B',    'Motorcraft', NULL, 'Cartridge element for the 2.3 (owner''s guides MY2007-2009). Replace the filter cap O-ring (1S7G-6885-AC) at every change. Ford 3S7Z-6731-A (replaces 3M4Z-6744-AC). The MY2006 guide lists "FL2017-A or FL910": early MY2006 cars may carry a spin-on filter instead.'),
  ('oil-filter-4cyl',     'oil-filters',    'Mühərrik yağ filtri',                               'Масляный фильтр двигателя',                              'Engine oil filter',                                      'Motorcraft', 'FL-910S',      'Motorcraft', NULL, 'Spin-on filter. CD391: all four-cylinder engines incl. Hybrid and Energi, MY2013-2020, no mid-cycle change. CD338: 2.5 Duratec MY2010-2012 (MY2010 guide prints FL-910), and early MY2006 2.3 cars built with a spin-on filter. Ford BE8Z-6731-AB (replaces 1S7Z-6731-DA). Manuals: if unavailable use a filter meeting SAE/USCAR-36.'),
  ('oil-filter-30-early', 'oil-filters',    'Mühərrik yağ filtri (3.0 Duratec V6, 2006-2009)',   'Масляный фильтр двигателя (3.0 Duratec V6, 2006-2009)',  'Engine oil filter (3.0 Duratec V6, 2006-2009)',          'Motorcraft', 'FL-820-S',     'Motorcraft', NULL, 'Spin-on filter per the MY2006-2008 guides; the MY2009 guide already prints FL-500-S, so both fit MY2009. Ford F1AZ-6731-BD (replaces F1AZ-6731-A).'),
  ('oil-filter-v6',       'oil-filters',    'Mühərrik yağ filtri (3.0 / 3.5 Duratec V6)',        'Масляный фильтр двигателя (3.0 / 3.5 Duratec V6)',       'Engine oil filter (3.0 / 3.5 Duratec V6)',               'Motorcraft', 'FL-500-S',     'Motorcraft', NULL, 'Spin-on filter per the MY2009-2012 guides (3.0 from MY2009, 3.5 Sport MY2010-2012). Ford AA5Z-6714-A.'),
  ('air-filter-i4-cd338', 'air-filters',    'Mühərrik hava filtri (2.3 / 2.5 Duratec)',          'Воздушный фильтр двигателя (2.3 / 2.5 Duratec)',         'Engine air filter (2.3 / 2.5 Duratec)',                  'Motorcraft', 'FA-1785',      'Motorcraft', NULL, 'Owner''s guides: FA-1683 for MY2006-2008, FA-1785 from MY2009; Ford 6E5Z-9601-EA for every year. Not for the Hybrid.'),
  ('air-filter-30',       'air-filters',    'Mühərrik hava filtri (3.0 Duratec V6)',             'Воздушный фильтр двигателя (3.0 Duratec V6)',            'Engine air filter (3.0 Duratec V6)',                     'Motorcraft', 'FA-1786',      'Motorcraft', NULL, 'Owner''s guides: FA-1771 for MY2006-2008, FA-1786 from MY2009; Ford 6E5Z-9601-GA for every year. FWD and AWD.'),
  ('air-filter-35',       'air-filters',    'Mühərrik hava filtri (3.5 Duratec V6)',             'Воздушный фильтр двигателя (3.5 Duratec V6)',            'Engine air filter (3.5 Duratec V6)',                     'Motorcraft', 'FA-1884',      'Motorcraft', NULL, 'Fusion Sport MY2010-2012. Ford 7T4Z-9601-A.'),
  ('cabin-filter-cd338',  'cabin-filters',  'Salon filtri (2010-2012)',                          'Салонный фильтр (2010-2012)',                            'Cabin air filter (2010-2012)',                           'Motorcraft', 'FP-67',        'Motorcraft', NULL, 'MY2010-2012 only, every engine incl. Hybrid, with and without dual A/C. MY2006-2009 cars have no factory cabin filter. Ford AE5Z-19N619-A.'),
  ('spark-plug-i4-cd338', 'spark-plugs',    'Alışdırma şamı (2.3 / 2.5 Duratec, Hybrid)',        'Свеча зажигания (2.3 / 2.5 Duratec, Hybrid)',            'Spark plug (2.3 / 2.5 Duratec, Hybrid / Energi)',        'Motorcraft', 'AYFS-32Y-RX',  'Ford',       NULL, '4 per car. CD391 2.5 Duratec and 2.0 Atkinson Hybrid / Energi (gap 2.5L 1.25-1.35 mm, 2.0 Atkinson 1.3 mm +/- 0.05; interval 100,000 mi / 60,000 mi severe) and CD338 2.3 (MY2006-2009), 2.5 and 2.5 Hybrid (MY2010-2012). Current iridium supersession SP530X (AYFS-32Y-RX); replaces AYFS-32Y-R, AYSF-32Y-PC, SP-490, SP-530. CD338 gap and interval not verified.'),
  ('spark-plug-30-early', 'spark-plugs',    'Alışdırma şamı (3.0 Duratec V6, 2006-2009)',        'Свеча зажигания (3.0 Duratec V6, 2006-2009)',            'Spark plug, platinum (3.0 Duratec V6, 2006-2009)',       'Motorcraft', 'SP-433-X',     'Motorcraft', NULL, '6 per car. Ford AGSF-32W-MX (replaces AGSF-32W-M, AGSF-32W-MF4, SP-433). Gap not seeded: ford.com prints both 1.4 mm and .056 in.'),
  ('spark-plug-30-late',  'spark-plugs',    'Alışdırma şamı (3.0 Duratec V6, 2010-2012)',        'Свеча зажигания (3.0 Duratec V6, 2010-2012)',            'Spark plug (3.0 Duratec V6, 2010-2012)',                 'Motorcraft', 'CGSF-22N-A1X', 'Ford',       NULL, '6 per car, flex-fuel 3.0. Replaces CGSF-22N-A1, CGSF-22N, CGSF-22F, SP-518-A, SP-518. No current Motorcraft retail number found.'),
  ('spark-plug-35',       'spark-plugs',    'Alışdırma şamı (3.5 Duratec V6)',                   'Свеча зажигания (3.5 Duratec V6)',                       'Spark plug (3.5 Duratec V6)',                            'Motorcraft', 'AYFS-22F-MX',  'Ford',       NULL, '6 per car, Fusion Sport. Replaces AYFS-22F-M and SP-411 (current SP-411-X seen in listings only).'),
  ('coil-30',             'ignition-coils', 'Alışdırma bobini (3.0 Duratec V6)',                 'Катушка зажигания (3.0 Duratec V6)',                     'Ignition coil (3.0 Duratec V6)',                         'Motorcraft', '6E5Z-12029-BA','Ford',       NULL, 'Coil-on-plug, 6 per car, MY2006-2012 gas and flex-fuel 3.0. Motorcraft DG-514.'),
  ('coil-23',             'ignition-coils', 'Alışdırma bobini (2.3 Duratec)',                    'Катушка зажигания (2.3 Duratec)',                        'Ignition coil (2.3 Duratec)',                            'Ford',       '6E5Z-12029-AA','Ford',       NULL, 'Coil-on-plug, 4 per car. Ford lists the number as discontinued without a successor; Motorcraft DG-516 seen in listings only.'),
  ('coil-25-hev',         'ignition-coils', 'Alışdırma bobini (2.5 Duratec / Hybrid)',           'Катушка зажигания (2.5 Duratec / Hybrid)',               'Ignition coil (2.5 Duratec / Hybrid / Energi)',          'Ford',       '9E5Z-12029-A', 'Ford',       NULL, 'Coil-on-plug, 4 per car. CD391 2.5 Duratec, 2.0 Atkinson Hybrid / Energi (MY2013-2020) and CD338 2.5 Duratec, 2.5 Hybrid (MY2010-2012). Motorcraft DG number not verified (DG-522 in listings only).'),
  ('coil-35',             'ignition-coils', 'Alışdırma bobini (3.5 Duratec V6)',                 'Катушка зажигания (3.5 Duratec V6)',                     'Ignition coil (3.5 Duratec V6)',                         'Ford',       '7T4Z-12029-E', 'Ford',       NULL, 'Coil-on-plug, Fusion Sport; quantity per car not stated by the catalog (6 cylinders). Motorcraft DG-520 seen in listings only.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('oil-filter-23',       '3S7Z-6731-A',   'OEM', 'Ford'),
  ('oil-filter-23',       '3M4Z-6744-AC',  'OEM', 'Ford'),
  ('oil-filter-23',       'CH9641',        'AFTERMARKET', 'FRAM'),
  ('oil-filter-23',       'XG9641',        'AFTERMARKET', 'FRAM'),
  ('oil-filter-23',       'TG9641',        'AFTERMARKET', 'FRAM'),
  ('oil-filter-23',       '57203',         'AFTERMARKET', 'WIX'),
  ('oil-filter-23',       '57203XP',       'AFTERMARKET', 'WIX'),
  ('oil-filter-23',       'OX203D',        'AFTERMARKET', 'Mahle'),
  ('oil-filter-23',       'PF1703',        'AFTERMARKET', 'ACDelco'),
  ('oil-filter-23',       'LF594',         'AFTERMARKET', 'Hastings'),
  ('oil-filter-23',       'L15505',        'AFTERMARKET', 'Purolator'),
  ('oil-filter-23',       'PL15505',       'AFTERMARKET', 'Purolator'),
  ('oil-filter-23',       'TL15505',       'AFTERMARKET', 'Purolator'),
  ('oil-filter-4cyl',     'FL-910',        'OEM', 'Motorcraft'),
  ('oil-filter-4cyl',     'BE8Z-6731-AB',  'OEM', 'Ford'),
  ('oil-filter-4cyl',     '1S7Z-6731-DA',  'OEM', 'Ford'),
  ('oil-filter-4cyl',     '51348XP',       'AFTERMARKET', 'WIX'),
  ('oil-filter-4cyl',     '3330',          'AFTERMARKET', 'Bosch'),
  ('oil-filter-4cyl',     '72161WS',       'AFTERMARKET', 'Bosch'),
  ('oil-filter-4cyl',     'PF53',          'AFTERMARKET', 'ACDelco'),
  ('oil-filter-4cyl',     'TL10241',       'AFTERMARKET', 'Purolator'),
  ('oil-filter-4cyl',     'PXL51348',      'AFTERMARKET', 'Purolator'),
  ('oil-filter-4cyl',     'OC338',         'AFTERMARKET', 'Mahle'),
  ('oil-filter-4cyl',     '1502010',       'AFTERMARKET', 'Denso'),
  ('oil-filter-4cyl',     'FE3614',        'AFTERMARKET', 'FRAM'),
  ('oil-filter-30-early', 'F1AZ-6731-BD',  'OEM', 'Ford'),
  ('oil-filter-30-early', 'F1AZ-6731-A',   'OEM', 'Ford'),
  ('oil-filter-v6',       'AA5Z-6714-A',   'OEM', 'Ford'),
  ('oil-filter-v6',       '57502',         'AFTERMARKET', 'WIX'),
  ('oil-filter-v6',       '57502XP',       'AFTERMARKET', 'WIX'),
  ('oil-filter-v6',       '3502',          'AFTERMARKET', 'Bosch'),
  ('oil-filter-v6',       'OC1047',        'AFTERMARKET', 'Mahle'),
  ('oil-filter-v6',       '1502021',       'AFTERMARKET', 'Denso'),
  ('air-filter-i4-cd338', 'FA-1683',       'OEM', 'Motorcraft'),
  ('air-filter-i4-cd338', '6E5Z-9601-EA',  'OEM', 'Ford'),
  ('air-filter-30',       'FA-1771',       'OEM', 'Motorcraft'),
  ('air-filter-30',       '6E5Z-9601-GA',  'OEM', 'Ford'),
  ('air-filter-35',       '7T4Z-9601-A',   'OEM', 'Ford'),
  ('cabin-filter-cd338',  'AE5Z-19N619-A', 'OEM', 'Ford'),
  ('spark-plug-i4-cd338', 'AYSF-32Y-PC',   'OEM', 'Ford'),
  ('spark-plug-i4-cd338', 'SP-490',        'OEM', 'Motorcraft'),
  ('spark-plug-30-early', 'SP-433',        'OEM', 'Motorcraft'),
  ('spark-plug-30-early', 'AGSF-32W-MX',   'OEM', 'Ford'),
  ('spark-plug-30-early', 'AGSF-32W-M',    'OEM', 'Ford'),
  ('spark-plug-30-early', 'AGSF-32W-MF4',  'OEM', 'Ford'),
  ('spark-plug-30-late',  'CGSF-22N-A1',   'OEM', 'Ford'),
  ('spark-plug-30-late',  'CGSF-22N',      'OEM', 'Ford'),
  ('spark-plug-30-late',  'CGSF-22F',      'OEM', 'Ford'),
  ('spark-plug-30-late',  'SP-518-A',      'OEM', 'Motorcraft'),
  ('spark-plug-30-late',  'SP-518',        'OEM', 'Motorcraft'),
  ('spark-plug-35',       'AYFS-22F-M',    'OEM', 'Ford'),
  ('spark-plug-35',       'SP-411',        'OEM', 'Motorcraft'),
  ('coil-30',             'DG-514',        'OEM', 'Motorcraft');

INSERT INTO seed_fits (key, year_from, year_to, engine_code, trims, notes) VALUES
  ('oil-filter-23',       2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('oil-filter-4cyl',     2006, 2006, '2.3 Duratec',      NULL, 'Early MY2006 cars built with a spin-on filter (guide: "FL2017-A or FL910"); cartridge cars use FL-2017-B'),
  ('oil-filter-4cyl',     2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('oil-filter-30-early', 2006, 2009, '3.0 Duratec V6',   NULL, NULL),
  ('oil-filter-v6',       2009, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('oil-filter-v6',       2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('air-filter-i4-cd338', 2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('air-filter-i4-cd338', 2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('air-filter-30',       2006, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('air-filter-35',       2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('cabin-filter-cd338',  2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('cabin-filter-cd338',  2010, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('cabin-filter-cd338',  2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('cabin-filter-cd338',  2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('spark-plug-i4-cd338', 2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('spark-plug-i4-cd338', 2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('spark-plug-i4-cd338', 2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('spark-plug-30-early', 2006, 2009, '3.0 Duratec V6',   NULL, NULL),
  ('spark-plug-30-late',  2010, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('spark-plug-35',       2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('coil-30',             2006, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('coil-23',             2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('coil-25-hev',         2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('coil-25-hev',         2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('coil-35',             2010, 2012, '3.5 Duratec V6',   NULL, NULL);

-- ---------- Belts, cooling, battery, wipers ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  ('belt-23-at',          'drive-belts',  'Generator qayışı (2.3 Duratec, avtomat)',                    'Ремень приводной (2.3 Duratec, АКПП)',                          'Serpentine belt (2.3 Duratec, automatic transmission)',        'Motorcraft', 'JK6-889-A',     'Motorcraft', NULL, 'Automatic-transmission cars only. Ford 6E5Z-8620-AE; supersedes 6E5Z-8620-B and JK6-887-A.'),
  ('belt-23-mt',          'drive-belts',  'Generator qayışı (2.3 Duratec, mexanika)',                   'Ремень приводной (2.3 Duratec, МКПП)',                          'Serpentine belt (2.3 Duratec, manual transmission)',           'Motorcraft', 'JK6-892-A',     'Motorcraft', NULL, 'Manual-transmission cars only. Ford 6E5Z-8620-C. Confirmed on the MY2008 catalog page; other model years likely but not verified.'),
  ('belt-30-main-0609',   'drive-belts',  'Generator qayışı, əsas (3.0 Duratec V6, 2006-2009)',         'Ремень приводной основной (3.0 Duratec V6, 2006-2009)',         'Serpentine belt, main (3.0 Duratec V6, 2006-2009)',            'Motorcraft', 'JK6-931',       'Motorcraft', NULL, 'Main accessory belt; the water pump runs on its own belt (6E5Z-8620-CA). Ford 6E5Z-8620-BB. FWD and AWD.'),
  ('belt-30-wp-0609',     'drive-belts',  'Su nasosu qayışı (3.0 Duratec V6, 2006-2009)',               'Ремень водяного насоса (3.0 Duratec V6, 2006-2009)',            'Water pump belt (3.0 Duratec V6, 2006-2009)',                  'Ford',       '6E5Z-8620-CA',  'Ford',       NULL, 'Second, short belt that drives the water pump (stretch fit).'),
  ('belt-25',             'drive-belts',  'Generator qayışı (2.5 Duratec, 2010-2012)',                  'Ремень приводной (2.5 Duratec, 2010-2012)',                     'Serpentine belt (2.5 Duratec, 2010-2012)',                     'Ford',       '9E5Z-8620-A',   'Ford',       NULL, 'Motorcraft retail number not verified (JK6-875-A seen in listings only).'),
  ('belt-hev',            'drive-belts',  'Generator qayışı (2.5 Hybrid)',                              'Ремень приводной (2.5 Hybrid)',                                 'Serpentine belt (2.5 Hybrid)',                                 'Ford',       'AE5Z-8620-A',   'Ford',       NULL, 'Fusion Hybrid MY2010-2012. Motorcraft retail number not verified.'),
  ('belt-30-main-1012',   'drive-belts',  'Generator qayışı, əsas (3.0 Duratec V6, 2010-2012)',         'Ремень приводной основной (3.0 Duratec V6, 2010-2012)',         'Serpentine belt, main (3.0 Duratec V6, 2010-2012)',            'Ford',       'GB5Z-8620-A',   'Ford',       NULL, 'Main accessory belt of the flex-fuel 3.0; the water pump runs on 9L8Z-8620-A. FWD and AWD.'),
  ('belt-30-wp-1012',     'drive-belts',  'Su nasosu qayışı (3.0 Duratec V6, 2010-2012)',               'Ремень водяного насоса (3.0 Duratec V6, 2010-2012)',            'Water pump belt (3.0 Duratec V6, 2010-2012)',                  'Ford',       '9L8Z-8620-A',   'Ford',       NULL, 'Second belt that drives the water pump.'),
  ('belt-35-main',        'drive-belts',  'Generator qayışı, əsas (3.5 Duratec V6)',                    'Ремень приводной основной (3.5 Duratec V6)',                    'Serpentine belt, main (3.5 Duratec V6)',                       'Ford',       'BT4Z-8620-A',   'Ford',       NULL, 'Fusion Sport. Supersedes 7T4Z-8620-C and 8T4Z-8620-A.'),
  ('belt-35-secondary',   'drive-belts',  'Köməkçi qayış (3.5 Duratec V6)',                             'Ремень вспомогательный (3.5 Duratec V6)',                       'Secondary accessory belt (3.5 Duratec V6)',                    'Ford',       '7T4Z-8620-A',   'Ford',       NULL, 'Fusion Sport. Ford catalog note: "For In Dealership Repairs Only". Sellers describe it as the power-steering / water-pump belt.'),
  ('tensioner-i4',        'drive-belts',  'Qayış dartıcısı (2.3 / 2.5 Duratec)',                        'Натяжитель ремня (2.3 / 2.5 Duratec)',                          'Belt tensioner (2.3 / 2.5 Duratec)',                           'Ford',       '6E5Z-6A228-B',  'Ford',       NULL, 'Tensioner pulley assembly; supersedes 3S4Z-6A228-AA, 6E5Z-6A228-BA and 6E5Z-6A228-AA.'),
  ('tensioner-hev',       'drive-belts',  'Qayış dartıcısı (2.5 Hybrid)',                               'Натяжитель ремня (2.5 Hybrid)',                                 'Belt tensioner (2.5 Hybrid)',                                  'Ford',       'AE5Z-6A228-A',  'Ford',       NULL, 'Fusion Hybrid MY2010-2012. Ford lists the number as discontinued; check availability before ordering.'),
  ('tensioner-30-0609',   'drive-belts',  'Qayış dartıcısı (3.0 Duratec V6, 2006-2009)',                'Натяжитель ремня (3.0 Duratec V6, 2006-2009)',                  'Belt tensioner (3.0 Duratec V6, 2006-2009)',                   'Ford',       '4L8Z-6B209-AA', 'Ford',       NULL, NULL),
  ('tensioner-30-1012',   'drive-belts',  'Qayış dartıcısı (3.0 Duratec V6, 2010-2012)',                'Натяжитель ремня (3.0 Duratec V6, 2010-2012)',                  'Belt tensioner (3.0 Duratec V6, 2010-2012)',                   'Ford',       '9L8Z-6B209-A',  'Ford',       NULL, NULL),
  ('tensioner-35',        'drive-belts',  'Qayış dartıcısı (3.5 Duratec V6)',                           'Натяжитель ремня (3.5 Duratec V6)',                             'Belt tensioner (3.5 Duratec V6)',                              'Ford',       'BT4Z-6B209-B',  'Ford',       NULL, 'Fusion Sport. Supersedes 8T4Z-6B209-A and 7T4Z-6B209-AA.'),
  ('thermostat-i4',       'thermostats',  'Termostat, korpusla, 82°C (2.3 / 2.5 Duratec, 2.5 Hybrid)',  'Термостат с корпусом, 82°C (2.3 / 2.5 Duratec, 2.5 Hybrid)',    'Thermostat with water outlet housing, 82 C (2.3 / 2.5 Duratec, 2.5 Hybrid)', 'Ford', '3M4Z-8575-B', 'Ford', NULL, 'Same part as the CD391 2.5 (batch 1): thermostat with its housing, includes gasket. CD338: 2.3 (MY2006-2009), 2.5 and 2.5 Hybrid (MY2010-2012). Supersedes 3M4Z-8575-A and 3M4Z-8575-AB. Motorcraft RT-1193 likely but unverified. Separate gaskets catalogued: 6G9Z-8255-BA (2.3 / 2.5), 1S7G-8255-BD (2.3 and Hybrid).'),
  ('thermostat-30',       'thermostats',  'Termostat (3.0 Duratec V6)',                                 'Термостат (3.0 Duratec V6)',                                    'Thermostat (3.0 Duratec V6)',                                  'Ford',       '1X4Z-8575-EB',  'Ford',       NULL, 'Same thermostat on the 2006-2009 gas and 2010-2012 flex-fuel 3.0. Supersedes 1X4Z-8575-EA. Seal 9L8Z-8255-B (2010-2012).'),
  ('thermostat-35',       'thermostats',  'Termostat (3.5 Duratec V6)',                                 'Термостат (3.5 Duratec V6)',                                    'Thermostat (3.5 Duratec V6)',                                  'Motorcraft', '1X4Z-8575-B',   'Ford',       NULL, 'Fusion Sport. Supersedes 1X4Z-8575-FA, 1X4Z-8575-A, Motorcraft RT-1228 and RT-1172. O-ring F1VY-8255-A.'),
  ('waterpump-i4',        'water-pumps',  'Su nasosu, qasnaqla (2.3 / 2.5 Duratec, 2.5 Hybrid)',        'Водяной насос (помпа) со шкивом (2.3 / 2.5 Duratec, 2.5 Hybrid)', 'Engine water pump with 3-bolt pulley (2.3 / 2.5 Duratec, 2.5 Hybrid)', 'Motorcraft', '4S4Z-8501-E', 'Ford', NULL, 'Same part as the CD391 2.5 (batch 1): Motorcraft PW624, belt-driven, gasket 1S7Z-8507-AE sold separately. CD338: 2.3 (MY2006-2009), 2.5 and 2.5 Hybrid (MY2010-2012). Supersedes 1S7Z-8501-AK, 4S4Z-8501-D, 4S4Z-8501-AA, 6M8Z-8501-AC, Motorcraft PW-465 and PW-447.'),
  ('waterpump-30-0609',   'water-pumps',  'Su nasosu (3.0 Duratec V6, 2006-2009)',                      'Водяной насос (помпа) (3.0 Duratec V6, 2006-2009)',             'Engine water pump (3.0 Duratec V6, 2006-2009)',                'Motorcraft', 'EU2Z-8501-D',   'Ford',       NULL, 'Supersedes 3M4Z-8501-BG, 3M4Z-8501-BJ, 5M8Z-8501-B, 5M8Z-8501-A, Motorcraft PW-481, PW-437 and PW-440. Gasket 2X4Z-8507-BA.'),
  ('waterpump-30-1012',   'water-pumps',  'Su nasosu (3.0 Duratec V6, 2010-2012)',                      'Водяной насос (помпа) (3.0 Duratec V6, 2010-2012)',             'Engine water pump (3.0 Duratec V6, 2010-2012)',                'Ford',       '9L8Z-8501-A',   'Ford',       NULL, 'Pump only; the housing is a separate part (9L8Z-8501-C). Gasket 9L8Z-8507-A.'),
  ('waterpump-35',        'water-pumps',  'Su nasosu (3.5 Duratec V6)',                                 'Водяной насос (помпа) (3.5 Duratec V6)',                        'Engine water pump (3.5 Duratec V6)',                           'Motorcraft', 'AA5Z-8501-F',   'Ford',       NULL, 'Fusion Sport. Supersedes 7T4Z-8501-D, AA5Z-8501-D, AA5Z-8501-A, Motorcraft PW-495, PW-489, PW-538 and PW-498.'),
  ('coolant-pump-hev',    'water-pumps',  'Elektrik soyuducu nasosu, invertor konturu (Hybrid)',        'Электрический насос ОЖ, контур инвертора (Hybrid)',             'Electric coolant pump, inverter / drive motor loop (Hybrid)',  'Ford',       '9E5Z-8C419-B',  'Ford',       NULL, 'Ford name: "Drive Motor Inverter Cooler Water Pump". Supersedes 9E5Z-8C419-A.'),
  ('battery-40r',         'batteries',    'Akkumulyator 12V, qrup 40R',                                 'Аккумулятор 12 В, группа 40R',                                  '12 V battery, BCI group 40R',                                  'Motorcraft', 'BXT-40-R',      'Motorcraft', NULL, 'MY2006 owner''s manual spec (2.3 and 3.0). Supersedes BXL-40-R. Capacity not stated by the sources.'),
  ('battery-96r-500',     'batteries',    'Akkumulyator 12V, qrup 96R, 500 CCA',                        'Аккумулятор 12 В, группа 96R, 500 CCA',                         '12 V battery, BCI group 96R, 500 CCA',                         'Motorcraft', 'BXT-96R-500',   'Motorcraft', NULL, '500 CCA, 90 min reserve. Owner''s manuals: 2.3 MY2008-2009, every gas engine MY2011-2012. Supersedes BXT-96-R. The 3.0 V6 battery for MY2007-2009 is not settled by the sources.'),
  ('battery-hev-12v',     'batteries',    'Akkumulyator 12V köməkçi, qrup 67R (Hybrid)',                'Аккумулятор 12 В вспомогательный, группа 67R (Hybrid)',         '12 V auxiliary battery, BCI group 67R (Hybrid)',               'Motorcraft', 'BXT-67R',       'Motorcraft', NULL, 'Under-hood 12 V battery of the Fusion Hybrid, 390 CCA / 65 min reserve. Not the high-voltage pack. Spacers BS-1 / BS-2 may be needed.'),
  ('wiper-driver',        'wiper-blades', 'Şüşəsilən fırçası, ön sol (sürücü), 24"',                    'Щётка стеклоочистителя передняя левая (водительская), 24"',     'Front wiper blade, driver side, 24 in',                        'Ford',       '6E5Z-17528-AA', 'Ford',       'FRONT_LEFT',  'Conventional blade, same for MY2006-2012. Premium flat blade AU2Z-17V528-HA also catalogued.'),
  ('wiper-passenger',     'wiper-blades', 'Şüşəsilən fırçası, ön sağ (sərnişin), 19"',                  'Щётка стеклоочистителя передняя правая (пассажирская), 19"',    'Front wiper blade, passenger side, 19 in',                     'Motorcraft', '6E5Z-17528-AB', 'Ford',       'FRONT_RIGHT', 'Conventional blade, same for MY2006-2012; Motorcraft WW-1901-PF per the MY2012 owner''s manual. Premium flat blade AU2Z-17V528-DA also catalogued.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('belt-23-at',        '6E5Z-8620-AE',  'OEM', 'Ford'),
  ('belt-23-at',        '6E5Z-8620-B',   'OEM', 'Ford'),
  ('belt-23-at',        'JK6-887-A',     'OEM', 'Motorcraft'),
  ('belt-23-mt',        '6E5Z-8620-C',   'OEM', 'Ford'),
  ('belt-30-main-0609', '6E5Z-8620-BB',  'OEM', 'Ford'),
  ('belt-35-main',      '7T4Z-8620-C',   'OEM', 'Ford'),
  ('belt-35-main',      '8T4Z-8620-A',   'OEM', 'Ford'),
  ('tensioner-i4',      '3S4Z-6A228-AA', 'OEM', 'Ford'),
  ('tensioner-i4',      '6E5Z-6A228-BA', 'OEM', 'Ford'),
  ('tensioner-i4',      '6E5Z-6A228-AA', 'OEM', 'Ford'),
  ('tensioner-35',      '8T4Z-6B209-A',  'OEM', 'Ford'),
  ('tensioner-35',      '7T4Z-6B209-AA', 'OEM', 'Ford'),
  ('thermostat-i4',     '3M4Z-8575-A',   'OEM', 'Ford'),
  ('thermostat-i4',     '3M4Z-8575-AB',  'OEM', 'Ford'),
  ('thermostat-30',     '1X4Z-8575-EA',  'OEM', 'Ford'),
  ('thermostat-35',     '1X4Z-8575-FA',  'OEM', 'Ford'),
  ('thermostat-35',     '1X4Z-8575-A',   'OEM', 'Ford'),
  ('thermostat-35',     'RT-1228',       'OEM', 'Motorcraft'),
  ('thermostat-35',     'RT-1172',       'OEM', 'Motorcraft'),
  ('waterpump-i4',      '1S7Z-8501-AK',  'OEM', 'Ford'),
  ('waterpump-i4',      '4S4Z-8501-D',   'OEM', 'Ford'),
  ('waterpump-i4',      '4S4Z-8501-AA',  'OEM', 'Ford'),
  ('waterpump-i4',      '6M8Z-8501-AC',  'OEM', 'Ford'),
  ('waterpump-i4',      'PW-465',        'OEM', 'Motorcraft'),
  ('waterpump-i4',      'PW-447',        'OEM', 'Motorcraft'),
  ('waterpump-30-0609', '3M4Z-8501-BG',  'OEM', 'Ford'),
  ('waterpump-30-0609', '3M4Z-8501-BJ',  'OEM', 'Ford'),
  ('waterpump-30-0609', '5M8Z-8501-B',   'OEM', 'Ford'),
  ('waterpump-30-0609', '5M8Z-8501-A',   'OEM', 'Ford'),
  ('waterpump-30-0609', 'PW-481',        'OEM', 'Motorcraft'),
  ('waterpump-30-0609', 'PW-437',        'OEM', 'Motorcraft'),
  ('waterpump-30-0609', 'PW-440',        'OEM', 'Motorcraft'),
  ('waterpump-35',      '7T4Z-8501-D',   'OEM', 'Ford'),
  ('waterpump-35',      'AA5Z-8501-D',   'OEM', 'Ford'),
  ('waterpump-35',      'AA5Z-8501-A',   'OEM', 'Ford'),
  ('waterpump-35',      'PW-495',        'OEM', 'Motorcraft'),
  ('waterpump-35',      'PW-489',        'OEM', 'Motorcraft'),
  ('waterpump-35',      'PW-538',        'OEM', 'Motorcraft'),
  ('waterpump-35',      'PW-498',        'OEM', 'Motorcraft'),
  ('coolant-pump-hev',  '9E5Z-8C419-A',  'OEM', 'Ford'),
  ('battery-40r',       'BXT-40R',       'OEM', 'Motorcraft'),
  ('battery-40r',       'BXL-40-R',      'OEM', 'Motorcraft'),
  ('battery-96r-500',   'BXT-96-R',      'OEM', 'Motorcraft'),
  ('battery-96r-500',   'BXT-96R',       'OEM', 'Motorcraft'),
  ('battery-hev-12v',   'BXT-67-R',      'OEM', 'Motorcraft'),
  ('wiper-passenger',   'WW-1901-PF',    'OEM', 'Motorcraft');

INSERT INTO seed_fits (key, year_from, year_to, engine_code, trims, notes) VALUES
  ('belt-23-at',        2006, 2009, '2.3 Duratec',      NULL, 'Automatic transmission'),
  ('belt-23-mt',        2008, 2008, '2.3 Duratec',      NULL, 'Manual transmission; MY2008 confirmed, other years unverified'),
  ('belt-30-main-0609', 2006, 2009, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('belt-30-wp-0609',   2006, 2009, '3.0 Duratec V6',   NULL, NULL),
  ('belt-25',           2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('belt-hev',          2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('belt-30-main-1012', 2010, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('belt-30-wp-1012',   2010, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('belt-35-main',      2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('belt-35-secondary', 2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('tensioner-i4',      2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('tensioner-i4',      2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('tensioner-hev',     2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('tensioner-30-0609', 2006, 2009, '3.0 Duratec V6',   NULL, NULL),
  ('tensioner-30-1012', 2010, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('tensioner-35',      2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('thermostat-i4',     2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('thermostat-i4',     2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('thermostat-i4',     2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('thermostat-30',     2006, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('thermostat-35',     2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('waterpump-i4',      2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('waterpump-i4',      2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('waterpump-i4',      2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('waterpump-30-0609', 2006, 2009, '3.0 Duratec V6',   NULL, NULL),
  ('waterpump-30-1012', 2010, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('waterpump-35',      2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('coolant-pump-hev',  2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('battery-40r',       2006, 2006, '2.3 Duratec',      NULL, NULL),
  ('battery-40r',       2006, 2006, '3.0 Duratec V6',   NULL, NULL),
  ('battery-96r-500',   2007, 2009, '2.3 Duratec',      NULL, NULL),
  ('battery-96r-500',   2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('battery-96r-500',   2010, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('battery-96r-500',   2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('battery-hev-12v',   2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('wiper-driver',      2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('wiper-driver',      2006, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('wiper-driver',      2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('wiper-driver',      2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('wiper-driver',      2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('wiper-passenger',   2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('wiper-passenger',   2006, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('wiper-passenger',   2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('wiper-passenger',   2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('wiper-passenger',   2010, 2012, '2.5 Atkinson HEV', NULL, NULL);

-- ---------- Brakes ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  ('front-pads-cd338',  'brake-pads',  'Ön əyləc kolodkaları dəsti',        'Колодки тормозные передние, комплект',    'Front brake pad set',      'Motorcraft', '6U2Z-2V001-F', 'Ford',       'FRONT', 'One kit for the whole CD338 line, MY2006-2012, every engine and trim incl. Sport and Hybrid, FWD and AWD. Current Ford number T3MZ-2V001-S; Motorcraft BRF-1164 / BR-1164-B superseded.'),
  ('rear-pads-cd338',   'brake-pads',  'Arxa əyləc kolodkaları dəsti',      'Колодки тормозные задние, комплект',      'Rear brake pad set',       'Motorcraft', '6U2Z-2V200-B', 'Ford',       'REAR',  'One kit for MY2006-2012, every engine and trim, FWD and AWD. Current Ford number T3MZ-2V200-R; Motorcraft BRF-24 superseded.'),
  ('front-rotor-cd338', 'brake-discs', 'Ön əyləc diski, ventilyasiyalı',    'Тормозной диск передний, вентилируемый',  'Front brake disc, vented', 'Motorcraft', '6U2Z-1V125-K', 'Ford',       'FRONT', 'Sold singly (2 per car). 299 x 25 mm, minimum 23 mm (Brembo equivalent spec). One disc for MY2006-2012, all engines and trims incl. Sport. Current Ford number T3MZ-1V125-CA; Motorcraft BRRF-116 / BRRF-30 / BRR-144 / BRR-295 superseded.'),
  ('rear-rotor-cd338',  'brake-discs', 'Arxa əyləc diski, ventilyasiyasız', 'Тормозной диск задний, невентилируемый',  'Rear brake disc, solid',   'Motorcraft', 'BRRF-29',      'Motorcraft', 'REAR',  'Sold singly (2 per car). 280 x 10 mm, minimum 8 mm, solid (Brembo equivalent spec). One disc for MY2006-2012, all engines and trims, FWD and AWD. Ford 9E5Z-2C026-B.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('front-pads-cd338',  'T3MZ-2V001-S',  'OEM', 'Ford'),
  ('front-pads-cd338',  '6U2Z-2V001-D',  'OEM', 'Ford'),
  ('front-pads-cd338',  '6E5Z-2001-B',   'OEM', 'Ford'),
  ('front-pads-cd338',  '6E5Z-2001-C',   'OEM', 'Ford'),
  ('front-pads-cd338',  '7E5Z-2001-A',   'OEM', 'Ford'),
  ('front-pads-cd338',  '9E5Z-2001-A',   'OEM', 'Ford'),
  ('front-pads-cd338',  'G2MZ-2V001-AF', 'OEM', 'Ford'),
  ('front-pads-cd338',  'BRF-1164',      'OEM', 'Motorcraft'),
  ('front-pads-cd338',  'BR-1164-B',     'OEM', 'Motorcraft'),
  ('front-pads-cd338',  'Z23-1164',      'AFTERMARKET', 'Power Stop'),
  ('rear-pads-cd338',   'T3MZ-2V200-R',  'OEM', 'Ford'),
  ('rear-pads-cd338',   '6E5Z-2200-B',   'OEM', 'Ford'),
  ('rear-pads-cd338',   '6E5Z-2200-C',   'OEM', 'Ford'),
  ('rear-pads-cd338',   '9E5Z-2200-A',   'OEM', 'Ford'),
  ('rear-pads-cd338',   'BE5Z-2200-A',   'OEM', 'Ford'),
  ('rear-pads-cd338',   'J2MZ-2V200-J',  'OEM', 'Ford'),
  ('rear-pads-cd338',   'BRF-24',        'OEM', 'Motorcraft'),
  ('rear-pads-cd338',   'Z23-1161',      'AFTERMARKET', 'Power Stop'),
  ('front-rotor-cd338', 'T3MZ-1V125-CA', 'OEM', 'Ford'),
  ('front-rotor-cd338', '6E5Z-1125-AA',  'OEM', 'Ford'),
  ('front-rotor-cd338', '9E5Z-1125-A',   'OEM', 'Ford'),
  ('front-rotor-cd338', '9E5Z-1125-B',   'OEM', 'Ford'),
  ('front-rotor-cd338', '9E5Z-1125-C',   'OEM', 'Ford'),
  ('front-rotor-cd338', '6U2Z-1V125-E',  'OEM', 'Ford'),
  ('front-rotor-cd338', '6U2Z-1V125-H',  'OEM', 'Ford'),
  ('front-rotor-cd338', 'G2MZ-1V125-JA', 'OEM', 'Ford'),
  ('front-rotor-cd338', 'BRRF-116',      'OEM', 'Motorcraft'),
  ('front-rotor-cd338', 'BRRF-30',       'OEM', 'Motorcraft'),
  ('front-rotor-cd338', 'BRR-144',       'OEM', 'Motorcraft'),
  ('front-rotor-cd338', 'BRR-295',       'OEM', 'Motorcraft'),
  ('front-rotor-cd338', '09.B543.11',    'AFTERMARKET', 'Brembo'),
  ('rear-rotor-cd338',  '9E5Z-2C026-B',  'OEM', 'Ford'),
  ('rear-rotor-cd338',  '9E5Z-2C026-A',  'OEM', 'Ford'),
  ('rear-rotor-cd338',  '6E5Z-2C026-AA', 'OEM', 'Ford'),
  ('rear-rotor-cd338',  '08.N226.11',    'AFTERMARKET', 'Brembo');

INSERT INTO seed_fits (key, year_from, year_to, engine_code, trims, notes) VALUES
  ('front-pads-cd338',  2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('front-pads-cd338',  2006, 2009, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('front-pads-cd338',  2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('front-pads-cd338',  2010, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('front-pads-cd338',  2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('front-pads-cd338',  2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('rear-pads-cd338',   2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('rear-pads-cd338',   2006, 2009, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('rear-pads-cd338',   2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('rear-pads-cd338',   2010, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('rear-pads-cd338',   2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('rear-pads-cd338',   2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('front-rotor-cd338', 2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('front-rotor-cd338', 2006, 2009, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('front-rotor-cd338', 2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('front-rotor-cd338', 2010, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('front-rotor-cd338', 2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('front-rotor-cd338', 2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('rear-rotor-cd338',  2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('rear-rotor-cd338',  2006, 2009, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('rear-rotor-cd338',  2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('rear-rotor-cd338',  2010, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('rear-rotor-cd338',  2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('rear-rotor-cd338',  2010, 2012, '2.5 Atkinson HEV', NULL, NULL);

-- ---------- Suspension ----------
INSERT INTO seed_parts (key, category_slug, name_az, name_ru, name_en, brand, oem_key, oem_key_source, position, description) VALUES
  ('fstrut-l-0609',        'shock-absorbers',  'Ön amortizator dayağı, sol (2006-2009)',                          'Стойка амортизатора передняя левая (2006-2009)',                          'Front strut, left (2006-2009)',                                    'Ford', '7E5Z-18124-LH', 'Ford', 'FRONT_LEFT',  'Bare strut without spring, qty 1. Every original 2006-2009 strut (2.3, 3.0 FWD/AWD, sport-tuned) is superseded to this one number; Motorcraft AST-159 / -160 / -161 / -280 / -336 / -389 superseded.'),
  ('fstrut-r-0609',        'shock-absorbers',  'Ön amortizator dayağı, sağ (2006-2009)',                          'Стойка амортизатора передняя правая (2006-2009)',                         'Front strut, right (2006-2009)',                                   'Ford', '7E5Z-18124-RH', 'Ford', 'FRONT_RIGHT', 'Bare strut without spring, qty 1. Supersedes every original 2006-2009 right strut; Motorcraft AST-162 / -163 / -164 / -279 / -337 / -388 superseded.'),
  ('fstrut-l-1012',        'shock-absorbers',  'Ön amortizator dayağı, sol (2010-2012)',                          'Стойка амортизатора передняя левая (2010-2012)',                          'Front strut, left (2010-2012)',                                    'Ford', 'AH6Z-18124-D',  'Ford', 'FRONT_LEFT',  'Bare strut without spring, qty 1. One number for 2.5, 3.0 FWD/AWD, 3.5 Sport and Hybrid (all wheel sizes); Motorcraft AST-421 / -423 / -425 / -427 / -439 / -471 superseded.'),
  ('fstrut-r-1012',        'shock-absorbers',  'Ön amortizator dayağı, sağ (2010-2012)',                          'Стойка амортизатора передняя правая (2010-2012)',                         'Front strut, right (2010-2012)',                                   'Ford', 'AH6Z-18124-C',  'Ford', 'FRONT_RIGHT', 'Bare strut without spring, qty 1. One number for every 2010-2012 engine incl. Sport and Hybrid; Motorcraft AST-420 / -422 / -424 / -426 / -438 / -470 superseded.'),
  ('fstrut-loaded-l-0809', 'shock-absorbers',  'Ön amortizator dayağı yaylı, komplekt, sol (2008-2009)',          'Стойка передняя в сборе с пружиной, левая (2008-2009)',                   'Front strut assembly with spring, left (2008-2009)',               'Ford', 'GU2Z-18A092-BE','Ford', 'FRONT_LEFT',  'Loaded strut (damper, spring and mount), qty 1. Supersedes GU2Z-18A092-Z and Motorcraft ASTL-27. 2006-2007 cars use GU2Z-18A092-BC (unverified).'),
  ('fstrut-loaded-r-0809', 'shock-absorbers',  'Ön amortizator dayağı yaylı, komplekt, sağ (2008-2009)',          'Стойка передняя в сборе с пружиной, правая (2008-2009)',                  'Front strut assembly with spring, right (2008-2009)',              'Ford', 'GU2Z-18A092-BD','Ford', 'FRONT_RIGHT', 'Loaded strut (damper, spring and mount), qty 1. Supersedes GU2Z-18A092-X.'),
  ('fstrut-loaded-l-1012', 'shock-absorbers',  'Ön amortizator dayağı yaylı, komplekt, sol (2.5 / 3.0, 2010-2012)','Стойка передняя в сборе с пружиной, левая (2.5 / 3.0, 2010-2012)',       'Front strut assembly with spring, left (2.5 / 3.0, 2010-2012)',    'Ford', 'JU2Z-18A092-B', 'Ford', 'FRONT_LEFT',  'Loaded strut, qty 1. 2.5 and 3.0 cars; Sport and Hybrid use GU2Z-18A092-V.'),
  ('fstrut-loaded-r-1012', 'shock-absorbers',  'Ön amortizator dayağı yaylı, komplekt, sağ (2.5 / 3.0, 2010-2012)','Стойка передняя в сборе с пружиной, правая (2.5 / 3.0, 2010-2012)',      'Front strut assembly with spring, right (2.5 / 3.0, 2010-2012)',   'Ford', 'JU2Z-18A092-A', 'Ford', 'FRONT_RIGHT', 'Loaded strut, qty 1. 2.5 and 3.0 cars; Sport and Hybrid use GU2Z-18A092-U.'),
  ('fstrut-loaded-l-sh',   'shock-absorbers',  'Ön amortizator dayağı yaylı, komplekt, sol (Sport / Hybrid)',     'Стойка передняя в сборе с пружиной, левая (Sport / Hybrid)',              'Front strut assembly with spring, left (Sport / Hybrid)',          'Ford', 'GU2Z-18A092-V', 'Ford', 'FRONT_LEFT',  'Loaded strut, qty 1. Fusion Sport 3.5 and Fusion Hybrid, 2010-2012.'),
  ('fstrut-loaded-r-sh',   'shock-absorbers',  'Ön amortizator dayağı yaylı, komplekt, sağ (Sport / Hybrid)',     'Стойка передняя в сборе с пружиной, правая (Sport / Hybrid)',             'Front strut assembly with spring, right (Sport / Hybrid)',         'Ford', 'GU2Z-18A092-U', 'Ford', 'FRONT_RIGHT', 'Loaded strut, qty 1. Fusion Sport 3.5 and Fusion Hybrid, 2010-2012.'),
  ('rshock-cd338',         'shock-absorbers',  'Arxa amortizator',                                                 'Амортизатор задний',                                                      'Rear shock absorber',                                              'Ford', '6E5Z-18125-BA', 'Ford', 'REAR',        'Same part both sides, qty 2. Every original 2006-2012 rear shock (2.3, 3.0 AWD, sport-tuned, 2010-2012 wheel-size / AWD / Hybrid versions) is superseded to this number; Motorcraft ASH-420 to -425, ASH-431, ASH-432, ASH-440, AST-177 / -179 / -281 / -282 / -283 / -338 superseded.'),
  ('strut-mount-0608',     'strut-mounts',     'Ön amortizator üst dayağı (2006-2008)',                           'Опора передней стойки верхняя (2006-2008)',                               'Front strut upper mount (2006-2008)',                              'Ford', '6E5Z-18183-B',  'Ford', 'FRONT',       'Qty 2. Ford lists it as discontinued without a successor; from MY2008 the catalog shows 8E5Z-18183-A (mid-2008 production split, check by VIN).'),
  ('strut-mount-0812',     'strut-mounts',     'Ön amortizator üst dayağı (2008-2012)',                           'Опора передней стойки верхняя (2008-2012)',                               'Front strut upper mount (2008-2012)',                              'Ford', '8E5Z-18183-A',  'Ford', 'FRONT',       'Qty 2. MY2008 overlaps with 6E5Z-18183-B (production split, check by VIN).'),
  ('strut-mount-damper',   'strut-mounts',     'Ön amortizator dayağının dempferi (yastıq)',                      'Демпфер (шайба) опоры передней стойки',                                   'Front strut mount damper washer',                                  'Ford', 'AE5Z-3F690-A',  'Ford', 'FRONT',       'Insulator / washer at the strut top, qty 2. Supersedes 6E5Z-3F690-A.'),
  ('strut-bearing-cd338',  'strut-mounts',     'Ön amortizator dayaq podşipniki',                                  'Подшипник опоры передней стойки',                                         'Front strut bearing',                                              'Ford', 'AE5Z-18198-A',  'Ford', 'FRONT',       'Qty 2. Supersedes 6E5Z-18198-A.'),
  ('lca-rear-l',           'control-arms',     'Ön aşağı rıçaq, arxa (şar dayaqlı), sol',                         'Рычаг передний нижний задний (с шаровой опорой), левый',                  'Front lower control arm, rearward, with ball joint, left',         'Ford', 'BE5Z-3079-A',   'Ford', 'FRONT_LEFT',  'The side-specific lower arm with the ball joint (aftermarket: "lower rearward"). Supersedes 5M8Z-3079-L, 6M8Z-3079-L (standard) and 7E5Z-3079-L (sport-tuned / AWD); Motorcraft kits MCSOE-123 / MCSOE-139.'),
  ('lca-rear-r',           'control-arms',     'Ön aşağı rıçaq, arxa (şar dayaqlı), sağ',                         'Рычаг передний нижний задний (с шаровой опорой), правый',                 'Front lower control arm, rearward, with ball joint, right',        'Ford', 'BE5Z-3078-B',   'Ford', 'FRONT_RIGHT', 'Supersedes 5M8Z-3078-R, 6M8Z-3078-R and 7E5Z-3078-RA; Motorcraft kits MCSOE-93 / MCSOE-107.'),
  ('lca-forward',          'control-arms',     'Ön aşağı rıçaq, ön (düz)',                                         'Рычаг передний нижний передний (прямой)',                                 'Front lower control arm, forward (straight)',                      'Ford', 'AE5Z-3078-A',   'Ford', 'FRONT',       'Same part left and right, qty 2 (aftermarket: "lower forward"). Supersedes 7E5Z-3078-R (built 08/2006-08/2010) and BE5Z-3078-A (08/2010-04/2012); Motorcraft MCF-8 / kit MCSOE-40. Cars built before 08/2006 use an unverified earlier arm.'),
  ('stab-link-fl-0609',    'stabilizer-links', 'Ön stabilizator dartqısı, sol (2006-2009)',                        'Стойка стабилизатора передняя левая (2006-2009)',                         'Front stabilizer bar link, left (2006-2009)',                      'Ford', '3M8Z-5K483-L',  'Ford', 'FRONT_LEFT',  NULL),
  ('stab-link-fr-0609',    'stabilizer-links', 'Ön stabilizator dartqısı, sağ (2006-2009)',                        'Стойка стабилизатора передняя правая (2006-2009)',                        'Front stabilizer bar link, right (2006-2009)',                     'Ford', '3M8Z-5K483-R',  'Ford', 'FRONT_RIGHT', NULL),
  ('stab-link-f-1012',     'stabilizer-links', 'Ön stabilizator dartqısı (2010-2012)',                             'Стойка стабилизатора передняя (2010-2012)',                               'Front stabilizer bar link (2010-2012)',                            'Ford', 'AE5Z-5K483-A',  'Ford', 'FRONT',       'Same part left and right, qty 2; every 2010-2012 engine incl. Sport and Hybrid.'),
  ('stab-link-rear-cd338', 'stabilizer-links', 'Arxa stabilizator dartqısı',                                       'Стойка стабилизатора задняя',                                             'Rear stabilizer bar link',                                         'Ford', '5M8Z-5A486-A',  'Ford', 'REAR',        'Repair kit, same part left and right, qty 2; FWD and AWD, MY2006-2012.'),
  ('front-bearing-cd338',  'wheel-bearings',   'Ön təkər podşipniki (preslənən)',                                  'Подшипник передней ступицы (запрессовываемый)',                           'Front wheel bearing, press-in',                                    'Ford', '3M8Z-1215-A',   'Ford', 'FRONT',       'Same part left and right, qty 2; the hub flange 6E5Z-1104-AB is separate. Supersedes F32Z-1215-A.'),
  ('front-hub-cd338',      'wheel-bearings',   'Ön təkər topu (flanş)',                                            'Ступица передняя (фланец)',                                               'Front wheel hub flange',                                           'Ford', '6E5Z-1104-AB',  'Ford', 'FRONT',       'Same part left and right, qty 2; pressed into bearing 3M8Z-1215-A. Ford also lists it as the rear hub flange on AWD cars (rear bearing for AWD not confirmed).'),
  ('rear-hub-fwd-cd338',   'wheel-bearings',   'Arxa təkər topu, podşipniklə (FWD)',                               'Ступица задняя в сборе с подшипником (FWD)',                              'Rear wheel hub and bearing assembly (FWD)',                        'Ford', '6E5Z-1104-BA',  'Ford', 'REAR',        'FWD cars only, qty 2, with the ABS tone ring. Supersedes 6E5Z-1104-AA and Motorcraft HUB-128.');

INSERT INTO seed_numbers (key, number, type, source) VALUES
  ('fstrut-l-0609',        '6E5Z-18124-AL', 'OEM', 'Ford'),
  ('fstrut-l-0609',        '6E5Z-18124-BL', 'OEM', 'Ford'),
  ('fstrut-l-0609',        '8E5Z-18124-L',  'OEM', 'Ford'),
  ('fstrut-l-0609',        '6H6Z-18124-AL', 'OEM', 'Ford'),
  ('fstrut-l-0609',        '7H6Z-18124-LH', 'OEM', 'Ford'),
  ('fstrut-l-0609',        '8H6Z-18124-B',  'OEM', 'Ford'),
  ('fstrut-l-0609',        'AST-159',       'OEM', 'Motorcraft'),
  ('fstrut-l-0609',        'AST-160',       'OEM', 'Motorcraft'),
  ('fstrut-l-0609',        'AST-161',       'OEM', 'Motorcraft'),
  ('fstrut-l-0609',        'AST-280',       'OEM', 'Motorcraft'),
  ('fstrut-l-0609',        'AST-336',       'OEM', 'Motorcraft'),
  ('fstrut-l-0609',        'AST-389',       'OEM', 'Motorcraft'),
  ('fstrut-r-0609',        '6E5Z-18124-AR', 'OEM', 'Ford'),
  ('fstrut-r-0609',        '6E5Z-18124-BR', 'OEM', 'Ford'),
  ('fstrut-r-0609',        '8E5Z-18124-R',  'OEM', 'Ford'),
  ('fstrut-r-0609',        '6H6Z-18124-AR', 'OEM', 'Ford'),
  ('fstrut-r-0609',        '7H6Z-18124-RL', 'OEM', 'Ford'),
  ('fstrut-r-0609',        '8H6Z-18124-A',  'OEM', 'Ford'),
  ('fstrut-r-0609',        'AST-162',       'OEM', 'Motorcraft'),
  ('fstrut-r-0609',        'AST-163',       'OEM', 'Motorcraft'),
  ('fstrut-r-0609',        'AST-164',       'OEM', 'Motorcraft'),
  ('fstrut-r-0609',        'AST-279',       'OEM', 'Motorcraft'),
  ('fstrut-r-0609',        'AST-337',       'OEM', 'Motorcraft'),
  ('fstrut-r-0609',        'AST-388',       'OEM', 'Motorcraft'),
  ('fstrut-l-1012',        'AE5Z-18124-B',  'OEM', 'Ford'),
  ('fstrut-l-1012',        'AE5Z-18124-D',  'OEM', 'Ford'),
  ('fstrut-l-1012',        'AE5Z-18124-F',  'OEM', 'Ford'),
  ('fstrut-l-1012',        'AE5Z-18124-H',  'OEM', 'Ford'),
  ('fstrut-l-1012',        'AE5Z-18124-K',  'OEM', 'Ford'),
  ('fstrut-l-1012',        'AH6Z-18124-B',  'OEM', 'Ford'),
  ('fstrut-l-1012',        'AST-421',       'OEM', 'Motorcraft'),
  ('fstrut-l-1012',        'AST-423',       'OEM', 'Motorcraft'),
  ('fstrut-l-1012',        'AST-425',       'OEM', 'Motorcraft'),
  ('fstrut-l-1012',        'AST-427',       'OEM', 'Motorcraft'),
  ('fstrut-l-1012',        'AST-439',       'OEM', 'Motorcraft'),
  ('fstrut-l-1012',        'AST-471',       'OEM', 'Motorcraft'),
  ('fstrut-r-1012',        'AE5Z-18124-A',  'OEM', 'Ford'),
  ('fstrut-r-1012',        'AE5Z-18124-C',  'OEM', 'Ford'),
  ('fstrut-r-1012',        'AE5Z-18124-E',  'OEM', 'Ford'),
  ('fstrut-r-1012',        'AE5Z-18124-G',  'OEM', 'Ford'),
  ('fstrut-r-1012',        'AE5Z-18124-J',  'OEM', 'Ford'),
  ('fstrut-r-1012',        'AH6Z-18124-A',  'OEM', 'Ford'),
  ('fstrut-r-1012',        'AST-420',       'OEM', 'Motorcraft'),
  ('fstrut-r-1012',        'AST-422',       'OEM', 'Motorcraft'),
  ('fstrut-r-1012',        'AST-424',       'OEM', 'Motorcraft'),
  ('fstrut-r-1012',        'AST-426',       'OEM', 'Motorcraft'),
  ('fstrut-r-1012',        'AST-438',       'OEM', 'Motorcraft'),
  ('fstrut-r-1012',        'AST-470',       'OEM', 'Motorcraft'),
  ('fstrut-loaded-l-0809', 'GU2Z-18A092-Z', 'OEM', 'Ford'),
  ('fstrut-loaded-l-0809', 'ASTL-27',       'OEM', 'Motorcraft'),
  ('fstrut-loaded-r-0809', 'GU2Z-18A092-X', 'OEM', 'Ford'),
  ('rshock-cd338',         '6E5Z-18125-AA', 'OEM', 'Ford'),
  ('rshock-cd338',         '7E5Z-18125-A',  'OEM', 'Ford'),
  ('rshock-cd338',         '8E5Z-18125-A',  'OEM', 'Ford'),
  ('rshock-cd338',         'AE5Z-18125-A',  'OEM', 'Ford'),
  ('rshock-cd338',         'AE5Z-18125-B',  'OEM', 'Ford'),
  ('rshock-cd338',         'AE5Z-18125-C',  'OEM', 'Ford'),
  ('rshock-cd338',         'AE5Z-18125-D',  'OEM', 'Ford'),
  ('rshock-cd338',         'AE5Z-18125-E',  'OEM', 'Ford'),
  ('rshock-cd338',         'AE5Z-18125-F',  'OEM', 'Ford'),
  ('rshock-cd338',         'AE5Z-18125-G',  'OEM', 'Ford'),
  ('rshock-cd338',         'AH6Z-18125-A',  'OEM', 'Ford'),
  ('rshock-cd338',         'AH6Z-18125-B',  'OEM', 'Ford'),
  ('rshock-cd338',         '6H6Z-18125-AA', 'OEM', 'Ford'),
  ('rshock-cd338',         '7H6Z-18125-C',  'OEM', 'Ford'),
  ('rshock-cd338',         '7H6Z-18125-D',  'OEM', 'Ford'),
  ('rshock-cd338',         'ASH-420',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'ASH-421',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'ASH-422',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'ASH-423',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'ASH-424',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'ASH-425',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'ASH-431',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'ASH-432',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'ASH-440',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'AST-177',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'AST-179',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'AST-281',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'AST-282',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'AST-283',       'OEM', 'Motorcraft'),
  ('rshock-cd338',         'AST-338',       'OEM', 'Motorcraft'),
  ('strut-mount-damper',   '6E5Z-3F690-A',  'OEM', 'Ford'),
  ('strut-bearing-cd338',  '6E5Z-18198-A',  'OEM', 'Ford'),
  ('lca-rear-l',           '5M8Z-3079-L',   'OEM', 'Ford'),
  ('lca-rear-l',           '6M8Z-3079-L',   'OEM', 'Ford'),
  ('lca-rear-l',           '7E5Z-3079-L',   'OEM', 'Ford'),
  ('lca-rear-l',           'MCSOE-123',     'OEM', 'Motorcraft'),
  ('lca-rear-l',           'MCSOE-139',     'OEM', 'Motorcraft'),
  ('lca-rear-r',           '5M8Z-3078-R',   'OEM', 'Ford'),
  ('lca-rear-r',           '6M8Z-3078-R',   'OEM', 'Ford'),
  ('lca-rear-r',           '7E5Z-3078-RA',  'OEM', 'Ford'),
  ('lca-rear-r',           'MCSOE-93',      'OEM', 'Motorcraft'),
  ('lca-rear-r',           'MCSOE-107',     'OEM', 'Motorcraft'),
  ('lca-forward',          '7E5Z-3078-R',   'OEM', 'Ford'),
  ('lca-forward',          'BE5Z-3078-A',   'OEM', 'Ford'),
  ('lca-forward',          'MCF-8',         'OEM', 'Motorcraft'),
  ('lca-forward',          'MCSOE-40',      'OEM', 'Motorcraft'),
  ('front-bearing-cd338',  'F32Z-1215-A',   'OEM', 'Ford'),
  ('rear-hub-fwd-cd338',   '6E5Z-1104-AA',  'OEM', 'Ford'),
  ('rear-hub-fwd-cd338',   'HUB-128',       'OEM', 'Motorcraft');

INSERT INTO seed_fits (key, year_from, year_to, engine_code, trims, notes) VALUES
  ('fstrut-l-0609',        2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('fstrut-l-0609',        2006, 2009, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('fstrut-r-0609',        2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('fstrut-r-0609',        2006, 2009, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('fstrut-l-1012',        2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('fstrut-l-1012',        2010, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('fstrut-l-1012',        2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('fstrut-l-1012',        2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('fstrut-r-1012',        2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('fstrut-r-1012',        2010, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('fstrut-r-1012',        2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('fstrut-r-1012',        2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('fstrut-loaded-l-0809', 2008, 2009, '2.3 Duratec',      NULL, NULL),
  ('fstrut-loaded-l-0809', 2008, 2009, '3.0 Duratec V6',   NULL, NULL),
  ('fstrut-loaded-r-0809', 2008, 2009, '2.3 Duratec',      NULL, NULL),
  ('fstrut-loaded-r-0809', 2008, 2009, '3.0 Duratec V6',   NULL, NULL),
  ('fstrut-loaded-l-1012', 2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('fstrut-loaded-l-1012', 2010, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('fstrut-loaded-r-1012', 2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('fstrut-loaded-r-1012', 2010, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('fstrut-loaded-l-sh',   2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('fstrut-loaded-l-sh',   2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('fstrut-loaded-r-sh',   2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('fstrut-loaded-r-sh',   2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('rshock-cd338',         2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('rshock-cd338',         2006, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('rshock-cd338',         2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('rshock-cd338',         2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('rshock-cd338',         2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('strut-mount-0608',     2006, 2008, '2.3 Duratec',      NULL, 'MY2008: production split with 8E5Z-18183-A, check by VIN'),
  ('strut-mount-0608',     2006, 2008, '3.0 Duratec V6',   NULL, 'MY2008: production split with 8E5Z-18183-A, check by VIN'),
  ('strut-mount-0812',     2008, 2009, '2.3 Duratec',      NULL, 'MY2008: production split with 6E5Z-18183-B, check by VIN'),
  ('strut-mount-0812',     2008, 2012, '3.0 Duratec V6',   NULL, 'MY2008: production split with 6E5Z-18183-B, check by VIN'),
  ('strut-mount-0812',     2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('strut-mount-0812',     2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('strut-mount-0812',     2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('strut-mount-damper',   2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('strut-mount-damper',   2006, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('strut-mount-damper',   2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('strut-mount-damper',   2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('strut-mount-damper',   2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('strut-bearing-cd338',  2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('strut-bearing-cd338',  2006, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('strut-bearing-cd338',  2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('strut-bearing-cd338',  2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('strut-bearing-cd338',  2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('lca-rear-l',           2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('lca-rear-l',           2006, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('lca-rear-l',           2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('lca-rear-l',           2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('lca-rear-l',           2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('lca-rear-r',           2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('lca-rear-r',           2006, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('lca-rear-r',           2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('lca-rear-r',           2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('lca-rear-r',           2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('lca-forward',          2007, 2009, '2.3 Duratec',      NULL, 'Cars built from 08/2006'),
  ('lca-forward',          2007, 2012, '3.0 Duratec V6',   NULL, 'Cars built from 08/2006; FWD and AWD'),
  ('lca-forward',          2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('lca-forward',          2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('lca-forward',          2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('stab-link-fl-0609',    2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('stab-link-fl-0609',    2006, 2009, '3.0 Duratec V6',   NULL, NULL),
  ('stab-link-fr-0609',    2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('stab-link-fr-0609',    2006, 2009, '3.0 Duratec V6',   NULL, NULL),
  ('stab-link-f-1012',     2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('stab-link-f-1012',     2010, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('stab-link-f-1012',     2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('stab-link-f-1012',     2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('stab-link-rear-cd338', 2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('stab-link-rear-cd338', 2006, 2012, '3.0 Duratec V6',   NULL, 'FWD and AWD'),
  ('stab-link-rear-cd338', 2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('stab-link-rear-cd338', 2010, 2012, '3.5 Duratec V6',   NULL, 'FWD and AWD'),
  ('stab-link-rear-cd338', 2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('front-bearing-cd338',  2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('front-bearing-cd338',  2006, 2012, '3.0 Duratec V6',   NULL, NULL),
  ('front-bearing-cd338',  2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('front-bearing-cd338',  2010, 2012, '3.5 Duratec V6',   NULL, NULL),
  ('front-bearing-cd338',  2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('front-hub-cd338',      2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('front-hub-cd338',      2006, 2012, '3.0 Duratec V6',   NULL, 'Front; also the rear hub flange on AWD cars'),
  ('front-hub-cd338',      2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('front-hub-cd338',      2010, 2012, '3.5 Duratec V6',   NULL, 'Front; also the rear hub flange on AWD cars'),
  ('front-hub-cd338',      2010, 2012, '2.5 Atkinson HEV', NULL, NULL),
  ('rear-hub-fwd-cd338',   2006, 2009, '2.3 Duratec',      NULL, NULL),
  ('rear-hub-fwd-cd338',   2006, 2012, '3.0 Duratec V6',   NULL, 'FWD only'),
  ('rear-hub-fwd-cd338',   2010, 2012, '2.5 Duratec iVCT', NULL, NULL),
  ('rear-hub-fwd-cd338',   2010, 2012, '3.5 Duratec V6',   NULL, 'FWD only'),
  ('rear-hub-fwd-cd338',   2010, 2012, '2.5 Atkinson HEV', NULL, NULL);


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
         WHERE mk.slug = 'ford' AND m.slug = 'fusion' AND g.slug = 'cd338'
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
       'seed-ford-fusion-i-service-parts', 'seed-ford-fusion-i-service-parts'
  FROM seed_new n
  JOIN seed_parts sp ON sp.key = n.key
  JOIN categories c ON c.slug = sp.category_slug;

INSERT INTO part_numbers (part_id, number, type, source, created_by, updated_by)
SELECT n.part_id, sp.oem_key, 'OEM', sp.oem_key_source,
       'seed-ford-fusion-i-service-parts', 'seed-ford-fusion-i-service-parts'
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
       updated_at = now(), updated_by = 'seed-ford-fusion-i-service-parts'
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
       'seed-ford-fusion-i-service-parts', 'seed-ford-fusion-i-service-parts'
  FROM seed_numbers sn
  JOIN seed_part_ids ids ON ids.key = sn.key
ON CONFLICT (number, type, part_id) DO NOTHING;

-- ============================================================
-- Fitments, per variant
-- ============================================================
INSERT INTO fitments (part_id, vehicle_variant_id, position, notes, created_by, updated_by)
SELECT DISTINCT ids.part_id, vv.id, sp.position, sf.notes,
       'seed-ford-fusion-i-service-parts', 'seed-ford-fusion-i-service-parts'
  FROM seed_fits sf
  JOIN seed_parts sp ON sp.key = sf.key
  JOIN seed_part_ids ids ON ids.key = sf.key
  JOIN vehicle_generations g ON g.slug = 'cd338'
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
 WHERE p.created_by = 'seed-ford-fusion-i-service-parts'
 ORDER BY c.slug, p.name_en;

SELECT vv.year, vv.trim, vv.engine_code, count(DISTINCT f.part_id) AS parts
  FROM vehicle_variants vv
  JOIN vehicle_generations g ON g.id = vv.generation_id AND g.slug = 'cd338'
  JOIN vehicle_models m ON m.id = g.model_id AND m.slug = 'fusion'
  LEFT JOIN fitments f ON f.vehicle_variant_id = vv.id
 GROUP BY vv.year, vv.trim, vv.engine_code
 ORDER BY vv.year, vv.engine_code, vv.trim;
SQL
