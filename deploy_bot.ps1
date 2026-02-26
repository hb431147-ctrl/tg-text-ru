# Скрипт для деплоя Telegram бота на сервер
# Использование: .\deploy_bot.ps1

$hostname = "45.153.70.209"
$username = "root"
$password = "wc.D_-X-1qERXt"
$BOT_TOKEN = "8527416853:AAG8EKiBVvaEJYpoYNk6BVOKbjOZlWvv56o"

# Install Posh-SSH module if not available
if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Host "Installing Posh-SSH module..."
    Install-Module -Name Posh-SSH -Force -Scope CurrentUser -SkipPublisherCheck
}

Import-Module Posh-SSH

# Create credentials
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)

Write-Host "=== Деплой Telegram бота на сервер ===" -ForegroundColor Green
Write-Host "Подключение к серверу $hostname..." -ForegroundColor Cyan

try {
    $session = New-SSHSession -ComputerName $hostname -Credential $credential -AcceptKey
    
    if ($session) {
        Write-Host "Подключение установлено!" -ForegroundColor Green
        
        $apiDir = "/var/www/tg-text.ru/api"
        
        # 1. Копируем bot.js на сервер
        Write-Host "`n=== Копирование bot.js на сервер ===" -ForegroundColor Cyan
        $botJsContent = Get-Content "C:\tg\bot.js" -Raw -Encoding UTF8
        $botJsBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($botJsContent))
        $copyBot = Invoke-SSHCommand -SessionId $session.SessionId -Command "echo '$botJsBase64' | base64 -d > $apiDir/bot.js"
        Write-Host "bot.js скопирован" -ForegroundColor Green
        
        # 2. Устанавливаем зависимости
        Write-Host "`n=== Установка зависимостей ===" -ForegroundColor Cyan
        $installDeps = Invoke-SSHCommand -SessionId $session.SessionId -Command "cd $apiDir; npm install node-telegram-bot-api 2>&1"
        Write-Host $installDeps.Output
        
        # 3. Обновляем базу данных
        Write-Host "`n=== Обновление базы данных ===" -ForegroundColor Cyan
        $updateDbContent = Get-Content "C:\tg\update_database_telegram.sql" -Raw -Encoding UTF8
        $updateDbBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($updateDbContent))
        $copyDbScript = Invoke-SSHCommand -SessionId $session.SessionId -Command "echo '$updateDbBase64' | base64 -d > /tmp/update_db.sql"
        Write-Host "SQL скрипт скопирован" -ForegroundColor Green
        
        $updateDb = Invoke-SSHCommand -SessionId $session.SessionId -Command "mysql -u tg_text_user -ptg_text_password_2024 tg_text_db < /tmp/update_db.sql 2>&1"
        Write-Host $updateDb.Output
        Write-Host "База данных обновлена" -ForegroundColor Green
        
        # 4. Копируем и настраиваем systemd сервис
        Write-Host "`n=== Настройка systemd сервиса ===" -ForegroundColor Cyan
        $serviceContent = Get-Content "C:\tg\telegram-bot.service" -Raw -Encoding UTF8
        $serviceBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($serviceContent))
        $copyService = Invoke-SSHCommand -SessionId $session.SessionId -Command "echo '$serviceBase64' | base64 -d > /tmp/telegram-bot.service"
        Write-Host "Файл сервиса скопирован" -ForegroundColor Green
        
        $setupService1 = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo cp /tmp/telegram-bot.service /etc/systemd/system/"
        $setupService2 = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo systemctl daemon-reload"
        $setupService3 = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo systemctl enable telegram-bot"
        Write-Host "Сервис настроен" -ForegroundColor Green
        
        # 5. Останавливаем старый сервис если запущен
        Write-Host "`n=== Остановка старого сервиса ===" -ForegroundColor Cyan
        $stopService = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo systemctl stop telegram-bot 2>&1"
        Write-Host $stopService.Output
        
        # 6. Запускаем сервис
        Write-Host "`n=== Запуск сервиса ===" -ForegroundColor Cyan
        $startService = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo systemctl start telegram-bot"
        Start-Sleep -Seconds 3
        Write-Host "Сервис запущен" -ForegroundColor Green
        
        # 7. Проверяем статус
        Write-Host "`n=== Проверка статуса сервиса ===" -ForegroundColor Cyan
        $status = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo systemctl status telegram-bot --no-pager | head -15"
        Write-Host $status.Output
        
        # 8. Проверяем логи
        Write-Host "`n=== Последние логи ===" -ForegroundColor Cyan
        $logs = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo journalctl -u telegram-bot -n 15 --no-pager"
        Write-Host $logs.Output
        
        # 9. Проверяем что bot.js на месте
        Write-Host "`n=== Проверка файлов ===" -ForegroundColor Cyan
        $checkFiles = Invoke-SSHCommand -SessionId $session.SessionId -Command "ls -lh $apiDir/bot.js"
        Write-Host $checkFiles.Output
        
        # 10. Проверяем что зависимости установлены
        Write-Host "`n=== Проверка зависимостей ===" -ForegroundColor Cyan
        $checkDeps = Invoke-SSHCommand -SessionId $session.SessionId -Command "cd $apiDir; npm list node-telegram-bot-api 2>&1 | head -3"
        Write-Host $checkDeps.Output
        
        Remove-SSHSession -SessionId $session.SessionId | Out-Null
        
        Write-Host "`n=== Деплой завершен! ===" -ForegroundColor Green
        Write-Host "Бот должен быть запущен. Проверьте его в Telegram!" -ForegroundColor Yellow
        Write-Host "Для просмотра логов: sudo journalctl -u telegram-bot -f" -ForegroundColor Cyan
        
    } else {
        Write-Host "Не удалось подключиться к серверу" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Ошибка: $_" -ForegroundColor Red
    exit 1
}

