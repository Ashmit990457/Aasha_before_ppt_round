CREATE TABLE IF NOT EXISTS device_tokens (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_uid VARCHAR(128) NOT NULL,
    token TEXT NOT NULL,
    token_hash CHAR(64) NOT NULL,
    platform VARCHAR(32) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_device_token_hash (token_hash),
    INDEX idx_device_tokens_user_active (user_uid, active),
    CONSTRAINT fk_device_tokens_user FOREIGN KEY (user_uid) REFERENCES users(uid)
);
