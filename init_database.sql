-- SQL скрипт для создания базы данных и таблицы запросов
-- Выполнить: mysql -u root -p < init_database.sql

-- Создание базы данных
CREATE DATABASE IF NOT EXISTS tg_text_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Использование базы данных
USE tg_text_db;

-- Создание пользователя (удаляем если существует, затем создаем заново)
DROP USER IF EXISTS 'tg_text_user'@'localhost';
CREATE USER 'tg_text_user'@'localhost' IDENTIFIED BY 'tg_text_password_2024';
GRANT ALL PRIVILEGES ON tg_text_db.* TO 'tg_text_user'@'localhost';
FLUSH PRIVILEGES;

-- Создание таблицы запросов пользователей
CREATE TABLE IF NOT EXISTS user_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_ip VARCHAR(45) NOT NULL COMMENT 'IP адрес пользователя',
    user_agent TEXT COMMENT 'User-Agent браузера',
    request_text TEXT NOT NULL COMMENT 'Исходный текст запроса',
    exclude_words TEXT COMMENT 'Слова для исключения',
    result_text TEXT COMMENT 'Результат обработки',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Время создания запроса',
    INDEX idx_user_ip (user_ip),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Таблица для хранения запросов пользователей';

-- Показать структуру таблицы
DESCRIBE user_requests;

