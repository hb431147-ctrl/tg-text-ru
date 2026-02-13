# PowerShell скрипт для обновления проекта на одну версию вперед (если есть)
# Использование: .\forward.ps1
# Или: powershell -ExecutionPolicy Bypass -File .\forward.ps1

$SERVER = "root@45.153.70.209"
$DOMAIN = "tg-text.ru"
$WWW_ROOT = "/var/www/$DOMAIN"

Write-Host "=== Обновление проекта на одну версию вперед ===" -ForegroundColor Cyan

# Проверка наличия Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ОШИБКА: Git не установлен!" -ForegroundColor Red
    exit 1
}

# Проверка наличия remote
$remotes = git remote
if ($remotes -notcontains "production") {
    Write-Host "ОШИБКА: Remote 'production' не найден!" -ForegroundColor Red
    Write-Host "Добавьте remote: git remote add production $SERVER`:$WWW_ROOT" -ForegroundColor Yellow
    exit 1
}

# Получаем текущий коммит на сервере
Write-Host "Проверка текущей версии на сервере..." -ForegroundColor Yellow
$currentCommit = ssh "$SERVER" "cd $WWW_ROOT; git rev-parse HEAD" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ОШИБКА: Не удалось подключиться к серверу или получить информацию о коммите" -ForegroundColor Red
    exit 1
}

Write-Host "Текущий коммит на сервере: $currentCommit" -ForegroundColor Cyan

# Получаем последний коммит из локального репозитория
Write-Host "Проверка последней версии в репозитории..." -ForegroundColor Yellow
$latestCommit = git rev-parse HEAD

Write-Host "Последний коммит в репозитории: $latestCommit" -ForegroundColor Cyan

# Проверяем, есть ли более новая версия
if ($currentCommit -eq $latestCommit) {
    Write-Host "ВНИМАНИЕ: Сервер уже на последней версии!" -ForegroundColor Yellow
    Write-Host "Текущая версия: $currentCommit" -ForegroundColor White
    exit 0
}

# Получаем историю коммитов между текущей и последней версией
Write-Host "Получение истории коммитов..." -ForegroundColor Yellow
$commits = ssh "$SERVER" "cd $WWW_ROOT; git log --oneline $currentCommit..HEAD" 2>&1

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($commits)) {
    Write-Host "ОШИБКА: Не удалось получить историю коммитов или нет новых версий" -ForegroundColor Red
    exit 1
}

# Определяем следующий коммит (первый после текущего)
$nextCommit = ssh "$SERVER" "cd $WWW_ROOT; git rev-parse $currentCommit^0" 2>&1
$nextCommit = ssh "$SERVER" "cd $WWW_ROOT; git log --reverse --oneline $currentCommit..HEAD | head -1 | cut -d' ' -f1" 2>&1

# Если не удалось получить через head, попробуем другой способ
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($nextCommit)) {
    $nextCommit = ssh "$SERVER" "cd $WWW_ROOT; git rev-list --reverse $currentCommit..HEAD | head -1" 2>&1
}

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($nextCommit)) {
    Write-Host "ОШИБКА: Не удалось определить следующую версию" -ForegroundColor Red
    exit 1
}

# Получаем информацию о следующем коммите
$nextCommitInfo = ssh "$SERVER" "cd $WWW_ROOT; git log -1 --oneline $nextCommit" 2>&1

Write-Host ""
Write-Host "Доступные версии для обновления:" -ForegroundColor Green
Write-Host $commits -ForegroundColor White
Write-Host ""
Write-Host "Текущий коммит: $currentCommit" -ForegroundColor Yellow
Write-Host "Следующий коммит: $nextCommit" -ForegroundColor Cyan
Write-Host "Информация: $nextCommitInfo" -ForegroundColor Cyan
Write-Host ""

# Подтверждение
Write-Host "ВНИМАНИЕ: Вы собираетесь обновить проект на сервере на одну версию вперед!" -ForegroundColor Yellow
Write-Host "Текущий коммит: $currentCommit" -ForegroundColor Yellow
Write-Host "Будет установлен коммит: $nextCommit" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Продолжить? (y/N)"

