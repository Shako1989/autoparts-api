-- AutoParts.az marketplace v1: identity (users + seller profiles + OTP) and listings.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX ix_parts_name_az_trgm ON parts USING GIN (name_az gin_trgm_ops) WHERE deleted_at IS NULL;
CREATE INDEX ix_parts_name_ru_trgm ON parts USING GIN (name_ru gin_trgm_ops) WHERE deleted_at IS NULL;
CREATE INDEX ix_parts_name_en_trgm ON parts USING GIN (name_en gin_trgm_ops) WHERE deleted_at IS NULL;
CREATE INDEX ix_part_numbers_number_trgm ON part_numbers USING GIN (number gin_trgm_ops);

CREATE TABLE users (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    phone           VARCHAR(20)  NOT NULL UNIQUE,
    full_name       VARCHAR(160),
    role            VARCHAR(20)  NOT NULL DEFAULT 'BUYER',
    enabled         BOOLEAN      NOT NULL DEFAULT TRUE,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by      VARCHAR(80),
    updated_by      VARCHAR(80),
    CONSTRAINT ck_users_role CHECK (role IN ('BUYER','SELLER','STAFF','ADMIN')),
    CONSTRAINT ck_users_phone_e164 CHECK (phone ~ '^\+[1-9][0-9]{6,18}$')
);
CREATE INDEX ix_users_role ON users (role);

CREATE TABLE seller_profiles (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID         NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    display_name    VARCHAR(160) NOT NULL,
    legal_name      VARCHAR(255),
    tax_id          VARCHAR(40),
    city            VARCHAR(80),
    address         TEXT,
    contact_phone   VARCHAR(20),
    whatsapp        VARCHAR(20),
    bio             TEXT,
    kyc_status      VARCHAR(20)  NOT NULL DEFAULT 'UNVERIFIED',
    rating_avg      NUMERIC(3,2) NOT NULL DEFAULT 0,
    rating_count    INT          NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by      VARCHAR(80),
    updated_by      VARCHAR(80),
    CONSTRAINT ck_seller_profiles_kyc CHECK (kyc_status IN ('UNVERIFIED','PENDING','VERIFIED','REJECTED')),
    CONSTRAINT ck_seller_profiles_rating_avg CHECK (rating_avg BETWEEN 0 AND 5),
    CONSTRAINT ck_seller_profiles_rating_count CHECK (rating_count >= 0)
);

CREATE TABLE listings (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id       UUID         NOT NULL REFERENCES seller_profiles(id) ON DELETE RESTRICT,
    part_id         UUID         NOT NULL REFERENCES parts(id) ON DELETE RESTRICT,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    condition       VARCHAR(20)  NOT NULL,
    price_minor     BIGINT       NOT NULL,
    currency        CHAR(3)      NOT NULL DEFAULT 'AZN',
    quantity        INT          NOT NULL DEFAULT 1,
    status          VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    city            VARCHAR(80),
    published_at    TIMESTAMPTZ,
    archived_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by      VARCHAR(80),
    updated_by      VARCHAR(80),
    CONSTRAINT ck_listings_condition CHECK (condition IN ('NEW','USED','REFURBISHED')),
    CONSTRAINT ck_listings_status CHECK (status IN ('DRAFT','ACTIVE','PAUSED','SOLD','ARCHIVED')),
    CONSTRAINT ck_listings_price_positive CHECK (price_minor > 0),
    CONSTRAINT ck_listings_quantity CHECK (quantity >= 0),
    CONSTRAINT ck_listings_currency CHECK (currency ~ '^[A-Z]{3}$')
);
CREATE INDEX ix_listings_part_active ON listings (part_id) WHERE status = 'ACTIVE';
CREATE INDEX ix_listings_seller_status ON listings (seller_id, status);
CREATE INDEX ix_listings_status_published ON listings (status, published_at DESC);

CREATE TABLE listing_photos (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id      UUID         NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    url             VARCHAR(512) NOT NULL,
    s3_key          VARCHAR(255) NOT NULL,
    position        INT          NOT NULL DEFAULT 0,
    width           INT,
    height          INT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by      VARCHAR(80),
    updated_by      VARCHAR(80),
    CONSTRAINT uq_listing_photos_position UNIQUE (listing_id, position),
    CONSTRAINT ck_listing_photos_position CHECK (position >= 0)
);
CREATE INDEX ix_listing_photos_listing ON listing_photos (listing_id, position);

CREATE TABLE otp_codes (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    phone           VARCHAR(20)  NOT NULL,
    code_hash       VARCHAR(255) NOT NULL,
    purpose         VARCHAR(20)  NOT NULL,
    expires_at      TIMESTAMPTZ  NOT NULL,
    consumed_at     TIMESTAMPTZ,
    attempts        SMALLINT     NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_otp_codes_purpose CHECK (purpose IN ('LOGIN','REGISTER')),
    CONSTRAINT ck_otp_codes_attempts CHECK (attempts >= 0)
);
CREATE INDEX ix_otp_codes_phone_active ON otp_codes (phone, expires_at DESC) WHERE consumed_at IS NULL;
