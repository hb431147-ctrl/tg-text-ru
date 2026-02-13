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
$WWW_ROOT = "/var/www/$DOMAIN"

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
    Write-Host "  Git репозиторий: $WWW_ROOT" -ForegroundColor Gray
    Write-Host "  Рабочая директория: $WWW_ROOT/public_html" -ForegroundColor Gray
    
    # Выполняем push с подробным выводом для отслеживания hook
    Write-Host "Выполнение git push..." -ForegroundColor Gray
    
    # Захватываем вывод команды
    $pushOutput = ""
    $pushError = ""
    
    try {
        # Выполняем push и захватываем весь вывод
        $pushOutput = git push production main --force 2>&1 | Out-String
        $pushExitCode = $LASTEXITCODE
    } catch {
        $pushError = $_.Exception.Message
        $pushExitCode = 1
    }
    
    # Выводим результат push
    if ($pushOutput) {
        Write-Host "Вывод git push:" -ForegroundColor Cyan
        Write-Host $pushOutput -ForegroundColor Gray
    }
    
    if ($pushExitCode -ne 0) {
        Write-Host "ОШИБКА при отправке на сервер!" -ForegroundColor Red
        if ($pushError) {
            Write-Host "Ошибка: $pushError" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Проверьте:" -ForegroundColor Yellow
        Write-Host "  - SSH ключ настроен для доступа к серверу" -ForegroundColor Yellow
        Write-Host "  - Git репозиторий на сервере: $WWW_ROOT/.git" -ForegroundColor Yellow
        Write-Host "  - Git hook post-receive установлен: $WWW_ROOT/.git/hooks/post-receive" -ForegroundColor Yellow
        Write-Host "  - Права доступа к директории на сервере" -ForegroundColor Yellow
        throw "Ошибка git push (код выхода: $pushExitCode)"
    }
    
    Write-Host "Отправка выполнена успешно." -ForegroundColor Green
    
    # Проверяем, что hook выполнился (ищем сообщения hook в выводе)
    if ($pushOutput -match "Начало деплоя|Деплой завершен|checkout|Копирование") {
        Write-Host "Git hook выполнен успешно (обнаружены сообщения hook)." -ForegroundColor Green
    } else {
        Write-Host "ВНИМАНИЕ: Не обнаружено подтверждение выполнения Git hook в выводе!" -ForegroundColor Yellow
        Write-Host "Это может быть нормально, если hook выполняется в фоне." -ForegroundColor Yellow
    }
    
    # Даем время hook выполниться
    Write-Host "Ожидание завершения hook на сервере..." -ForegroundColor Gray
    Start-Sleep -Seconds 3
    
    # Проверяем файлы на сервере
    Write-Host "Проверка файлов на сервере..." -ForegroundColor Gray
    try {
        $checkFiles = ssh $SERVER "test -f $WWW_ROOT/public_html/index.html && echo 'OK' || echo 'NOT_FOUND'" 2>&1
        if ($checkFiles -match "OK") {
            Write-Host "Файл index.html найден на сервере." -ForegroundColor Green
            
            # Проверяем дату модификации файла
            $fileDate = ssh $SERVER "stat -c '%y' $WWW_ROOT/public_html/index.html" 2>&1
            if ($fileDate) {
                Write-Host "Дата модификации index.html: $fileDate" -ForegroundColor Gray
            }
        } else {
            Write-Host "ВНИМАНИЕ: Файл index.html не найден на сервере!" -ForegroundColor Yellow
            Write-Host "Возможно hook не выполнился или произошла ошибка." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Пробуем альтернативный способ деплоя через SSH..." -ForegroundColor Yellow
            
            # Пытаемся выполнить деплой вручную через SSH
            try {
                Write-Host "Выполнение деплоя через SSH..." -ForegroundColor Gray
                $sshDeploy = ssh $SERVER "cd $WWW_ROOT && export GIT_DIR=$WWW_ROOT/.git && export GIT_WORK_TREE=$WWW_ROOT && git checkout -f main && bash $WWW_ROOT/.git/hooks/post-receive" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Альтернативный деплой выполнен успешно." -ForegroundColor Green
                } else {
                    Write-Host "Альтернативный деплой не удался. Вывод:" -ForegroundColor Yellow
                    Write-Host $sshDeploy -ForegroundColor Gray
                }
            } catch {
                Write-Host "Не удалось выполнить альтернативный деплой: $_" -ForegroundColor Yellow
            }
            
            Write-Host ""
            Write-Host "Диагностика:" -ForegroundColor Yellow
            Write-Host "1. Проверьте наличие hook: ssh $SERVER 'ls -la $WWW_ROOT/.git/hooks/post-receive'" -ForegroundColor Cyan
            Write-Host "2. Проверьте права на hook: ssh $SERVER 'test -x $WWW_ROOT/.git/hooks/post-receive && echo OK || echo NO_EXEC'" -ForegroundColor Cyan
            Write-Host "3. Проверьте файлы в репозитории: ssh $SERVER 'ls -la $WWW_ROOT/'" -ForegroundColor Cyan
            Write-Host "4. Проверьте настройки Git: ssh $SERVER 'cd $WWW_ROOT && git config receive.denyCurrentBranch'" -ForegroundColor Cyan
            Write-Host "5. Выполните hook вручную: ssh $SERVER 'cd $WWW_ROOT && bash $WWW_ROOT/.git/hooks/post-receive'" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "Не удалось проверить файлы на сервере (это нормально, если SSH требует интерактивного ввода)." -ForegroundColor Yellow
        Write-Host "Проверьте вручную через SSH:" -ForegroundColor Yellow
        Write-Host "  ssh $SERVER" -ForegroundColor Cyan
        Write-Host "  ls -la $WWW_ROOT/public_html/" -ForegroundColor Cyan
    }
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


