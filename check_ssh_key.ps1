# Скрипт для проверки SSH ключей
Write-Host "=== Проверка SSH ключей ===" -ForegroundColor Green
Write-Host ""

$SERVER = "root@45.153.70.209"

# Проверяем существующие ключи
Write-Host "Локальные SSH ключи:" -ForegroundColor Cyan
Get-ChildItem "$env:USERPROFILE\.ssh\id_*" -File | Where-Object { $_.Name -notlike "*.pub" } | ForEach-Object {
    $keyName = $_.Name
    $pubKeyPath = "$($_.FullName).pub"
    
    Write-Host ""
    Write-Host "Приватный ключ: $keyName" -ForegroundColor Yellow
    if (Test-Path $pubKeyPath) {
        $pubKey = Get-Content $pubKeyPath -Raw
        Write-Host "Публичный ключ:" -ForegroundColor Gray
        Write-Host $pubKey.Trim() -ForegroundColor White
        
        # Пробуем подключиться
        Write-Host ""
        Write-Host "Тест подключения с этим ключом..." -ForegroundColor Gray
        $testResult = ssh -i $_.FullName -o ConnectTimeout=5 -o StrictHostKeyChecking=no $SERVER "echo SSH_OK" 2>&1
        
        if ($testResult -match "SSH_OK") {
            Write-Host "✓ Подключение работает с ключом: $keyName" -ForegroundColor Green
            Write-Host ""
            Write-Host "Этот ключ можно использовать для деплоя!" -ForegroundColor Green
        } else {
            Write-Host "✗ Подключение не работает с ключом: $keyName" -ForegroundColor Red
            Write-Host "Вывод: $testResult" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "=== ИНСТРУКЦИЯ ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "На сервере должен быть публичный ключ, соответствующий одному из ваших приватных ключей." -ForegroundColor Cyan
Write-Host ""
Write-Host "Если ни один ключ не работает:" -ForegroundColor Yellow
Write-Host "1. Подключитесь к серверу: ssh root@45.153.70.209" -ForegroundColor White
Write-Host "2. Проверьте ключи на сервере: cat ~/.ssh/authorized_keys" -ForegroundColor White
Write-Host "3. Сравните с локальными публичными ключами выше" -ForegroundColor White
Write-Host "4. Добавьте нужный публичный ключ на сервер" -ForegroundColor White

