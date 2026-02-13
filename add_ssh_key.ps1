# Скрипт для автоматического добавления SSH ключа на сервер
$SERVER = "root@45.153.70.209"
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa"
$SSH_PUB_KEY = "$SSH_KEY.pub"

Write-Host "=== Добавление SSH ключа на сервер ===" -ForegroundColor Green

if (-not (Test-Path $SSH_PUB_KEY)) {
    Write-Host "ОШИБКА: Публичный ключ не найден: $SSH_PUB_KEY" -ForegroundColor Red
    exit 1
}

$publicKey = Get-Content $SSH_PUB_KEY -Raw
$publicKey = $publicKey.Trim()

Write-Host "Публичный ключ:" -ForegroundColor Cyan
Write-Host $publicKey -ForegroundColor Gray
Write-Host ""

Write-Host "Попытка добавления ключа через SSH..." -ForegroundColor Yellow
Write-Host "Введите пароль root для сервера (если потребуется):" -ForegroundColor Cyan
Write-Host ""

# Создаем временный файл с командами
$tempFile = [System.IO.Path]::GetTempFileName()
$commands = @"
mkdir -p ~/.ssh
echo '$publicKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
"@

$commands | Out-File -FilePath $tempFile -Encoding ASCII -NoNewline

# Выполняем команды через SSH
Write-Host "Выполнение команд на сервере..." -ForegroundColor Gray
$result = Get-Content $tempFile | ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new $SERVER "bash" 2>&1

Remove-Item $tempFile -ErrorAction SilentlyContinue

Write-Host "Команды выполнены!" -ForegroundColor Green

# Проверяем подключение
Write-Host ""
Write-Host "Проверка SSH подключения..." -ForegroundColor Yellow
$testResult = ssh -i $SSH_KEY -o ConnectTimeout=5 $SERVER "echo SSH_TEST_OK" 2>&1

if ($LASTEXITCODE -eq 0 -and $testResult -match "SSH_TEST_OK") {
    Write-Host "SSH подключение работает!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Теперь можно запустить деплой:" -ForegroundColor Cyan
    Write-Host "  .\deploy.ps1" -ForegroundColor White
} else {
    Write-Host "SSH подключение еще не работает" -ForegroundColor Red
    Write-Host "Вывод: $testResult" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Добавьте ключ вручную:" -ForegroundColor Yellow
    Write-Host "1. Подключитесь: ssh $SERVER" -ForegroundColor Cyan
    Write-Host "2. Выполните на сервере:" -ForegroundColor Cyan
    Write-Host "   mkdir -p ~/.ssh" -ForegroundColor White
    $keyLine = "   echo '$publicKey' >> ~/.ssh/authorized_keys"
    Write-Host $keyLine -ForegroundColor White
    Write-Host "   chmod 600 ~/.ssh/authorized_keys" -ForegroundColor White
    Write-Host "   chmod 700 ~/.ssh" -ForegroundColor White
}
