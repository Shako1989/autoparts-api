#!/usr/bin/env bash
# Seed: the canonical category tree, az / ru / en. 11 roots, 75 leaves.
#
# Why: prod had four placeholder roots (engine, exhaust-system, radiator,
# front-axle) and the local dev seed (DevSeedService) its own five. A part
# attaches to exactly one category and the category page lists only that
# category's parts (no roll-up to the parent), so every part type needs a leaf
# and the roots are navigation only. Roots follow TODO.md task 3; leaves cover
# the service parts of tasks 4-5 and the body / lighting parts of task 6, plus
# the categories Baku sellers list most.
#
# Rules
# - Upsert by slug. A row that already exists keeps its id, and with it its
#   parts, diagrams and listings; it gets the canonical parent, names and sort
#   order. Nothing is deleted.
# - Existing slugs are reused on purpose so local and prod converge on one
#   tree: `engine` and `exhaust-system` stay roots; prod's `radiator`
#   (singular, kept) becomes a leaf of `cooling`; `front-axle` becomes a leaf
#   of `suspension`; the dev-seed roots `brakes`, `suspension`, `electrical`,
#   `body` and leaves such as `brake-pads`, `oil-filters`, `spark-plugs`,
#   `timing-belts` are adopted and, where needed, re-parented (oil / air
#   filters and spark plugs move from Engine to Maintenance).
# - The DO UPDATE only fires when something differs, so a second run reports
#   INSERT 0 0 for both statements.
# - Azerbaijani uses the formal term, with the Baku workshop word in brackets
#   where people search by it (rıçaqlar, stupitsa, podushka, pompa, başok,
#   stoplar, televizor). Review the az column before running on prod.
# - Icons: icon_url is left NULL; the web app maps slugs to lucide icons in
#   src/components/catalog/CategoryIcon.tsx, so new slugs need a case there.
#
# Run:  ./scripts/seed-category-tree.sh
#       CONTAINER=autoparts-postgres ./scripts/seed-category-tree.sh
# Prod: print the heredoc body and run it from a DB client (seed-only change, no VM rebuild):
#   awk '/^docker exec/{f=1;next} /^SQL$/{f=0} f' scripts/seed-category-tree.sh > ~/Downloads/seed-category-tree.sql

set -euo pipefail

CONTAINER="${CONTAINER:-autoparts-postgres}"

docker exec -i "$CONTAINER" psql -U autoparts -d autoparts -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

-- ============================================================
-- Roots (11). parent_id is forced to NULL so an adopted slug is a root.
-- ============================================================
INSERT INTO categories (slug, parent_id, name_az, name_ru, name_en, sort_order, created_by, updated_by)
VALUES
    ('maintenance',    NULL, 'Texniki xidmət',           'Техобслуживание',               'Maintenance',            10, 'seed-category-tree', 'seed-category-tree'),
    ('brakes',         NULL, 'Əyləc sistemi',            'Тормозная система',             'Brakes',                 20, 'seed-category-tree', 'seed-category-tree'),
    ('suspension',     NULL, 'Asqı və sükan',            'Подвеска и рулевое управление', 'Suspension & steering',  30, 'seed-category-tree', 'seed-category-tree'),
    ('engine',         NULL, 'Mühərrik',                 'Двигатель',                     'Engine',                 40, 'seed-category-tree', 'seed-category-tree'),
    ('cooling',        NULL, 'Soyutma sistemi',          'Система охлаждения',            'Cooling',                50, 'seed-category-tree', 'seed-category-tree'),
    ('electrical',     NULL, 'Elektrik və işıqlandırma', 'Электрика и освещение',         'Electrical & lighting',  60, 'seed-category-tree', 'seed-category-tree'),
    ('body',           NULL, 'Kuzov',                    'Кузов',                         'Body',                   70, 'seed-category-tree', 'seed-category-tree'),
    ('interior',       NULL, 'Salon',                    'Салон',                         'Interior',               80, 'seed-category-tree', 'seed-category-tree'),
    ('transmission',   NULL, 'Transmissiya',             'Трансмиссия',                   'Transmission',           90, 'seed-category-tree', 'seed-category-tree'),
    ('exhaust-system', NULL, 'Egzoz sistemi',            'Выхлопная система',             'Exhaust',               100, 'seed-category-tree', 'seed-category-tree'),
    ('hvac',           NULL, 'Kondisioner və isitmə',    'Кондиционер и отопление',       'Heating & A/C',         110, 'seed-category-tree', 'seed-category-tree')
