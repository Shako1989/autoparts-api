-- V7: introduce vehicle_generations between models and variants.
--
-- Why: the BMW 3 Series ran as both E46 (1998–2006) and E90 (2005–2011) in 2005–2006.
-- A user picking "BMW 3 Series, 2006" today cannot tell us whether they own an E46
-- or an E90 — and the engine bay, electronics and fitment parts differ entirely.
-- Without a generation layer the catalog cannot represent this correctly.
--
-- This migration is non-destructive at the row level: every existing variant gets
-- bound to a single default generation for its model. The picker can then evolve
-- to show the generation step (auto-skipped while there's only one), and admins
-- can later split a model into multiple generations without touching variants.

CREATE TABLE vehicle_generations (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    model_id     UUID         NOT NULL REFERENCES vehicle_models(id) ON DELETE CASCADE,
    -- Manufacturer's chassis/generation code (E90, F30, Mk7, etc.). Optional —
    -- not all marques publish one, especially for budget brands.
    code         VARCHAR(40),
    -- Display name. Defaults to the model name during backfill; admins rename
    -- when they split into multiple generations ("3 Series E90", "3 Series F30").
    name         VARCHAR(120) NOT NULL,
    slug         VARCHAR(120) NOT NULL,
    year_from    SMALLINT     NOT NULL,
    year_to      SMALLINT,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by   VARCHAR(80),
    updated_by   VARCHAR(80),
    CONSTRAINT uq_vehicle_generations_model_slug UNIQUE (model_id, slug)
);
CREATE INDEX idx_vehicle_generations_model ON vehicle_generations(model_id);

-- Backfill: one default generation per existing model, mirroring its year range.
-- Slug 'gen' is a placeholder; admins rename when splitting (e.g. 'e90', 'f30').
INSERT INTO vehicle_generations (
    id, model_id, code, name, slug, year_from, year_to,
    created_at, updated_at, created_by, updated_by
)
SELECT
    gen_random_uuid(),
    m.id,
    NULL,
    m.name,
    'gen',
    m.year_from,
    m.year_to,
    now(),
    now(),
    'migration-v7',
    'migration-v7'
FROM vehicle_models m;

-- Add generation_id to variants, backfill it from the default generation per
-- model, then enforce NOT NULL and drop the old model_id column.
ALTER TABLE vehicle_variants ADD COLUMN generation_id UUID REFERENCES vehicle_generations(id) ON DELETE CASCADE;

UPDATE vehicle_variants v
SET generation_id = g.id
FROM vehicle_generations g
WHERE g.model_id = v.model_id;

ALTER TABLE vehicle_variants ALTER COLUMN generation_id SET NOT NULL;

-- The old uniqueness constraint included model_id; swap to generation_id.
ALTER TABLE vehicle_variants DROP CONSTRAINT uq_vehicle_variants;
ALTER TABLE vehicle_variants ADD CONSTRAINT uq_vehicle_variants
    UNIQUE (generation_id, year, trim, engine_code);

ALTER TABLE vehicle_variants DROP COLUMN model_id;

CREATE INDEX idx_vehicle_variants_generation ON vehicle_variants(generation_id);
