-- AutoParts.az schema baseline.
-- Module-specific tables (identity, catalog, listings, ...) start at V2 and beyond.
-- This baseline only enables the extensions every module will need.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- for gen_random_uuid()