ON CONFLICT (slug) DO UPDATE
   SET parent_id  = NULL,
       name_az    = EXCLUDED.name_az,
       name_ru    = EXCLUDED.name_ru,
       name_en    = EXCLUDED.name_en,
       sort_order = EXCLUDED.sort_order,
       updated_at = now(),
       updated_by = EXCLUDED.updated_by
 WHERE categories.parent_id IS NOT NULL
    OR (categories.name_az, categories.name_ru, categories.name_en, categories.sort_order)
       IS DISTINCT FROM (EXCLUDED.name_az, EXCLUDED.name_ru, EXCLUDED.name_en, EXCLUDED.sort_order);

-- ============================================================
-- Leaves (75), attached to the roots above by slug.
-- ============================================================
INSERT INTO categories (slug, parent_id, name_az, name_ru, name_en, sort_order, created_by, updated_by)
SELECT v.slug, p.id, v.name_az, v.name_ru, v.name_en, v.sort_order, 'seed-category-tree', 'seed-category-tree'
  FROM (VALUES
    -- Maintenance: the service items of tasks 4-5
    ('maintenance',    'oil-filters',              10, 'Yağ filtrləri',                                 'Масляные фильтры',                              'Oil filters'),
    ('maintenance',    'air-filters',              20, 'Hava filtrləri',                                'Воздушные фильтры',                             'Air filters'),
    ('maintenance',    'cabin-filters',            30, 'Salon filtrləri',                               'Салонные фильтры',                              'Cabin filters'),
    ('maintenance',    'fuel-filters',             40, 'Yanacaq filtrləri',                             'Топливные фильтры',                             'Fuel filters'),
    ('maintenance',    'spark-plugs',              50, 'Alışdırma şamları',                             'Свечи зажигания',                               'Spark plugs'),
    ('maintenance',    'drive-belts',              60, 'Qayışlar və dartıcılar',                        'Приводные ремни и ролики',                      'Drive belts & tensioners'),
    ('maintenance',    'wiper-blades',             70, 'Şüşəsilən fırçaları',                           'Щётки стеклоочистителя',                        'Wiper blades'),
    ('maintenance',    'engine-oil',               80, 'Mühərrik yağı',                                 'Моторное масло',                                'Engine oil'),
    ('maintenance',    'fluids',                   90, 'Texniki mayelər (antifriz, əyləc mayesi, ATF)', 'Технические жидкости (антифриз, тормозная, ATF)', 'Fluids (coolant, brake fluid, ATF)'),
    -- Brakes
    ('brakes',         'brake-pads',               10, 'Əyləc kolodkaları',                             'Тормозные колодки',                             'Brake pads'),
    ('brakes',         'brake-discs',              20, 'Əyləc diskləri',                                'Тормозные диски',                               'Brake discs'),
    ('brakes',         'brake-calipers',           30, 'Əyləc supportları',                             'Тормозные суппорты',                            'Brake calipers'),
    ('brakes',         'brake-hoses',              40, 'Əyləc şlanqları və boruları',                   'Тормозные шланги и трубки',                     'Brake hoses & lines'),
    ('brakes',         'abs-sensors',              50, 'ABS sensorları',                                'Датчики ABS',                                   'ABS sensors'),
    ('brakes',         'parking-brake',            60, 'Dayanacaq əyləci',                              'Стояночный тормоз',                             'Parking brake'),
    -- Suspension & steering
    ('suspension',     'shock-absorbers',          10, 'Amortizatorlar',                                'Амортизаторы и стойки',                         'Shocks & struts'),
    ('suspension',     'strut-mounts',             20, 'Amortizator dayaqları və yastıqları',           'Опоры и подшипники стоек',                      'Strut mounts & bearings'),
    ('suspension',     'control-arms',             30, 'Asqı qolları (rıçaqlar)',                       'Рычаги подвески',                               'Control arms'),
    ('suspension',     'ball-joints',              40, 'Şar dayaqları',                                 'Шаровые опоры',                                 'Ball joints'),
    ('suspension',     'stabilizer-links',         50, 'Stabilizator dartqıları və vtulkaları',         'Стойки и втулки стабилизатора',                 'Stabilizer links & bushings'),
    ('suspension',     'suspension-bushings',      60, 'Saylentbloklar və vtulkalar',                   'Сайлентблоки и втулки',                         'Bushings'),
    ('suspension',     'wheel-bearings',           70, 'Təkər podşipnikləri (stupitsa)',                'Ступичные подшипники и ступицы',                'Wheel bearings & hubs'),
    ('suspension',     'tie-rods',                 80, 'Sükan dartqıları və ucluqları',                 'Рулевые тяги и наконечники',                    'Tie rods & ends'),
    ('suspension',     'steering-racks',           90, 'Sükan reykaları və nasosları',                  'Рулевые рейки и насосы',                        'Steering racks & pumps'),
    ('suspension',     'front-axle',              100, 'Ön ox',                                         'Передняя ось',                                  'Front axle'),
    -- Engine
    ('engine',         'ignition-coils',           10, 'Alışdırma bobinləri',                           'Катушки зажигания',                             'Ignition coils'),
    ('engine',         'engine-mounts',            20, 'Mühərrik dayaqları (podushka)',                 'Опоры (подушки) двигателя',                     'Engine mounts'),
    ('engine',         'timing-belts',             30, 'Qazpaylama (GRM) qayışları və zəncirləri',      'Ремни и цепи ГРМ',                              'Timing belts, chains & kits'),
    ('engine',         'gaskets-seals',            40, 'Araqatlar və salniklər',                        'Прокладки и сальники',                          'Gaskets & seals'),
    ('engine',         'fuel-system',              50, 'Yanacaq nasosları və forsunkalar',              'Топливные насосы и форсунки',                   'Fuel pumps & injectors'),
    ('engine',         'turbochargers',            60, 'Turbinlər',                                     'Турбины',                                       'Turbochargers'),
    ('engine',         'engine-sensors',           70, 'Mühərrik sensorları',                           'Датчики двигателя',                             'Engine sensors'),
    ('engine',         'intake',                   80, 'Hava qəbulu və drossel qapaqları',              'Впуск и дроссельные заслонки',                  'Intake & throttle bodies'),
    -- Cooling
    ('cooling',        'radiator',                 10, 'Radiatorlar',                                   'Радиаторы',                                     'Radiators'),
    ('cooling',        'water-pumps',              20, 'Su nasosları (pompa)',                          'Водяные насосы (помпы)',                        'Water pumps'),
    ('cooling',        'thermostats',              30, 'Termostatlar və korpusları',                    'Термостаты и корпуса',                          'Thermostats & housings'),
    ('cooling',        'radiator-fans',            40, 'Radiator ventilyatorları',                      'Вентиляторы радиатора',                         'Radiator fans'),
    ('cooling',        'coolant-hoses',            50, 'Soyutma şlanqları və boruları',                 'Патрубки и трубки охлаждения',                  'Coolant hoses & pipes'),
    ('cooling',        'expansion-tanks',          60, 'Genişlənmə çənləri (başok)',                    'Расширительные бачки',                          'Expansion tanks'),
    ('cooling',        'intercoolers',             70, 'İnterkulerlər',                                 'Интеркулеры',                                   'Intercoolers'),
    -- Electrical & lighting
    ('electrical',     'batteries',                10, 'Akkumulyatorlar',                               'Аккумуляторы',                                  'Batteries'),
    ('electrical',     'alternators',              20, 'Generatorlar',                                  'Генераторы',                                    'Alternators'),
    ('electrical',     'starters',                 30, 'Starterlər',                                    'Стартеры',                                      'Starter motors'),
    ('electrical',     'headlights',               40, 'Faralar',                                       'Фары',                                          'Headlights'),
    ('electrical',     'tail-lights',              50, 'Arxa fənərlər (stoplar)',                       'Задние фонари',                                 'Tail lights'),
    ('electrical',     'fog-lights',               60, 'Duman faraları',                                'Противотуманные фары',                          'Fog lights'),
    ('electrical',     'bulbs',                    70, 'Lampalar',                                      'Лампы',                                         'Bulbs & LEDs'),
    ('electrical',     'parking-sensors',          80, 'Park sensorları və kameralar',                  'Парктроники и камеры',                          'Parking sensors & cameras'),
    -- Body
    ('body',           'bumpers',                  10, 'Bamperlər',                                     'Бамперы',                                       'Bumpers'),
    ('body',           'fenders',                  20, 'Qanadlar',                                      'Крылья',                                        'Fenders'),
    ('body',           'hoods',                    30, 'Kapotlar',                                      'Капоты',                                        'Hoods'),
    ('body',           'grilles',                  40, 'Radiator barmaqlıqları',                        'Решётки радиатора',                             'Grilles'),
    ('body',           'mirrors',                  50, 'Yan güzgülər',                                  'Боковые зеркала',                               'Side mirrors'),
    ('body',           'doors',                    60, 'Qapılar',                                       'Двери',                                         'Doors'),
    ('body',           'door-handles-locks',       70, 'Qapı dəstəkləri və kilidləri',                  'Ручки и замки дверей',                          'Door handles & locks'),
    ('body',           'trunk-lids',               80, 'Baqaj qapıları',                                'Крышки багажника',                              'Trunk lids'),
    ('body',           'radiator-supports',        90, 'Radiator panelləri (televizor)',                'Панели радиатора (телевизор)',                  'Radiator supports'),
    ('body',           'glass',                   100, 'Şüşələr',                                       'Стёкла',                                        'Glass & windshields'),
    -- Interior
    ('interior',       'seats',                    10, 'Oturacaqlar',                                   'Сиденья',                                       'Seats'),
    ('interior',       'dashboard',                20, 'Torpedo və salon bəzəkləri',                    'Торпедо и отделка салона',                      'Dashboard & trim'),
    ('interior',       'infotainment',             30, 'Multimedia və ekranlar',                        'Мультимедиа и дисплеи',                         'Infotainment & displays'),
    -- Transmission
    ('transmission',   'transmission-filters',     10, 'Transmissiya filtrləri və poddonları',          'Фильтры и поддоны АКПП',                        'Transmission filters & pans'),
    ('transmission',   'transmission-mounts',      20, 'Transmissiya dayaqları',                        'Опоры КПП',                                     'Transmission mounts'),
    ('transmission',   'cv-axles',                 30, 'Yarımoxlar və ŞRUS-lar',                        'Приводы и ШРУСы',                               'CV axles & joints'),
    ('transmission',   'clutches',                 40, 'İlişmə muftaları',                              'Сцепление',                                     'Clutch kits'),
    ('transmission',   'transmission-solenoids',   50, 'Solenoidlər və klapan blokları',                'Соленоиды и гидроблоки',                        'Solenoids & valve bodies'),
    -- Exhaust
    ('exhaust-system', 'mufflers',                 10, 'Səsboğanlar və borular',                        'Глушители и трубы',                             'Mufflers & pipes'),
    ('exhaust-system', 'catalytic-converters',     20, 'Katalizatorlar',                                'Катализаторы',                                  'Catalytic converters'),
    ('exhaust-system', 'exhaust-manifolds',        30, 'Egzoz kollektorları',                           'Выпускные коллекторы',                          'Exhaust manifolds'),
    ('exhaust-system', 'oxygen-sensors',           40, 'Lambda-zondlar (O2 sensorları)',                'Лямбда-зонды',                                  'Oxygen sensors'),
    -- Heating & A/C
    ('hvac',           'ac-compressors',           10, 'Kondisioner kompressorları',                    'Компрессоры кондиционера',                      'A/C compressors'),
    ('hvac',           'condensers',               20, 'Kondisioner radiatorları',                      'Радиаторы кондиционера',                        'A/C condensers'),
    ('hvac',           'evaporators-heater-cores', 30, 'Buxarlandırıcılar və peç radiatorları',         'Испарители и радиаторы печки',                  'Evaporators & heater cores'),
    ('hvac',           'blower-motors',            40, 'Peç motorları və rezistorları',                 'Моторы печки и резисторы',                      'Blower motors & resistors'),
    ('hvac',           'hvac-controls',            50, 'İqlim idarəetmə blokları və aktuatorlar',       'Блоки климата и актуаторы',                     'Climate controls & actuators')
  ) AS v(parent_slug, slug, sort_order, name_az, name_ru, name_en)
  JOIN categories p ON p.slug = v.parent_slug
