# PowerShell скрипт для деплоя на сервер
# Использование: 
#   .\deploy.ps1              - обычный деплой
#   .\deploy.ps1 -RollbackBack    - откат на одну версию назад
#   .\deploy.ps1 -RollbackForward - откат на одну версию вперед

param(
    [switch]$RollbackBack,
    [switch]$RollbackForward
)

$SERVER = "root@45.153.70.209"
$DOMAIN = "tg-text.ru"
$WWW_ROOT = "/var/www/$DOMAIN"
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa_tg_text"

# Проверка наличия SSH ключа
if (-not (Test-Path $SSH_KEY)) {
    Write-Host "ОШИБКА: SSH ключ не найден: $SSH_KEY" -ForegroundColor Red
    Write-Host "Создайте ключ: .\create_ssh_key.ps1" -ForegroundColor Yellow
    exit 1
}

# Проверка наличия Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ОШИБКА: Git не установлен!" -ForegroundColor Red
    exit 1
}

# Функция для отката назад
function Rollback-Back {
    Write-Host "=== Откат на одну версию назад ===" -ForegroundColor Yellow
    
    if (-not (Test-Path ".git")) {
        Write-Host "ОШИБКА: Git репозиторий не инициализирован!" -ForegroundColor Red
        exit 1
    }
    
    $commits = git log --oneline --all
    if ($commits.Count -lt 2) {
        Write-Host "ОШИБКА: Недостаточно коммитов для отката!" -ForegroundColor Red
        exit 1
    }
    
    $previousCommit = ($commits[1] -split ' ')[0]
    Write-Host "Откат к коммиту: $previousCommit" -ForegroundColor Cyan
    
    git reset --hard $previousCommit
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ОШИБКА: Не удалось выполнить откат!" -ForegroundColor Red
        exit 1
    }
    
    Deploy-ToServer
    Deploy-ToGitHub
    Write-Host "=== Откат завершен успешно! ===" -ForegroundColor Green
}

# Функция для отката вперед
function Rollback-Forward {
    Write-Host "=== Откат на одну версию вперед ===" -ForegroundColor Yellow
    
    if (-not (Test-Path ".git")) {
        Write-Host "ОШИБКА: Git репозиторий не инициализирован!" -ForegroundColor Red
        exit 1
    }
    
    $previousHead = git rev-parse HEAD@{1} 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ОШИБКА: Не найдена предыдущая версия!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Возврат к коммиту: $previousHead" -ForegroundColor Cyan
    git reset --hard $previousHead
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ОШИБКА: Не удалось выполнить откат!" -ForegroundColor Red
        exit 1
    }
    
    Deploy-ToServer
    Deploy-ToGitHub
    Write-Host "=== Откат завершен успешно! ===" -ForegroundColor Green
}

