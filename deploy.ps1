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

# Путь к SSH ключу
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa"

# Проверка наличия SSH ключа
if (-not (Test-Path $SSH_KEY)) {
    Write-Host "ОШИБКА: SSH ключ не найден: $SSH_KEY" -ForegroundColor Red
    Write-Host "Создайте ключ: ssh-keygen -t rsa -f $SSH_KEY" -ForegroundColor Yellow
    exit 1
}

# Настройка SSH для использования правильного ключа
$env:GIT_SSH_COMMAND = "ssh -i `"$SSH_KEY`" -o StrictHostKeyChecking=accept-new"

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
        
        # Отправляем изменения в GitHub
        Deploy-ToGitHub
        
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
        
        # Отправляем изменения в GitHub
        Deploy-ToGitHub
        
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
    Write-Host "Используется SSH ключ: $SSH_KEY" -ForegroundColor Gray
    
    # Выполняем push с явным указанием SSH команды
    $pushOutput = git -c core.sshCommand="ssh -i `"$SSH_KEY`" -o StrictHostKeyChecking=accept-new" push production main --force 2>&1
    $pushExitCode = $LASTEXITCODE
    
    if ($pushExitCode -ne 0) {
        Write-Host "ОШИБКА при отправке на сервер!" -ForegroundColor Red
        Write-Host "Вывод команды:" -ForegroundColor Yellow
        Write-Host $pushOutput -ForegroundColor Red
        Write-Host ""
        Write-Host "Проверьте:" -ForegroundColor Yellow
        Write-Host "  1. SSH ключ добавлен на сервер: $SSH_KEY.pub" -ForegroundColor Yellow
        Write-Host "  2. Публичный ключ добавлен в ~/.ssh/authorized_keys на сервере" -ForegroundColor Yellow
        Write-Host "  3. Права на ключ: icacls `"$SSH_KEY`" /inheritance:r /grant:r `"$env:USERNAME:R`"" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Для добавления ключа на сервер выполните:" -ForegroundColor Cyan
        Write-Host "  type $SSH_KEY.pub" -ForegroundColor Cyan
        Write-Host "  Скопируйте вывод и на сервере выполните:" -ForegroundColor Cyan
        Write-Host "    mkdir -p ~/.ssh && echo 'ваш_ключ' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" -ForegroundColor Cyan
        throw "Ошибка git push"
    }
    
    Write-Host "Отправка выполнена успешно." -ForegroundColor Green
    
    # Выполняем деплой через SSH (hook не выполняется автоматически при push в обычный репозиторий)
    Write-Host "Выполнение деплоя на сервере..." -ForegroundColor Gray
    $deployCmd = "cd $WWW_ROOT && mkdir -p $WWW_ROOT/staging && export GIT_DIR=$WWW_ROOT/.git && export GIT_WORK_TREE=$WWW_ROOT/staging && git checkout -f main && unset GIT_DIR && unset GIT_WORK_TREE && rsync -av --delete --include='index.html' --include='*.html' --include='*.css' --include='*.js' --include='*.jpg' --include='*.jpeg' --include='*.png' --include='*.gif' --include='*.svg' --include='*.ico' --include='*.woff' --include='*.woff2' --include='*.ttf' --include='*.eot' --exclude='deploy.ps1' --exclude='nginx_*.conf' --exclude='post-receive' --exclude='README.md' --exclude='DEPLOY_GUIDE.md' --exclude='SSL/' --exclude='*.sh' --exclude='*' $WWW_ROOT/staging/ $WWW_ROOT/public_html/ 2>/dev/null || cp $WWW_ROOT/staging/index.html $WWW_ROOT/public_html/ 2>/dev/null || true && chown -R http:http $WWW_ROOT/public_html && chmod -R 755 $WWW_ROOT/public_html && rm -rf $WWW_ROOT/staging"
    $deployResult = ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new $SERVER $deployCmd 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Деплой на сервере выполнен успешно." -ForegroundColor Green
    } else {
        Write-Host "ВНИМАНИЕ: Деплой выполнился с ошибкой!" -ForegroundColor Yellow
        Write-Host $deployResult -ForegroundColor Yellow
    }
}

# Функция для отправки в GitHub
function Deploy-ToGitHub {
    Write-Host "Отправка изменений в GitHub..." -ForegroundColor Yellow
    
    # Проверяем наличие remote для GitHub
    $remotes = git remote
    $githubRemote = $null
    
    # Ищем существующий GitHub remote
    foreach ($remote in $remotes) {
        $url = git remote get-url $remote 2>&1
        if ($url -match "github.com.*tg-text-ru") {
            $githubRemote = $remote
            break
        }
    }
    
    # Если нет GitHub remote, добавляем origin
    if (-not $githubRemote) {
        $githubUrl = "https://github.com/hb431147-ctrl/tg-text-ru.git"
        if ($remotes -contains "origin") {
            git remote set-url origin $githubUrl 2>&1 | Out-Null
        } else {
            git remote add origin $githubUrl 2>&1 | Out-Null
        }
        $githubRemote = "origin"
    }
    
    # Отправляем в GitHub
    git push $githubRemote main 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Изменения отправлены в GitHub." -ForegroundColor Green
    } else {
        Write-Host "ВНИМАНИЕ: Не удалось отправить в GitHub (проверьте аутентификацию)." -ForegroundColor Yellow
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

# Отправка в GitHub после успешного деплоя на сервер
Deploy-ToGitHub

Write-Host "=== Деплой завершен успешно! ===" -ForegroundColor Green


