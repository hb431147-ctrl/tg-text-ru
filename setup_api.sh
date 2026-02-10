#!/bin/bash

# Скрипт установки API на сервере (Node.js)

set -e

API_DIR="/var/www/tg-text.ru/api"
SERVICE_FILE="text-processor.service"

echo "=== Установка API сервера (Node.js) ==="

# Создаем директорию для API
mkdir -p ${API_DIR}

# Устанавливаем Node.js если не установлен
echo "Проверка Node.js..."
if ! command -v node &> /dev/null; then
    echo "Установка Node.js..."
    pacman -S --noconfirm nodejs npm
fi

# Проверяем версию Node.js
NODE_VERSION=$(node --version)
echo "Node.js версия: ${NODE_VERSION}"

# Копируем файлы API
echo "Копирование файлов..."
cp app.js ${API_DIR}/
cp package.json ${API_DIR}/

# Устанавливаем зависимости
cd ${API_DIR}
echo "Установка npm зависимостей..."
npm install --production

# Устанавливаем права
chown -R http:http ${API_DIR}
chmod +x ${API_DIR}/app.js

# Копируем и активируем systemd service
cp ${SERVICE_FILE} /etc/systemd/system/
systemctl daemon-reload
systemctl enable text-processor
systemctl restart text-processor

echo "=== API сервер установлен ==="
echo "Проверка статуса: systemctl status text-processor"
echo "Проверка API: curl http://127.0.0.1:5000/api/health"