# Функция для отправки на сервер
function Deploy-ToServer {
    Write-Host "Отправка на сервер..." -ForegroundColor Yellow
    
    # Добавление/обновление remote
    $remotes = git remote
    if ($remotes -notcontains "production") {
        git remote add production "$SERVER`:$WWW_ROOT"
    } else {
        git remote set-url production "$SERVER`:$WWW_ROOT"
    }
    
    # Push на сервер
    $env:GIT_SSH_COMMAND = "ssh -i `"$SSH_KEY`" -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"
    $pushOutput = git push production main --force 2>&1
    Remove-Item Env:\GIT_SSH_COMMAND -ErrorAction SilentlyContinue
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ОШИБКА при отправке на сервер!" -ForegroundColor Red
        Write-Host $pushOutput -ForegroundColor Red
        Write-Host ""
        Write-Host "Проверьте SSH ключ на сервере:" -ForegroundColor Yellow
        Write-Host "  type $SSH_KEY.pub" -ForegroundColor White
        Write-Host "  ssh root@45.153.70.209" -ForegroundColor White
        Write-Host "  echo 'ваш_ключ' >> ~/.ssh/authorized_keys" -ForegroundColor White
        throw "Ошибка git push"
    }
    
    Write-Host "Отправка выполнена успешно." -ForegroundColor Green
    
    # Деплой на сервере
    Write-Host "Выполнение деплоя на сервере..." -ForegroundColor Gray
    
    # Используем git archive для извлечения файлов из bare репозитория
    $deployCmd = "cd $WWW_ROOT && mkdir -p staging && (git archive --format=tar main 2>/dev/null | tar -x -C staging 2>/dev/null || git archive --format=tar HEAD 2>/dev/null | tar -x -C staging 2>/dev/null) && rsync -av --delete --include='index.html' --include='*.html' --include='*.css' --include='*.js' --include='*.jpg' --include='*.jpeg' --include='*.png' --include='*.gif' --include='*.svg' --include='*.ico' --include='*.woff' --include='*.woff2' --include='*.ttf' --include='*.eot' --exclude='deploy.ps1' --exclude='nginx_*.conf' --exclude='post-receive' --exclude='README.md' --exclude='*.md' --exclude='SSL/' --exclude='*.sh' --exclude='*.sql' --exclude='*' staging/ public_html/ 2>&1 && chown -R www-data:www-data public_html && chmod -R 755 public_html && rm -rf staging"
    
    $deployResult = ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new $SERVER $deployCmd 2>&1
    
    # Если git archive не сработал, копируем файлы напрямую
    if ($LASTEXITCODE -ne 0 -or $deployResult -match "error|fatal|failed") {
        Write-Host "Копирование файлов напрямую (альтернативный метод)..." -ForegroundColor Yellow
        scp -i $SSH_KEY index.html style.css "${SERVER}:${WWW_ROOT}/public_html/" 2>&1 | Out-Null
        ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new $SERVER "chown -R www-data:www-data ${WWW_ROOT}/public_html && chmod -R 755 ${WWW_ROOT}/public_html" 2>&1 | Out-Null
        Write-Host "Файлы скопированы напрямую." -ForegroundColor Green
    } else {
        Write-Host "Деплой на сервере выполнен успешно." -ForegroundColor Green
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Деплой на сервере выполнен успешно." -ForegroundColor Green
    }
}

# Функция для отправки в GitHub
function Deploy-ToGitHub {
    Write-Host "Отправка в GitHub..." -ForegroundColor Yellow
    
    $remotes = git remote
    $githubRemote = $null
    
    foreach ($remote in $remotes) {
        $url = git remote get-url $remote 2>&1
        if ($url -match "github.com.*tg-text-ru") {
            $githubRemote = $remote
            break
        }
    }
    
    if (-not $githubRemote) {
        if ($remotes -contains "origin") {
            git remote set-url origin "https://github.com/hb431147-ctrl/tg-text-ru.git" 2>&1 | Out-Null
        } else {
            git remote add origin "https://github.com/hb431147-ctrl/tg-text-ru.git" 2>&1 | Out-Null
        }
        $githubRemote = "origin"
    }
    
    git push $githubRemote main 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Изменения отправлены в GitHub." -ForegroundColor Green
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
Write-Host "=== Деплой на сервер ===" -ForegroundColor Green

if (-not (Test-Path "index.html")) {
    Write-Host "ОШИБКА: index.html не найден!" -ForegroundColor Red
    exit 1
}

# Инициализация Git если нужно
if (-not (Test-Path ".git")) {
    Write-Host "Инициализация Git репозитория..." -ForegroundColor Yellow
    git init
    git branch -M main
}

# Добавление и коммит
Write-Host "Добавление файлов в Git..." -ForegroundColor Yellow
git add .
$status = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($status)) {
    git commit -m "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

# Деплой
Deploy-ToServer
Deploy-ToGitHub

Write-Host "=== Деплой завершен успешно! ===" -ForegroundColor Green
Write-Host "Проверьте сайт: https://$DOMAIN" -ForegroundColor Cyan
