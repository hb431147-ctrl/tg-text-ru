# Deploy to server (git push -> post-receive hook)
# Requires: Git, SSH key (create_ssh_key.ps1), post-receive on server.
# Usage: .\deploy.ps1
# Bot only: .\deploy_bot_update.ps1

param(
    [switch]$RollbackBack,
    [switch]$RollbackForward
)

$SERVER = "root@45.153.70.209"
$DOMAIN = "tg-text.ru"
$WWW_ROOT = "/var/www/$DOMAIN"
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa_tg_text"

if (-not (Test-Path $SSH_KEY)) {
    Write-Host "ERROR: SSH key not found: $SSH_KEY" -ForegroundColor Red
    Write-Host "Create key: .\create_ssh_key.ps1" -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Git not installed!" -ForegroundColor Red
    exit 1
}

function Rollback-Back {
    Write-Host "=== Rollback one commit ===" -ForegroundColor Yellow
    if (-not (Test-Path ".git")) {
        Write-Host "ERROR: Not a Git repo!" -ForegroundColor Red
        exit 1
    }
    $commits = git log --oneline --all
    if ($commits.Count -lt 2) {
        Write-Host "ERROR: Not enough commits!" -ForegroundColor Red
        exit 1
    }
    $previousCommit = ($commits[1] -split ' ')[0]
    Write-Host "Rollback to: $previousCommit" -ForegroundColor Cyan
    git reset --hard $previousCommit
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Rollback failed!" -ForegroundColor Red
        exit 1
    }
    Deploy-ToServer
    Deploy-ToGitHub
    Write-Host "=== Rollback done ===" -ForegroundColor Green
}

function Rollback-Forward {
    Write-Host "=== Rollback forward ===" -ForegroundColor Yellow
    if (-not (Test-Path ".git")) {
        Write-Host "ERROR: Not a Git repo!" -ForegroundColor Red
        exit 1
    }
    $previousHead = git rev-parse HEAD@{1} 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Previous HEAD not found!" -ForegroundColor Red
        exit 1
    }
    Write-Host "Reset to: $previousHead" -ForegroundColor Cyan
    git reset --hard $previousHead
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Rollback failed!" -ForegroundColor Red
        exit 1
    }
    Deploy-ToServer
    Deploy-ToGitHub
    Write-Host "=== Rollback done ===" -ForegroundColor Green
}

function Deploy-ToServer {
    Write-Host "Pushing to server..." -ForegroundColor Yellow
    if (-not (Test-Path "app.js")) {
        Write-Host "WARNING: app.js not found!" -ForegroundColor Yellow
    }
    if (-not (Test-Path "nginx_tg-text.ru.conf")) {
        Write-Host "WARNING: nginx_tg-text.ru.conf not found!" -ForegroundColor Yellow
    }
    if (-not (Test-Path "post-receive")) {
        Write-Host "WARNING: post-receive not found!" -ForegroundColor Yellow
    }

    $remotes = git remote
    if ($remotes -notcontains "production") {
        git remote add production "$SERVER`:$WWW_ROOT"
    } else {
        git remote set-url production "$SERVER`:$WWW_ROOT"
    }

    $env:GIT_SSH_COMMAND = "ssh -i `"$SSH_KEY`" -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"
    $pushOutput = git push production main --force 2>&1
    Remove-Item Env:\GIT_SSH_COMMAND -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Push to server failed!" -ForegroundColor Red
        Write-Host $pushOutput -ForegroundColor Red
        Write-Host "Add your key to server: type $SSH_KEY.pub then ssh root@45.153.70.209 and add to authorized_keys" -ForegroundColor Yellow
        throw "git push failed"
    }

    Write-Host "Push OK." -ForegroundColor Green
}

function Deploy-ApiOnServer {
    # Явно копируем app.js, bot.js и unit-файлы на сервер и перезапускаем сервисы — чтобы точно запускались актуальные файлы
    $apiDir = "$WWW_ROOT/api"
    Write-Host "Uploading API and services..." -ForegroundColor Yellow
    scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new app.js "${SERVER}:${apiDir}/" 2>&1 | Out-Null
    if (Test-Path "bot.js") {
        scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new bot.js "${SERVER}:${apiDir}/" 2>&1 | Out-Null
    }
    scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new text-processor.service "${SERVER}:/etc/systemd/system/" 2>&1 | Out-Null
    if (Test-Path "telegram-bot.service") {
        scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new telegram-bot.service "${SERVER}:/etc/systemd/system/" 2>&1 | Out-Null
    }
    if (Test-Path "nginx_tg-text.ru.conf") {
        scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new nginx_tg-text.ru.conf "${SERVER}:/etc/nginx/conf.d/tg-text.ru.conf" 2>&1 | Out-Null
    }
    $restart = "systemctl daemon-reload; systemctl restart text-processor; systemctl restart telegram-bot 2>/dev/null; nginx -t 2>/dev/null && systemctl reload nginx; echo API_OK"
    $out = ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new $SERVER $restart 2>&1
    if ($out -match "API_OK") {
        Write-Host "API and services updated and restarted." -ForegroundColor Green
    }
}

function Deploy-Frontend {
    # Build React locally and upload to server (server-side build often fails in hook)
    if (-not (Test-Path "package.json")) { return }
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npmCmd) {
        $npmPath = "${env:ProgramFiles}\nodejs\npm.cmd"
        if (Test-Path $npmPath) { $npmCmd = $npmPath }
    }
    if (-not $npmCmd) {
        Write-Host "WARNING: npm not found. Frontend not uploaded." -ForegroundColor Yellow
        Write-Host "  Option 1: Install Node.js (https://nodejs.org), then run deploy again." -ForegroundColor Gray
        Write-Host "  Option 2: On server run: ssh root@45.153.70.209 'apt update; apt install -y nodejs npm'" -ForegroundColor Gray
        return
    }
    Write-Host "Building React locally..." -ForegroundColor Yellow
    & $npmCmd run build 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: npm run build failed, skipping frontend upload" -ForegroundColor Yellow
        return
    }
    if (-not (Test-Path "dist\index.html")) {
        Write-Host "WARNING: dist\index.html not found, skipping frontend upload" -ForegroundColor Yellow
        return
    }
    $pub = "${WWW_ROOT}/public_html"
    Write-Host "Uploading dist to server..." -ForegroundColor Yellow
    $scp = "scp -i `"$SSH_KEY`" -o StrictHostKeyChecking=accept-new -r dist\* ${SERVER}:${pub}/"
    Invoke-Expression $scp
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: SCP upload failed" -ForegroundColor Yellow
        return
    }
    $fix = "chown -R www-data:www-data $pub; find $pub -type d -exec chmod 755 {} \; ; find $pub -type f -exec chmod 644 {} \;"
    ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new $SERVER $fix 2>&1 | Out-Null
    Write-Host "Frontend uploaded." -ForegroundColor Green
}

