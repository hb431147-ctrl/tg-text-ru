# Скрипт для выполнения миграции на React
$SERVER = "root@45.153.70.209"
$PASSWORD = "wc.D_-X-1qERXt"
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa_tg_text"
$WWW_ROOT = "/var/www/tg-text.ru"

Write-Host "=== Автоматическая миграция на React ===" -ForegroundColor Green
Write-Host ""

# Проверяем наличие SSH ключа
if (-not (Test-Path $SSH_KEY)) {
    Write-Host "ОШИБКА: SSH ключ не найден!" -ForegroundColor Red
    Write-Host "Создайте ключ: .\create_ssh_key.ps1" -ForegroundColor Yellow
    exit 1
}

# Шаг 1: Настройка SSH ключа (если еще не настроен)
Write-Host "[1/5] Проверка SSH подключения..." -ForegroundColor Yellow
$testConnection = ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5 $SERVER "echo 'OK'" 2>&1

if ($LASTEXITCODE -ne 0 -or $testConnection -notmatch "OK") {
    Write-Host "SSH ключ не настроен. Добавьте ключ вручную:" -ForegroundColor Yellow
    Write-Host ""
    $pubKey = Get-Content "$SSH_KEY.pub" -Raw
    Write-Host "Публичный ключ:" -ForegroundColor Cyan
    Write-Host $pubKey.Trim() -ForegroundColor White
    Write-Host ""
    Write-Host "Выполните на сервере:" -ForegroundColor Yellow
    Write-Host "ssh $SERVER" -ForegroundColor White
    Write-Host "mkdir -p ~/.ssh && chmod 700 ~/.ssh" -ForegroundColor White
    Write-Host "echo 'ПУБЛИЧНЫЙ_КЛЮЧ_ВЫШЕ' >> ~/.ssh/authorized_keys" -ForegroundColor White
    Write-Host "chmod 600 ~/.ssh/authorized_keys" -ForegroundColor White
    Write-Host ""
    Write-Host "Нажмите Enter после добавления ключа..." -ForegroundColor Yellow
    Read-Host
} else {
    Write-Host "SSH подключение работает!" -ForegroundColor Green
}

# Шаг 2: Проверка Node.js
Write-Host ""
Write-Host "[2/5] Проверка Node.js на сервере..." -ForegroundColor Yellow
$nodeVersion = ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "node --version 2>&1"
if ($LASTEXITCODE -ne 0 -or $nodeVersion -match "command not found") {
    Write-Host "Установка Node.js..." -ForegroundColor Cyan
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "pacman -Sy --noconfirm nodejs npm" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Node.js установлен" -ForegroundColor Green
    } else {
        Write-Host "ОШИБКА при установке Node.js" -ForegroundColor Red
    }
} else {
    Write-Host "Node.js установлен: $nodeVersion" -ForegroundColor Green
}

# Шаг 3: Обновление базы данных
Write-Host ""
Write-Host "[3/5] Обновление базы данных..." -ForegroundColor Yellow

# Копируем SQL файл
Write-Host "Копирование update_database.sql на сервер..." -ForegroundColor Cyan
scp -i $SSH_KEY -o StrictHostKeyChecking=no "update_database.sql" "${SERVER}:${WWW_ROOT}/update_database.sql" 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Файл скопирован" -ForegroundColor Green
} else {
    Write-Host "ОШИБКА при копировании файла" -ForegroundColor Red
}

# Выполняем SQL скрипт
Write-Host "Выполнение SQL скрипта..." -ForegroundColor Cyan
$sqlResult = ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "mysql -u root -ptg_text_password_2024 tg_text_db < ${WWW_ROOT}/update_database.sql 2>&1" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "База данных обновлена" -ForegroundColor Green
} else {
    Write-Host "Попытка с другим паролем..." -ForegroundColor Yellow
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "mysql -u root -p'$PASSWORD' tg_text_db < ${WWW_ROOT}/update_database.sql 2>&1" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "База данных обновлена" -ForegroundColor Green
    } else {
        Write-Host "ОШИБКА при обновлении БД. Выполните вручную:" -ForegroundColor Red
        Write-Host "ssh $SERVER" -ForegroundColor White
        Write-Host "mysql -u root -p tg_text_db < update_database.sql" -ForegroundColor White
    }
}

# Шаг 4: Деплой приложения
Write-Host ""
Write-Host "[4/5] Деплой приложения..." -ForegroundColor Yellow
Write-Host "Запуск deploy.ps1..." -ForegroundColor Cyan
& ".\deploy.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ОШИБКА при деплое!" -ForegroundColor Red
    exit 1
}

# Шаг 5: Обновление зависимостей на сервере
Write-Host ""
Write-Host "[5/5] Обновление зависимостей на сервере..." -ForegroundColor Yellow

Write-Host "Установка зависимостей npm..." -ForegroundColor Cyan
$npmResult = ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "cd ${WWW_ROOT} && npm install 2>&1" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Зависимости установлены" -ForegroundColor Green
} else {
    Write-Host "Предупреждение: возможна ошибка при установке зависимостей" -ForegroundColor Yellow
    Write-Host $npmResult -ForegroundColor Gray
}

Write-Host "Перезапуск API сервиса..." -ForegroundColor Cyan
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "systemctl restart text-processor 2>&1" 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Сервис перезапущен" -ForegroundColor Green
} else {
    Write-Host "Предупреждение: возможна ошибка при перезапуске сервиса" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Миграция завершена! ===" -ForegroundColor Green
Write-Host "Проверьте сайт: https://tg-text.ru" -ForegroundColor Cyan
Write-Host ""
Write-Host "Если возникли проблемы, проверьте логи:" -ForegroundColor Yellow
Write-Host "ssh $SERVER 'journalctl -u text-processor -n 50'" -ForegroundColor White

