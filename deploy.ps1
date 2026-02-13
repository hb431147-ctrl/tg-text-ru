# PowerShell скрипт для деплоя на сервер
# Использование: 
#   .\deploy.ps1              - обычный деплой
#   .\deploy.ps1 -RollbackBack    - откат на одну версию назад
#   .\deploy.ps1 -RollbackForward - откат на одну версию вперед (возврат к последней версии)
# Или: powershell -ExecutionPolicy Bypass -File .\deploy.ps1

param(
    [switch]$RollbackBack,
    [switch]$RollbackForward
)

$SERVER = "root@45.153.70.209"
$DOMAIN = "tg-text.ru"
$WWW_ROOT = "/var/www/$DOMAIN/public_html"

# Проверка наличия Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ОШИБКА: Git не установлен!" -ForegroundColor Red
    exit 1
}

# Функция для получения текущего коммита
function Get-CurrentCommit {
    return git rev-parse HEAD
}

# Функция для получения истории коммитов
function Get-CommitHistory {
    $commits = git log --oneline --all | ForEach-Object {
        $parts = $_ -split ' ', 2
        @{
            Hash = $parts[0]
            Message = $parts[1]
        }
    }
    return $commits
}

# Функция для отката назад
function Rollback-Back {
    Write-Host "=== Откат на одну версию назад ===" -ForegroundColor Yellow
    
    # Проверка наличия Git репозитория
    if (-not (Test-Path ".git")) {
        Write-Host "ОШИБКА: Git репозиторий не инициализирован!" -ForegroundColor Red
        Write-Host "Сначала выполните обычный деплой: .\deploy.ps1" -ForegroundColor Yellow
        exit 1
    }
    
    # Получаем текущий коммит
    $currentCommit = Get-CurrentCommit
    
    # Получаем историю коммитов
    $commits = Get-CommitHistory
    
    if ($commits.Count -lt 2) {
        Write-Host "ОШИБКА: Недостаточно коммитов для отката!" -ForegroundColor Red
        exit 1
    }
    
    # Находим предыдущий коммит (второй в списке)
    $previousCommit = $commits[1].Hash
    $previousMessage = $commits[1].Message
    
    Write-Host "Текущий коммит: $currentCommit" -ForegroundColor Cyan
    Write-Host "Откат к коммиту: $previousCommit ($previousMessage)" -ForegroundColor Cyan
    
    # Откатываемся к предыдущему коммиту
    try {
        git reset --hard $previousCommit
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ОШИБКА: Не удалось выполнить откат!" -ForegroundColor Red
            exit 1
        }
        Write-Host "Локальный откат выполнен успешно." -ForegroundColor Green
        
        # Отправляем изменения на сервер
        Deploy-ToServer
        
        Write-Host "=== Откат завершен успешно! ===" -ForegroundColor Green
        Write-Host "Проверьте сайт: https://$DOMAIN" -ForegroundColor Cyan
    } catch {
        Write-Host "ОШИБКА при откате: $_" -ForegroundColor Red
        exit 1
    }
}

# Функция для отката вперед (возврат к последней версии)
function Rollback-Forward {
    Write-Host "=== Откат на одну версию вперед (возврат к последней версии) ===" -ForegroundColor Yellow
    
    # Проверка наличия Git репозитория
    if (-not (Test-Path ".git")) {
        Write-Host "ОШИБКА: Git репозиторий не инициализирован!" -ForegroundColor Red
        Write-Host "Сначала выполните обычный деплой: .\deploy.ps1" -ForegroundColor Yellow
        exit 1
    }
    
    # Получаем текущий коммит
    $currentCommit = Get-CurrentCommit
    
    # Используем HEAD@{1} для получения последней версии (до отката)
    # HEAD@{1} содержит предыдущее положение HEAD перед текущим reset
    try {
        # Получаем предыдущий HEAD из reflog
        $previousHeadOutput = git rev-parse HEAD@{1} 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ОШИБКА: Не найдена предыдущая версия в истории!" -ForegroundColor Red
            Write-Host "Возможно, вы уже на последней версии или не было отката назад." -ForegroundColor Yellow
            Write-Host "Попробуйте сначала выполнить откат назад: .\deploy.ps1 -RollbackBack" -ForegroundColor Yellow
            exit 1
        }
        
        $previousHead = $previousHeadOutput.ToString().Trim()
        
        if ([string]::IsNullOrWhiteSpace($previousHead)) {
            Write-Host "ОШИБКА: Не найдена предыдущая версия в истории!" -ForegroundColor Red
            exit 1
        }
        
        # Проверяем, что это действительно другая версия
        if ($previousHead -eq $currentCommit) {
            Write-Host "ОШИБКА: Вы уже на последней версии!" -ForegroundColor Red
            exit 1
        }
        
        # Получаем информацию о коммите
        $commitMessage = git log -1 --format="%s" $previousHead
        
        Write-Host "Текущий коммит: $currentCommit" -ForegroundColor Cyan
        Write-Host "Возврат к коммиту: $previousHead ($commitMessage)" -ForegroundColor Cyan
        
        # Возвращаемся к последней версии
        git reset --hard $previousHead
        if ($LASTEXITCODE -ne 0) {
            throw "Не удалось выполнить git reset --hard"
        }
        
        Write-Host "Локальный откат выполнен успешно." -ForegroundColor Green
        
        # Отправляем изменения на сервер
        Deploy-ToServer
        
        Write-Host "=== Откат завершен успешно! ===" -ForegroundColor Green
        Write-Host "Проверьте сайт: https://$DOMAIN" -ForegroundColor Cyan
    } catch {
        Write-Host "ОШИБКА при откате: $_" -ForegroundColor Red
        exit 1
    }
}

