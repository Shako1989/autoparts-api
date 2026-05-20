-- Align listings.currency column type with the JPA entity (String → VARCHAR).
-- V4 originally created it as CHAR(3); Hibernate schema validation rejects bpchar.

ALTER TABLE listings ALTER COLUMN currency TYPE VARCHAR(3);
