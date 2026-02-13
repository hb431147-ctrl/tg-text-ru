#!/bin/bash
# Скрипт установки MySQL на Ubuntu

set -e

echo "=== Установка MySQL на Ubuntu ==="

# Обновление списка пакетов
echo "Обновление списка пакетов..."
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Проверяем, установлен ли уже MySQL
if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null; then
    echo "MySQL уже запущен, пропускаем установку..."
else
    # Установка MySQL Server
    echo "Установка MySQL Server..."
    apt-get install -y mysql-server
    
    # Запуск MySQL
    echo "Запуск MySQL..."
    systemctl enable mysql
    systemctl start mysql
    
    # Ожидание запуска MySQL
    echo "Ожидание запуска MySQL..."
    sleep 5
    
    # Проверяем, что сервис запущен
    if ! systemctl is-active --quiet mysql 2>/dev/null && ! systemctl is-active --quiet mysqld 2>/dev/null; then
        echo "ОШИБКА: MySQL не запустился!"
        echo "Проверьте логи: journalctl -xeu mysql.service"
        exit 1
    fi
fi

# Установка пароля root и создание базы данных
echo "Настройка MySQL..."

# Используем готовый SQL скрипт, если он есть
if [ -f "/var/www/tg-text.ru/init_database.sql" ]; then
    echo "Использование init_database.sql..."
    mysql -u root < /var/www/tg-text.ru/init_database.sql 2>/dev/null || {
        echo "ВНИМАНИЕ: Не удалось выполнить настройку автоматически."
        echo "Выполните вручную:"
        echo "  mysql -u root -p < /var/www/tg-text.ru/init_database.sql"
    }
else
    # Создаем SQL скрипт для настройки
    cat > /tmp/mysql_setup.sql << 'EOF'
-- Создание базы данных
CREATE DATABASE IF NOT EXISTS tg_text_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Использование базы данных
USE tg_text_db;

-- Создание пользователя (удаляем если существует, затем создаем заново)
DROP USER IF EXISTS 'tg_text_user'@'localhost';
CREATE USER 'tg_text_user'@'localhost' IDENTIFIED BY 'tg_text_password_2024';
GRANT ALL PRIVILEGES ON tg_text_db.* TO 'tg_text_user'@'localhost';
FLUSH PRIVILEGES;

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
    mysql -u root < /tmp/mysql_setup.sql 2>/dev/null || {
        echo "ВНИМАНИЕ: Не удалось выполнить настройку автоматически."
        echo "Выполните вручную:"
        echo "  mysql -u root -p < /tmp/mysql_setup.sql"
    }
    
    # Удаляем временный файл
    rm -f /tmp/mysql_setup.sql
fi

echo "=== MySQL установлен и настроен успешно! ==="
echo "База данных: tg_text_db"
echo "Пользователь: tg_text_user"
echo "Пароль: tg_text_password_2024"
echo ""
echo "Проверка подключения:"
mysql -u tg_text_user -ptg_text_password_2024 tg_text_db -e "SELECT 1;" 2>/dev/null && echo "✓ Подключение работает!" || echo "✗ Ошибка подключения (возможно нужен пароль root)"

