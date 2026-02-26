-- Add prompt template and request count to users
-- History last 7 days is enforced in API (WHERE created_at >= ...)
USE tg_text_db;

ALTER TABLE users ADD COLUMN prompt_template TEXT NULL COMMENT 'Prompt with {text} and {exc}';
ALTER TABLE users ADD COLUMN request_count INT NOT NULL DEFAULT 1 COMMENT 'Number of requests per run (1+)';
