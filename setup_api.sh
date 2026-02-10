#!/bin/bash

# Скрипт установки API на сервере

set -e

API_DIR="/var/www/tg-text.ru/api"
SERVICE_FILE="text-processor.service"

echo "=== Установка API сервера ==="

# Создаем директорию для API
mkdir -p ${API_DIR}

# Устанавливаем Python зависимости
echo "Установка Python зависимостей..."
pacman -S --noconfirm python python-pip gunicorn || true
pip install --upgrade pip || true

# Копируем файлы API
echo "Копирование файлов..."
cp app.py ${API_DIR}/
cp requirements.txt ${API_DIR}/

# Устанавливаем зависимости Python
cd ${API_DIR}
pip install -r requirements.txt --user || pip3 install -r requirements.txt --user

# Устанавливаем права
chown -R http:http ${API_DIR}
chmod +x ${API_DIR}/app.py

# Копируем и активируем systemd service
cp ${SERVICE_FILE} /etc/systemd/system/
systemctl daemon-reload
systemctl enable text-processor
systemctl start text-processor

echo "=== API сервер установлен ==="
echo "Проверка статуса: systemctl status text-processor"

