# Скрипт для добавления SSH ключа на сервер
$SERVER = "root@45.153.70.209"

# Используем ключ для tg-text.ru если он существует, иначе используем дефолтный
$SSH_KEY_TG = "$env:USERPROFILE\.ssh\id_rsa_tg_text"
$SSH_KEY_DEFAULT = "$env:USERPROFILE\.ssh\id_rsa"

if (Test-Path $SSH_KEY_TG) {
    $SSH_KEY = $SSH_KEY_TG
    Write-Host "Используется SSH ключ для tg-text.ru" -ForegroundColor Gray
} else {
    $SSH_KEY = $SSH_KEY_DEFAULT
    Write-Host "Используется дефолтный SSH ключ" -ForegroundColor Gray
}

$SSH_PUB_KEY = "$SSH_KEY.pub"

Write-Host "=== Добавление SSH ключа на сервер ===" -ForegroundColor Green
Write-Host ""

if (-not (Test-Path $SSH_PUB_KEY)) {
    Write-Host "ОШИБКА: Публичный ключ не найден: $SSH_PUB_KEY" -ForegroundColor Red
    exit 1
}

$publicKey = Get-Content $SSH_PUB_KEY -Raw
$publicKey = $publicKey.Trim()

Write-Host "Ваш публичный SSH ключ:" -ForegroundColor Cyan
Write-Host $publicKey -ForegroundColor White
Write-Host ""

Write-Host "=== ИНСТРУКЦИЯ ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Подключитесь к серверу (используйте пароль root):" -ForegroundColor Cyan
Write-Host "   ssh root@45.153.70.209" -ForegroundColor White
Write-Host ""
Write-Host "2. На сервере выполните следующие команды:" -ForegroundColor Cyan
Write-Host "   mkdir -p ~/.ssh" -ForegroundColor White
Write-Host "   chmod 700 ~/.ssh" -ForegroundColor White
Write-Host ""
Write-Host "3. Добавьте ваш публичный ключ (скопируйте ключ выше):" -ForegroundColor Cyan
Write-Host "   nano ~/.ssh/authorized_keys" -ForegroundColor White
Write-Host "   (Вставьте ключ, сохраните: Ctrl+O, Enter, Ctrl+X)" -ForegroundColor Gray
Write-Host ""
Write-Host "   ИЛИ выполните команду:" -ForegroundColor Cyan
Write-Host "   echo '$publicKey' >> ~/.ssh/authorized_keys" -ForegroundColor White
Write-Host ""
Write-Host "4. Установите правильные права:" -ForegroundColor Cyan
Write-Host "   chmod 600 ~/.ssh/authorized_keys" -ForegroundColor White
Write-Host ""
Write-Host "5. Проверьте подключение (из PowerShell):" -ForegroundColor Cyan
Write-Host "   ssh -i $SSH_KEY root@45.153.70.209 'echo Connection OK'" -ForegroundColor White
Write-Host ""

# Пробуем автоматически добавить через ssh-copy-id (если доступен)
$sshCopyId = Get-Command ssh-copy-id -ErrorAction SilentlyContinue
if ($null -ne $sshCopyId) {
    Write-Host "Попытка автоматического добавления через ssh-copy-id..." -ForegroundColor Yellow
    Write-Host "Введите пароль root при запросе:" -ForegroundColor Cyan
    ssh-copy-id -i $SSH_PUB_KEY $SERVER
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Ключ успешно добавлен!" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "После добавления ключа запустите деплой:" -ForegroundColor Cyan
Write-Host "  .\deploy.ps1" -ForegroundColor White
