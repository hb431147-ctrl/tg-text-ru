# Скрипт для создания SSH ключа для tg-text.ru
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa_tg_text"
$EMAIL = "hb431147@yandex.ru"

Write-Host "=== Создание SSH ключа для tg-text.ru ===" -ForegroundColor Green
Write-Host ""

if (Test-Path $SSH_KEY) {
    Write-Host "Ключ уже существует: $SSH_KEY" -ForegroundColor Yellow
    $overwrite = Read-Host "Перезаписать? (y/n)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "Отменено." -ForegroundColor Gray
        exit 0
    }
    Remove-Item $SSH_KEY -ErrorAction SilentlyContinue
    Remove-Item "$SSH_KEY.pub" -ErrorAction SilentlyContinue
}

Write-Host "Создание ключа..." -ForegroundColor Cyan
ssh-keygen -t rsa -b 4096 -f $SSH_KEY -C $EMAIL -N '""' -q

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Ключ успешно создан!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Публичный ключ:" -ForegroundColor Cyan
    $pubKey = Get-Content "$SSH_KEY.pub" -Raw
    Write-Host $pubKey.Trim() -ForegroundColor White
    Write-Host ""
    Write-Host "Добавьте этот ключ на сервер:" -ForegroundColor Yellow
    Write-Host "  ssh root@45.153.70.209" -ForegroundColor White
    Write-Host "  echo '$($pubKey.Trim())' >> ~/.ssh/authorized_keys" -ForegroundColor White
    Write-Host "  chmod 600 ~/.ssh/authorized_keys" -ForegroundColor White
} else {
    Write-Host "✗ Ошибка при создании ключа!" -ForegroundColor Red
    exit 1
}

