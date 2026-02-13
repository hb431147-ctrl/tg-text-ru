# PowerShell скрипт для отката проекта на одну версию назад
# Использование: .\rollback.ps1
# Или: powershell -ExecutionPolicy Bypass -File .\rollback.ps1

$SERVER = "root@45.153.70.209"
$DOMAIN = "tg-text.ru"
$WWW_ROOT = "/var/www/$DOMAIN"

Write-Host "=== Откат проекта на одну версию назад ===" -ForegroundColor Yellow

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
$currentCommit = ssh "$SERVER" "cd $WWW_ROOT && git rev-parse HEAD" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ОШИБКА: Не удалось подключиться к серверу или получить информацию о коммите" -ForegroundColor Red
    exit 1
}

Write-Host "Текущий коммит на сервере: $currentCommit" -ForegroundColor Cyan

# Получаем предыдущий коммит
Write-Host "Получение предыдущего коммита..." -ForegroundColor Yellow
$previousCommit = ssh "$SERVER" "cd $WWW_ROOT && git rev-parse HEAD~1" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ОШИБКА: Не удалось получить предыдущий коммит. Возможно, это первый коммит." -ForegroundColor Red
    exit 1
}

Write-Host "Предыдущий коммит: $previousCommit" -ForegroundColor Cyan

# Подтверждение
Write-Host ""
Write-Host "ВНИМАНИЕ: Вы собираетесь откатить проект на сервере на одну версию назад!" -ForegroundColor Red
Write-Host "Текущий коммит: $currentCommit" -ForegroundColor Yellow
Write-Host "Будет установлен коммит: $previousCommit" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Продолжить? (y/N)"

if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Откат отменен." -ForegroundColor Yellow
    exit 0
}

# Выполняем откат на сервере
Write-Host "Выполнение отката на сервере..." -ForegroundColor Yellow

$rollbackScript = @"
set -e

DOMAIN="tg-text.ru"
WWW_ROOT="/var/www/\${DOMAIN}"
DEPLOY_DIR="\${WWW_ROOT}/public_html"
STAGING_DIR="\${WWW_ROOT}/staging"
NGINX_USER="http"
GIT_DIR="\${WWW_ROOT}/.git"

cd \${WWW_ROOT}

# Откатываем репозиторий на один коммит назад
echo "Откат репозитория на один коммит назад..."
git reset --hard HEAD~1

# Создаем staging директорию
mkdir -p \${STAGING_DIR}

# Делаем checkout предыдущей версии в staging директорию
export GIT_DIR=\${GIT_DIR}
export GIT_WORK_TREE=\${STAGING_DIR}
git checkout -f main 2>/dev/null || git checkout -f
unset GIT_DIR
unset GIT_WORK_TREE

# Проверяем наличие index.html
if [ ! -f "\${STAGING_DIR}/index.html" ]; then
    echo "ОШИБКА: index.html не найден в предыдущей версии!"
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

echo "Откат завершен успешно!"
"@

$rollbackScript | ssh "$SERVER" "bash -s"

if ($LASTEXITCODE -eq 0) {
    Write-Host "=== Откат завершен успешно! ===" -ForegroundColor Green
    Write-Host "Проверьте сайт: https://$DOMAIN" -ForegroundColor Cyan
    
    # Показываем информацию о текущем коммите
    $newCommit = ssh "$SERVER" "cd $WWW_ROOT && git rev-parse HEAD && git log -1 --oneline"
    Write-Host "Текущий коммит на сервере:" -ForegroundColor Cyan
    Write-Host $newCommit -ForegroundColor White
} else {
    Write-Host "ОШИБКА при выполнении отката на сервере!" -ForegroundColor Red
    exit 1
}