# Функция для отправки на сервер
function Deploy-ToServer {
    # Добавление remote если его нет
    $remotes = git remote
    if ($remotes -notcontains "production") {
        Write-Host "Добавление remote 'production'..." -ForegroundColor Yellow
        Write-Host "  URL: $SERVER`:$WWW_ROOT" -ForegroundColor Gray
        git remote add production "$SERVER`:$WWW_ROOT"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ОШИБКА: Не удалось добавить remote 'production'!" -ForegroundColor Red
            throw "Не удалось добавить remote"
        }
    } else {
        # Обновляем URL remote на случай изменения
        git remote set-url production "$SERVER`:$WWW_ROOT"
    }
    
    # Проверяем текущий коммит перед отправкой
    $currentCommit = git rev-parse HEAD
    Write-Host "Текущий коммит: $currentCommit" -ForegroundColor Gray
    
    # Отправка на сервер
    Write-Host "Отправка на сервер..." -ForegroundColor Yellow
    Write-Host "  Сервер: $SERVER" -ForegroundColor Gray
    Write-Host "  Путь: $WWW_ROOT" -ForegroundColor Gray
    
    $pushOutput = git push production main --force 2>&1
    $pushExitCode = $LASTEXITCODE
    
    if ($pushExitCode -ne 0) {
        Write-Host "ОШИБКА при отправке на сервер!" -ForegroundColor Red
        Write-Host "Вывод команды:" -ForegroundColor Yellow
        Write-Host $pushOutput -ForegroundColor Red
        Write-Host ""
        Write-Host "Проверьте:" -ForegroundColor Yellow
        Write-Host "  - SSH ключ настроен для доступа к серверу" -ForegroundColor Yellow
        Write-Host "  - Путь на сервере правильный: $WWW_ROOT" -ForegroundColor Yellow
        Write-Host "  - Git репозиторий на сервере инициализирован" -ForegroundColor Yellow
        Write-Host "  - Права доступа к директории на сервере" -ForegroundColor Yellow
        throw "Ошибка git push (код выхода: $pushExitCode)"
    }
    
    Write-Host "Отправка выполнена успешно." -ForegroundColor Green
}

# Основная логика
if ($RollbackBack) {
    Rollback-Back
    exit 0
}

if ($RollbackForward) {
    Rollback-Forward
    exit 0
}

# Обычный деплой
Write-Host "=== Деплой на сервер $SERVER ===" -ForegroundColor Green

# Проверка наличия файлов
if (-not (Test-Path "index.html")) {
    Write-Host "ОШИБКА: index.html не найден!" -ForegroundColor Red
    exit 1
}

# Инициализация Git репозитория если нужно
if (-not (Test-Path ".git")) {
    Write-Host "Инициализация Git репозитория..." -ForegroundColor Yellow
    git init
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ОШИБКА: Не удалось инициализировать Git репозиторий!" -ForegroundColor Red
        exit 1
    }
    git branch -M main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ОШИБКА: Не удалось переименовать ветку в main!" -ForegroundColor Red
        exit 1
    }
}

# Добавление файлов
Write-Host "Добавление файлов в Git..." -ForegroundColor Yellow
git add .
if ($LASTEXITCODE -ne 0) {
    Write-Host "ОШИБКА: Не удалось добавить файлы в Git!" -ForegroundColor Red
    exit 1
}

# Проверка изменений
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "Нет изменений для коммита." -ForegroundColor Yellow
} else {
    # Создание коммита
    Write-Host "Создание коммита..." -ForegroundColor Yellow
    git commit -m "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ОШИБКА: Не удалось создать коммит!" -ForegroundColor Red
        exit 1
    }
}

# Отправка на сервер
Deploy-ToServer

Write-Host "=== Деплой завершен успешно! ===" -ForegroundColor Green
Write-Host "Проверьте сайт: https://$DOMAIN" -ForegroundColor Cyan


