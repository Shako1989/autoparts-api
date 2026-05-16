-- AutoParts.az diagrams: exploded-view images with numbered callouts that link to parts.

CREATE TABLE diagrams (
    id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    slug                VARCHAR(160) NOT NULL UNIQUE,
    title_az            VARCHAR(255) NOT NULL,
    title_ru            VARCHAR(255) NOT NULL,
    title_en            VARCHAR(255) NOT NULL,
    image_url           VARCHAR(512) NOT NULL,
    image_width         INT          NOT NULL,
    image_height        INT          NOT NULL,
    category_id         UUID         REFERENCES categories(id) ON DELETE RESTRICT,
    vehicle_variant_id  UUID         REFERENCES vehicle_variants(id) ON DELETE RESTRICT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by          VARCHAR(80),
    updated_by          VARCHAR(80),
    CONSTRAINT ck_diagrams_image_size CHECK (image_width > 0 AND image_height > 0),
    CONSTRAINT ck_diagrams_scope CHECK (category_id IS NOT NULL OR vehicle_variant_id IS NOT NULL)
);
CREATE INDEX ix_diagrams_category ON diagrams (category_id);
CREATE INDEX ix_diagrams_variant  ON diagrams (vehicle_variant_id);

CREATE TABLE diagram_callouts (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    diagram_id   UUID         NOT NULL REFERENCES diagrams(id) ON DELETE CASCADE,
    part_id      UUID         NOT NULL REFERENCES parts(id) ON DELETE RESTRICT,
    label        VARCHAR(20)  NOT NULL,
    x            INT          NOT NULL,
    y            INT          NOT NULL,
    w            INT,
    h            INT,
    z_order      INT          NOT NULL DEFAULT 0,
    notes        VARCHAR(255),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by   VARCHAR(80),
    updated_by   VARCHAR(80),
    CONSTRAINT uq_diagram_callouts_label UNIQUE (diagram_id, label),
    CONSTRAINT ck_diagram_callouts_xy   CHECK (x >= 0 AND y >= 0),
    CONSTRAINT ck_diagram_callouts_size CHECK (
        (w IS NULL AND h IS NULL) OR (w > 0 AND h > 0)
    )
);
CREATE INDEX ix_diagram_callouts_diagram ON diagram_callouts (diagram_id);
CREATE INDEX ix_diagram_callouts_part    ON diagram_callouts (part_id);
