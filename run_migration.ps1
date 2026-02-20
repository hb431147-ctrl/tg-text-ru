# Скрипт для выполнения миграции на React
$SERVER = "root@45.153.70.209"
$PASSWORD = "wc.D_-X-1qERXt"
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa_tg_text"
$WWW_ROOT = "/var/www/tg-text.ru"

Write-Host "=== Автоматическая миграция на React ===" -ForegroundColor Green
Write-Host ""

# Функция для выполнения команд через SSH с паролем
function Invoke-SSHWithPassword {
    param($Server, $Password, $Command)
    
    # Используем plink если доступен
    if (Get-Command plink -ErrorAction SilentlyContinue) {
        $result = echo y | plink -ssh -pw $Password $Server $Command 2>&1
        return $result
    } else {
        Write-Host "plink не найден. Установите PuTTY или выполните команды вручную" -ForegroundColor Yellow
        Write-Host "Команда: $Command" -ForegroundColor White
        return $null
    }
}

# Шаг 1: Настройка SSH ключа
Write-Host "[1/5] Настройка SSH ключа..." -ForegroundColor Yellow
if (Test-Path "$SSH_KEY.pub") {
    $pubKey = Get-Content "$SSH_KEY.pub" -Raw
    $pubKey = $pubKey.Trim()
    
    $addKeyCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'OK'"
    
    if (Get-Command plink -ErrorAction SilentlyContinue) {
        $result = Invoke-SSHWithPassword -Server $SERVER -Password $PASSWORD -Command $addKeyCmd
        if ($result -match "OK") {
            Write-Host "SSH ключ добавлен успешно" -ForegroundColor Green
        }
    } else {
        Write-Host "Выполните вручную через SSH:" -ForegroundColor Yellow
        Write-Host "ssh $SERVER" -ForegroundColor White
        Write-Host "mkdir -p ~/.ssh && chmod 700 ~/.ssh" -ForegroundColor White
        Write-Host "echo '$pubKey' >> ~/.ssh/authorized_keys" -ForegroundColor White
        Write-Host "chmod 600 ~/.ssh/authorized_keys" -ForegroundColor White
        Write-Host ""
        Write-Host "Нажмите Enter после выполнения..." -ForegroundColor Yellow
        Read-Host
    }
} else {
    Write-Host "Публичный ключ не найден!" -ForegroundColor Red
    exit 1
}

# Шаг 2: Проверка Node.js
Write-Host ""
Write-Host "[2/5] Проверка Node.js..." -ForegroundColor Yellow
$nodeCheck = ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "node --version 2>&1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Установка Node.js..." -ForegroundColor Cyan
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "pacman -Sy --noconfirm nodejs npm" 2>&1 | Out-Null
}

# Шаг 3: Обновление БД
Write-Host ""
Write-Host "[3/5] Обновление базы данных..." -ForegroundColor Yellow
scp -i $SSH_KEY -o StrictHostKeyChecking=no "update_database.sql" "${SERVER}:${WWW_ROOT}/update_database.sql" 2>&1 | Out-Null
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "mysql -u root -ptg_text_password_2024 tg_text_db < ${WWW_ROOT}/update_database.sql 2>&1" 2>&1 | Out-Null
Write-Host "База данных обновлена" -ForegroundColor Green

# Шаг 4: Деплой
Write-Host ""
Write-Host "[4/5] Деплой приложения..." -ForegroundColor Yellow
& ".\deploy.ps1"

# Шаг 5: Обновление зависимостей на сервере
Write-Host ""
Write-Host "[5/5] Обновление зависимостей..." -ForegroundColor Yellow
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "cd ${WWW_ROOT} && npm install 2>&1" 2>&1 | Out-Null
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "systemctl restart text-processor 2>&1" 2>&1 | Out-Null

Write-Host ""
Write-Host "=== Миграция завершена! ===" -ForegroundColor Green
Write-Host "Проверьте: https://tg-text.ru" -ForegroundColor Cyan