function Deploy-FrontendOnServer {
    # Загружаем исходники с вашего ПК на сервер и собираем там — чтобы точно шла актуальная версия
    if (-not (Test-Path "package.json") -or -not (Test-Path "src")) { return }
    Write-Host "Uploading frontend source and building on server..." -ForegroundColor Yellow
    $buildDir = "$WWW_ROOT/build_tmp"
    ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new $SERVER "rm -rf $buildDir; mkdir -p $buildDir" 2>&1 | Out-Null
    scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new -r index.html package.json vite.config.js src "${SERVER}:${buildDir}/" 2>&1 | Out-Null
    if (Test-Path "package-lock.json") {
        scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new package-lock.json "${SERVER}:${buildDir}/" 2>&1 | Out-Null
    }
    $cmd = "cd $buildDir && export PATH=/usr/bin:/bin && npm install --production=false && npm run build && rm -rf $WWW_ROOT/public_html/* && cp -r dist/* $WWW_ROOT/public_html/ && chown -R www-data:www-data $WWW_ROOT/public_html && cd / && rm -rf $buildDir && echo DEPLOY_OK"
    $out = ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new $SERVER $cmd 2>&1
    if ($out -match "DEPLOY_OK") {
        Write-Host "Frontend (from your PC) built and deployed on server." -ForegroundColor Green
    } else {
        Write-Host $out -ForegroundColor Gray
        Write-Host "WARNING: Server build failed. Check output above." -ForegroundColor Yellow
    }
}

function Deploy-ToGitHub {
    Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
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
        Write-Host "GitHub push OK." -ForegroundColor Green
    }
}

if ($RollbackBack) {
    Rollback-Back
    exit 0
}
if ($RollbackForward) {
    Rollback-Forward
    exit 0
}

Write-Host "=== Deploy ===" -ForegroundColor Green

if (-not (Test-Path ".git")) {
    Write-Host "Init Git..." -ForegroundColor Yellow
    git init
    git branch -M main
}

Write-Host "Adding files..." -ForegroundColor Yellow
git add .
$status = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($status)) {
    git commit -m "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

Deploy-ToServer
Deploy-ApiOnServer
Deploy-Frontend
Deploy-FrontendOnServer
Deploy-ToGitHub

Write-Host "=== Deploy finished ===" -ForegroundColor Green
Write-Host "Site: https://$DOMAIN" -ForegroundColor Cyan