if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Обновление отменено." -ForegroundColor Yellow
    exit 0
}

# Выполняем обновление на сервере
Write-Host "Выполнение обновления на сервере..." -ForegroundColor Yellow

$forwardScript = @"
set -e

DOMAIN="tg-text.ru"
WWW_ROOT="/var/www/\${DOMAIN}"
DEPLOY_DIR="\${WWW_ROOT}/public_html"
STAGING_DIR="\${WWW_ROOT}/staging"
NGINX_USER="http"
GIT_DIR="\${WWW_ROOT}/.git"

cd \${WWW_ROOT}

# Получаем текущий коммит
CURRENT_COMMIT=\$(git rev-parse HEAD)

# Получаем следующий коммит
NEXT_COMMIT=\$(git rev-list --reverse \${CURRENT_COMMIT}..HEAD | head -1)

if [ -z "\$NEXT_COMMIT" ]; then
    echo "ОШИБКА: Не удалось определить следующую версию!"
    exit 1
fi

echo "Обновление с \${CURRENT_COMMIT} на \${NEXT_COMMIT}..."

# Переходим на следующий коммит
git reset --hard \${NEXT_COMMIT}

# Создаем staging директорию
mkdir -p \${STAGING_DIR}

# Делаем checkout следующей версии в staging директорию
export GIT_DIR=\${GIT_DIR}
export GIT_WORK_TREE=\${STAGING_DIR}
git checkout -f main 2>/dev/null || git checkout -f
unset GIT_DIR
unset GIT_WORK_TREE

# Проверяем наличие index.html
if [ ! -f "\${STAGING_DIR}/index.html" ]; then
    echo "ОШИБКА: index.html не найден в следующей версии!"
    exit 1
fi

# Копируем файлы сайта из staging в production атомарно
echo "Копирование файлов сайта..."
rsync -av --delete \\
  --include='index.html' \\
  --include='*.html' \\
  --include='*.css' \\
  --include='*.js' \\
  --include='*.jpg' \\
  --include='*.jpeg' \\
  --include='*.png' \\
  --include='*.gif' \\
  --include='*.svg' \\
  --include='*.ico' \\
  --include='*.woff' \\
  --include='*.woff2' \\
  --include='*.ttf' \\
  --include='*.eot' \\
  --exclude='deploy.ps1' \\
  --exclude='nginx_*.conf' \\
  --exclude='post-receive' \\
  --exclude='README.md' \\
  --exclude='DEPLOY_GUIDE.md' \\
  --exclude='SSL/' \\
  --exclude='*.sh' \\
  \${STAGING_DIR}/ \${DEPLOY_DIR}/ || \\
  (cp \${STAGING_DIR}/index.html \${DEPLOY_DIR}/ 2>/dev/null || true)

# Устанавливаем правильные права
chown -R \${NGINX_USER}:\${NGINX_USER} \${DEPLOY_DIR}
chmod -R 755 \${DEPLOY_DIR}

# Проверяем конфигурацию nginx
echo "Проверка конфигурации nginx..."
nginx -t

# Перезагружаем nginx (graceful reload - без прерывания работы)
echo "Перезагрузка nginx..."
systemctl reload nginx

# Очищаем staging директорию
rm -rf \${STAGING_DIR}

echo "Обновление завершено успешно!"
"@

$forwardScript | ssh "$SERVER" "bash -s"

if ($LASTEXITCODE -eq 0) {
    Write-Host "=== Обновление завершено успешно! ===" -ForegroundColor Green
    Write-Host "Проверьте сайт: https://$DOMAIN" -ForegroundColor Cyan
    
    # Показываем информацию о текущем коммите
    $newCommit = ssh "$SERVER" "cd $WWW_ROOT; git rev-parse HEAD; git log -1 --oneline"
    Write-Host "Текущий коммит на сервере:" -ForegroundColor Cyan
    Write-Host $newCommit -ForegroundColor White
} else {
    Write-Host "ОШИБКА при выполнении обновления на сервере!" -ForegroundColor Red
    exit 1
}

