#!/usr/bin/env bash
# One-off: upload a BMW engine image to MinIO and add the matching
# part + part_number + diagram + callout rows to the local Postgres.
#
# Requires the local infra containers running (autoparts-minio,
# autoparts-postgres) and the V3 migration applied (diagrams table).

set -euo pipefail

IMAGE_SRC="${IMAGE_SRC:-$HOME/Downloads/3lct.png}"
BUCKET="autoparts-local"
OBJECT_KEY="diagrams/bmw-3-2016-engine.png"
PUBLIC_URL="http://localhost:9000/${BUCKET}/${OBJECT_KEY}"

DIAGRAM_SLUG="bmw-3-2016-engine"
PART_NAME="N20 2000 engine N47D20D"
PART_NUMBER="11002223006"
CALLOUT_X=655
CALLOUT_Y=215
IMG_W=950
IMG_H=665

if [[ ! -f "$IMAGE_SRC" ]]; then
  echo "Image not found: $IMAGE_SRC" >&2
  exit 1
fi

echo "1/3  Uploading image to MinIO ($PUBLIC_URL) ..."
docker cp "$IMAGE_SRC" autoparts-minio:/tmp/diagram-engine.png >/dev/null
docker exec autoparts-minio sh -c '
  set -e
  mc alias set local http://localhost:9000 minioadmin minioadmin >/dev/null
  mc mb --ignore-existing local/autoparts-local >/dev/null
  mc anonymous set download local/autoparts-local >/dev/null
  mc cp /tmp/diagram-engine.png local/autoparts-local/diagrams/bmw-3-2016-engine.png >/dev/null
'
echo "     ok"

echo "2/3  Verifying engine category and BMW 2016 variant exist ..."
docker exec -i autoparts-postgres psql -U autoparts -d autoparts -v ON_ERROR_STOP=1 -tA <<'SQL' >/dev/null
SELECT 1 FROM categories WHERE slug = 'engine';
SELECT 1 FROM vehicle_variants vv
  JOIN vehicle_models vm ON vm.id = vv.model_id
 WHERE vm.slug = '3-series' AND vv.year = 2016
 LIMIT 1;
SQL
echo "     ok"

echo "3/3  Inserting part, part_number, diagram, callout ..."
docker exec -i autoparts-postgres psql -U autoparts -d autoparts -v ON_ERROR_STOP=1 <<SQL
WITH eng AS (
  SELECT id FROM categories WHERE slug = 'engine'
),
variant AS (
  SELECT vv.id FROM vehicle_variants vv
    JOIN vehicle_models vm ON vm.id = vv.model_id
   WHERE vm.slug = '3-series' AND vv.year = 2016
   LIMIT 1
),
new_part AS (
  INSERT INTO parts (category_id, name_az, name_ru, name_en, brand)
  SELECT eng.id, '${PART_NAME}', '${PART_NAME}', '${PART_NAME}', 'BMW'
    FROM eng
  RETURNING id
),
ins_pn AS (
  INSERT INTO part_numbers (part_id, number, type, source)
  SELECT id, '${PART_NUMBER}', 'OEM', 'BMW' FROM new_part
  RETURNING part_id
),
new_diagram AS (
  INSERT INTO diagrams (slug, title_az, title_ru, title_en, image_url, image_width, image_height, category_id, vehicle_variant_id)
  SELECT '${DIAGRAM_SLUG}',
         '${PART_NAME}', '${PART_NAME}', '${PART_NAME}',
         '${PUBLIC_URL}',
         ${IMG_W}, ${IMG_H},
         eng.id, variant.id
    FROM eng, variant
  RETURNING id
)
INSERT INTO diagram_callouts (diagram_id, part_id, label, x, y, z_order)
SELECT d.id, p.id, '1', ${CALLOUT_X}, ${CALLOUT_Y}, 0
  FROM new_diagram d, new_part p;
SQL
echo "     ok"

echo
echo "Done."
echo "  Image:   $PUBLIC_URL"
echo "  API:     http://localhost:8080/api/v1/catalog/diagrams/${DIAGRAM_SLUG}"
echo "  Web:     http://localhost:5173/d/${DIAGRAM_SLUG}"