ON CONFLICT (slug) DO UPDATE
   SET parent_id  = EXCLUDED.parent_id,
       name_az    = EXCLUDED.name_az,
       name_ru    = EXCLUDED.name_ru,
       name_en    = EXCLUDED.name_en,
       sort_order = EXCLUDED.sort_order,
       updated_at = now(),
       updated_by = EXCLUDED.updated_by
 WHERE (categories.parent_id, categories.name_az, categories.name_ru, categories.name_en, categories.sort_order)
       IS DISTINCT FROM (EXCLUDED.parent_id, EXCLUDED.name_az, EXCLUDED.name_ru, EXCLUDED.name_en, EXCLUDED.sort_order);

COMMIT;

-- Verify: roots in display order with their leaf counts.
SELECT r.sort_order AS ord, r.slug AS root, r.name_az, r.name_ru, r.name_en, count(c.id) AS leaves
  FROM categories r
  LEFT JOIN categories c ON c.parent_id = r.id
 WHERE r.parent_id IS NULL
 GROUP BY r.id
 ORDER BY r.sort_order, r.slug;

-- Verify: rows the seed neither created nor adopted (expected: only hand-made data).
SELECT c.slug, p.slug AS parent, c.name_en
  FROM categories c
  LEFT JOIN categories p ON p.id = c.parent_id
 WHERE 'seed-category-tree' NOT IN (coalesce(c.created_by, ''), coalesce(c.updated_by, ''))
 ORDER BY 2 NULLS FIRST, 1;
SQL
