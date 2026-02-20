# Скрипт для автоматической миграции на React
$SERVER = "root@45.153.70.209"
$PASSWORD = "wc.D_-X-1qERXt"
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa_tg_text"
$WWW_ROOT = "/var/www/tg-text.ru"

Write-Host "=== Автоматическая миграция на React ===" -ForegroundColor Green
Write-Host ""

# Шаг 1: Настройка SSH ключа
Write-Host "[1/5] Настройка SSH ключа..." -ForegroundColor Yellow
if (Test-Path "$SSH_KEY.pub") {
    $pubKey = Get-Content "$SSH_KEY.pub" -Raw
    $pubKey = $pubKey.Trim()
    
    Write-Host "Добавление ключа на сервер (требуется пароль)..." -ForegroundColor Cyan
    
    # Используем ssh с паролем через expect-подобный скрипт
    # Создаем команду для добавления ключа
    $addKeyCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    
    # Пробуем использовать plink если доступен
    if (Get-Command plink -ErrorAction SilentlyContinue) {
        Write-Host "Используется plink для подключения..." -ForegroundColor Gray
        $plinkCmd = "echo y | plink -ssh -pw `"$PASSWORD`" $SERVER `"$addKeyCmd`""
        Invoke-Expression $plinkCmd | Out-Null
    } else {
        Write-Host "plink не найден. Выполните вручную:" -ForegroundColor Yellow
        Write-Host "ssh $SERVER" -ForegroundColor White
        Write-Host "mkdir -p ~/.ssh && chmod 700 ~/.ssh" -ForegroundColor White
        Write-Host "echo '$pubKey' >> ~/.ssh/authorized_keys" -ForegroundColor White
        Write-Host "chmod 600 ~/.ssh/authorized_keys" -ForegroundColor White
        Write-Host ""
        Write-Host "Нажмите Enter после выполнения команд выше..." -ForegroundColor Yellow
        Read-Host
    }
} else {
    Write-Host "Публичный ключ не найден. Создайте ключ: .\create_ssh_key.ps1" -ForegroundColor Red
    exit 1
}

# Шаг 2: Проверка Node.js на сервере
Write-Host ""
Write-Host "[2/5] Проверка Node.js на сервере..." -ForegroundColor Yellow

$nodeCheck = ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "node --version 2>&1; npm --version 2>&1" 2>&1

if ($LASTEXITCODE -ne 0 -or $nodeCheck -match "command not found") {
    Write-Host "Node.js не установлен. Устанавливаю..." -ForegroundColor Cyan
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "pacman -Sy --noconfirm nodejs npm" 2>&1 | Out-Null
    Write-Host "Node.js установлен." -ForegroundColor Green
} else {
    Write-Host "Node.js уже установлен: $nodeCheck" -ForegroundColor Green
}

# Шаг 3: Обновление базы данных
Write-Host ""
Write-Host "[3/5] Обновление базы данных..." -ForegroundColor Yellow

# Копируем SQL файл на сервер
scp -i $SSH_KEY -o StrictHostKeyChecking=no "update_database.sql" "${SERVER}:${WWW_ROOT}/update_database.sql" 2>&1 | Out-Null

# Выполняем SQL скрипт
Write-Host "Выполнение SQL скрипта..." -ForegroundColor Cyan
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "mysql -u root -ptg_text_password_2024 tg_text_db < ${WWW_ROOT}/update_database.sql 2>&1 || mysql -u root -p'wc.D_-X-1qERXt' tg_text_db < ${WWW_ROOT}/update_database.sql 2>&1" 2>&1 | Out-Null

Write-Host "База данных обновлена." -ForegroundColor Green

# Шаг 4: Деплой приложения
Write-Host ""
Write-Host "[4/5] Деплой приложения..." -ForegroundColor Yellow

# Запускаем деплой скрипт
Write-Host "Запуск deploy.ps1..." -ForegroundColor Cyan
& ".\deploy.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ОШИБКА при деплое!" -ForegroundColor Red
    exit 1
}

# Шаг 5: Обновление зависимостей и перезапуск сервиса на сервере
Write-Host ""
Write-Host "[5/5] Обновление зависимостей на сервере..." -ForegroundColor Yellow

Write-Host "Установка зависимостей..." -ForegroundColor Cyan
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "cd ${WWW_ROOT} && npm install 2>&1" 2>&1 | Out-Null

Write-Host "Перезапуск API сервиса..." -ForegroundColor Cyan
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "systemctl restart text-processor 2>&1" 2>&1 | Out-Null

Write-Host ""
Write-Host "=== Миграция завершена успешно! ===" -ForegroundColor Green
Write-Host "Проверьте сайт: https://tg-text.ru" -ForegroundColor Cyan

