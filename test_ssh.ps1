# Скрипт для тестирования SSH подключения
$SERVER = "root@45.153.70.209"
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa"
$SSH_PUB_KEY = "$SSH_KEY.pub"

Write-Host "=== Тестирование SSH подключения ===" -ForegroundColor Green
Write-Host ""

# Показываем ключ
Write-Host "Публичный ключ на локальной машине:" -ForegroundColor Cyan
$localKey = Get-Content $SSH_PUB_KEY -Raw
Write-Host $localKey.Trim() -ForegroundColor White
Write-Host ""

# Пробуем подключиться разными способами
Write-Host "Тест 1: Подключение с явным указанием ключа..." -ForegroundColor Yellow
$test1 = ssh -i $SSH_KEY -v $SERVER "echo TEST_OK" 2>&1 | Select-String -Pattern "Permission denied|TEST_OK|Offering|Authentications"
Write-Host $test1 -ForegroundColor Gray

Write-Host ""
Write-Host "Тест 2: Подключение через SSH config..." -ForegroundColor Yellow
$test2 = ssh -v $SERVER "echo TEST_OK" 2>&1 | Select-String -Pattern "Permission denied|TEST_OK|Offering|Authentications"
Write-Host $test2 -ForegroundColor Gray

Write-Host ""
Write-Host "=== РЕКОМЕНДАЦИИ ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "Если подключение не работает, проверьте на сервере:" -ForegroundColor Cyan
Write-Host "1. Содержимое ~/.ssh/authorized_keys:" -ForegroundColor White
Write-Host "   cat ~/.ssh/authorized_keys" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Права на файлы:" -ForegroundColor White
Write-Host "   ls -la ~/.ssh/" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Должно быть:" -ForegroundColor White
Write-Host "   ~/.ssh - 700 (drwx------)" -ForegroundColor Gray
Write-Host "   ~/.ssh/authorized_keys - 600 (-rw-------)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Проверьте логи SSH на сервере:" -ForegroundColor White
Write-Host "   tail -20 /var/log/auth.log" -ForegroundColor Gray
Write-Host ""
Write-Host "ВАЖНО: Убедитесь, что ключ на сервере совпадает с локальным!" -ForegroundColor Yellow

