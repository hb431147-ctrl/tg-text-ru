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

    Write-Host "Push OK. Deploy runs on server via post-receive hook." -ForegroundColor Green
}

function Deploy-Frontend {
    # Build React locally and upload to server (server-side build often fails in hook)
    if (-not (Test-Path "package.json")) { return }
    Write-Host "Building React locally..." -ForegroundColor Yellow
    npm run build 2>&1 | Out-Null
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
Deploy-Frontend
Deploy-ToGitHub

Write-Host "=== Deploy finished ===" -ForegroundColor Green
Write-Host "Site: https://$DOMAIN" -ForegroundColor Cyan
