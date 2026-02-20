-- SQL скрипт для обновления базы данных (добавление таблицы users)
-- Выполнить: mysql -u root -p tg_text_db < update_database.sql

USE tg_text_db;

-- Создание таблицы пользователей (если не существует)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE COMMENT 'Email пользователя',
    password_hash VARCHAR(255) NOT NULL COMMENT 'Хеш пароля',
    name VARCHAR(255) COMMENT 'Имя пользователя',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Время регистрации',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Время последнего обновления',
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Таблица пользователей';

-- Добавление колонки user_id в user_requests (если не существует)
-- Проверяем существование колонки перед добавлением
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'tg_text_db'
  AND TABLE_NAME = 'user_requests'
  AND COLUMN_NAME = 'user_id';

SET @query = IF(@col_exists = 0,
    'ALTER TABLE user_requests ADD COLUMN user_id INT NULL COMMENT ''ID пользователя''',
    'SELECT ''Column user_id already exists'' AS message');

PREPARE stmt FROM @query;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Добавление индекса для user_id (если не существует)
SET @idx_exists = 0;
SELECT COUNT(*) INTO @idx_exists
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'tg_text_db'
  AND TABLE_NAME = 'user_requests'
  AND INDEX_NAME = 'idx_user_id';

SET @query2 = IF(@idx_exists = 0,
    'ALTER TABLE user_requests ADD INDEX idx_user_id (user_id)',
    'SELECT ''Index idx_user_id already exists'' AS message');

PREPARE stmt2 FROM @query2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;

-- Добавление внешнего ключа (если не существует)
SET @fk_exists = 0;
SELECT COUNT(*) INTO @fk_exists
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'tg_text_db'
  AND TABLE_NAME = 'user_requests'
  AND CONSTRAINT_NAME = 'fk_user_requests_user';

SET @query3 = IF(@fk_exists = 0,
    'ALTER TABLE user_requests ADD CONSTRAINT fk_user_requests_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL',
    'SELECT ''Foreign key fk_user_requests_user already exists'' AS message');

PREPARE stmt3 FROM @query3;
EXECUTE stmt3;
DEALLOCATE PREPARE stmt3;

-- Показать структуру таблиц
DESCRIBE users;
DESCRIBE user_requests;

