-- V6 created token_hash as CHAR(64), while the JPA mapping uses VARCHAR(64).
-- MODIFY preserves all existing SHA-256 values and the existing unique index.
ALTER TABLE device_tokens
    MODIFY COLUMN token_hash VARCHAR(64) NOT NULL;
