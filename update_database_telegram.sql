-- SQL script for adding Telegram bot support
-- Execute: mysql -u tg_text_user -p tg_text_db < update_database_telegram.sql

USE tg_text_db;

-- Check if column exists, if not add it
SET @dbname = DATABASE();
SET @tablename = 'users';
SET @columnname = 'telegram_id';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  'SELECT 1',
  CONCAT('ALTER TABLE ', @tablename, ' ADD COLUMN ', @columnname, ' VARCHAR(50) NULL UNIQUE COMMENT ''Telegram ID пользователя'', ADD INDEX idx_telegram_id (', @columnname, ')')
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- Show updated structure
DESCRIBE users;
