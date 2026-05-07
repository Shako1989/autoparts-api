-- AutoParts.az catalog schema (vehicles, categories, parts, fitments).
-- See brief §4 for column-level rationale.

CREATE TABLE vehicle_makes (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name         VARCHAR(80)  NOT NULL UNIQUE,
    slug         VARCHAR(80)  NOT NULL UNIQUE,
    logo_url     VARCHAR(255),
    popularity   INT          NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by   VARCHAR(80),
    updated_by   VARCHAR(80)
);
CREATE INDEX ix_vehicle_makes_popularity ON vehicle_makes (popularity DESC);

CREATE TABLE vehicle_models (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    make_id      UUID         NOT NULL REFERENCES vehicle_makes(id) ON DELETE CASCADE,
    name         VARCHAR(120) NOT NULL,
    slug         VARCHAR(120) NOT NULL,
    year_from    SMALLINT     NOT NULL,
    year_to      SMALLINT,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by   VARCHAR(80),
    updated_by   VARCHAR(80),
    CONSTRAINT uq_vehicle_models_make_slug UNIQUE (make_id, slug)
);
CREATE INDEX ix_vehicle_models_make ON vehicle_models (make_id);

CREATE TABLE vehicle_variants (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    model_id     UUID         NOT NULL REFERENCES vehicle_models(id) ON DELETE CASCADE,
    year         SMALLINT     NOT NULL,
    trim         VARCHAR(120),
    engine_code  VARCHAR(60),
    body_type    VARCHAR(40),
    fuel         VARCHAR(20),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by   VARCHAR(80),
    updated_by   VARCHAR(80),
    CONSTRAINT uq_vehicle_variants UNIQUE (model_id, year, trim, engine_code)
);
CREATE INDEX ix_vehicle_variants_model_year ON vehicle_variants (model_id, year);

CREATE TABLE categories (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id    UUID         REFERENCES categories(id) ON DELETE RESTRICT,
    slug         VARCHAR(120) NOT NULL UNIQUE,
    name_az      VARCHAR(160) NOT NULL,
    name_ru      VARCHAR(160) NOT NULL,
    name_en      VARCHAR(160) NOT NULL,
    icon_url     VARCHAR(255),
    sort_order   INT          NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by   VARCHAR(80),
    updated_by   VARCHAR(80)
);
CREATE INDEX ix_categories_parent_sort ON categories (parent_id, sort_order);

CREATE TABLE parts (
    id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id        UUID         NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    name_az            VARCHAR(255) NOT NULL,
    name_ru            VARCHAR(255) NOT NULL,
    name_en            VARCHAR(255) NOT NULL,
    brand              VARCHAR(120),
    description        TEXT,
    default_image_url  VARCHAR(255),
    deleted_at         TIMESTAMPTZ,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by         VARCHAR(80),
    updated_by         VARCHAR(80)
);
CREATE INDEX ix_parts_category ON parts (category_id);
CREATE INDEX ix_parts_brand ON parts (brand);

CREATE TABLE part_numbers (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    part_id      UUID         NOT NULL REFERENCES parts(id) ON DELETE CASCADE,
    number       VARCHAR(80)  NOT NULL,
    type         VARCHAR(20)  NOT NULL,
    source       VARCHAR(80),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by   VARCHAR(80),
    updated_by   VARCHAR(80),
    CONSTRAINT uq_part_numbers UNIQUE (number, type, part_id),
    CONSTRAINT ck_part_numbers_type CHECK (type IN ('OEM', 'AFTERMARKET'))
);
CREATE INDEX ix_part_numbers_number ON part_numbers (number);
CREATE INDEX ix_part_numbers_part ON part_numbers (part_id);

CREATE TABLE cross_references (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    number_a     VARCHAR(80)  NOT NULL,
    number_b     VARCHAR(80)  NOT NULL,
    source       VARCHAR(80),
    confidence   SMALLINT     NOT NULL DEFAULT 100,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by   VARCHAR(80),
    updated_by   VARCHAR(80),
    CONSTRAINT ck_cross_refs_confidence CHECK (confidence BETWEEN 0 AND 100),
    CONSTRAINT ck_cross_refs_distinct CHECK (number_a <> number_b)
);
CREATE INDEX ix_cross_refs_a ON cross_references (number_a);
CREATE INDEX ix_cross_refs_b ON cross_references (number_b);

CREATE TABLE fitments (
    id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    part_id             UUID         NOT NULL REFERENCES parts(id) ON DELETE CASCADE,
    vehicle_variant_id  UUID         NOT NULL REFERENCES vehicle_variants(id) ON DELETE CASCADE,
    position            VARCHAR(40),
    notes               VARCHAR(255),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by          VARCHAR(80),
    updated_by          VARCHAR(80),
    CONSTRAINT uq_fitments UNIQUE (part_id, vehicle_variant_id, position)
);
CREATE INDEX ix_fitments_part ON fitments (part_id);
CREATE INDEX ix_fitments_variant ON fitments (vehicle_variant_id);
