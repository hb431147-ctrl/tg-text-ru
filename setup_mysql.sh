#!/bin/bash
# Скрипт установки MySQL на Arch Linux

set -e

echo "=== Установка MySQL на Arch Linux ==="

# Обновление системы
echo "Обновление системы..."
pacman -Syu --noconfirm

# Установка MySQL
echo "Установка MySQL..."
pacman -S --noconfirm mysql

# Запуск MySQL
echo "Запуск MySQL..."
systemctl enable mysqld
systemctl start mysqld

# Ожидание запуска MySQL
echo "Ожидание запуска MySQL..."
sleep 5

# Получение временного пароля root (если есть)
TEMP_PASSWORD=$(sudo grep 'temporary password' /var/log/mysqld.log 2>/dev/null | awk '{print $NF}' | tail -1 || echo "")

# Установка пароля root и создание базы данных
echo "Настройка MySQL..."

# Создаем SQL скрипт для настройки
cat > /tmp/mysql_setup.sql << 'EOF'
-- Создание базы данных
CREATE DATABASE IF NOT EXISTS tg_text_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Создание пользователя (если не существует)
CREATE USER IF NOT EXISTS 'tg_text_user'@'localhost' IDENTIFIED BY 'tg_text_password_2024';
GRANT ALL PRIVILEGES ON tg_text_db.* TO 'tg_text_user'@'localhost';
FLUSH PRIVILEGES;

-- Использование базы данных
USE tg_text_db;

-- Создание таблицы запросов
CREATE TABLE IF NOT EXISTS user_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_ip VARCHAR(45) NOT NULL,
    user_agent TEXT,
    request_text TEXT NOT NULL,
    exclude_words TEXT,
    result_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_ip (user_ip),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOF

# Выполняем настройку
if [ -n "$TEMP_PASSWORD" ]; then
    mysql -u root -p"$TEMP_PASSWORD" --connect-expired-password < /tmp/mysql_setup.sql 2>/dev/null || \
    mysql -u root < /tmp/mysql_setup.sql
else
    mysql -u root < /tmp/mysql_setup.sql
fi

# Удаляем временный файл
rm -f /tmp/mysql_setup.sql

echo "=== MySQL установлен и настроен успешно! ==="
echo "База данных: tg_text_db"
echo "Пользователь: tg_text_user"
echo "Пароль: tg_text_password_2024"

