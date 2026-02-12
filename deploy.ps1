# PowerShell скрипт для деплоя на сервер
# Использование: .\deploy.ps1

$SERVER = "root@45.153.70.209"
$DOMAIN = "tg-text.ru"
$WWW_ROOT = "/var/www/$DOMAIN"

Write-Host "=== Деплой на сервер $SERVER ===" -ForegroundColor Green

# Проверка наличия Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ОШИБКА: Git не установлен!" -ForegroundColor Red
    exit 1
}

# Проверка наличия файлов
if (-not (Test-Path "index.html")) {
    Write-Host "ОШИБКА: index.html не найден!" -ForegroundColor Red
    exit 1
}

# Инициализация Git репозитория если нужно
if (-not (Test-Path ".git")) {
    Write-Host "Инициализация Git репозитория..." -ForegroundColor Yellow
    git init
    git branch -M main
}

# Добавление файлов
Write-Host "Добавление файлов в Git..." -ForegroundColor Yellow
git add .

# Проверка изменений
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "Нет изменений для коммита." -ForegroundColor Yellow
} else {
    # Создание коммита
    Write-Host "Создание коммита..." -ForegroundColor Yellow
    git commit -m "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

# Добавление remote если его нет
$remotes = git remote
if ($remotes -notcontains "production") {
    Write-Host "Добавление remote 'production'..." -ForegroundColor Yellow
    git remote add production "$SERVER`:$WWW_ROOT"
}

# Отправка на сервер
Write-Host "Отправка на сервер..." -ForegroundColor Yellow
try {
    git push production main --force
    Write-Host "=== Деплой завершен успешно! ===" -ForegroundColor Green
    Write-Host "Проверьте сайт: https://$DOMAIN" -ForegroundColor Cyan
} catch {
    Write-Host "ОШИБКА при отправке на сервер: $_" -ForegroundColor Red
    exit 1
}


