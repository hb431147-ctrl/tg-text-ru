# Скрипт для настройки SSH ключа на сервере
$SERVER = "root@45.153.70.209"
$PASSWORD = "wc.D_-X-1qERXt"
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa_tg_text"

Write-Host "=== Настройка SSH подключения ===" -ForegroundColor Green

# Читаем публичный ключ
if (-not (Test-Path "$SSH_KEY.pub")) {
    Write-Host "ОШИБКА: Публичный ключ не найден!" -ForegroundColor Red
    exit 1
}

$pubKey = Get-Content "$SSH_KEY.pub" -Raw
$pubKey = $pubKey.Trim()

Write-Host "Добавление ключа на сервер..." -ForegroundColor Yellow

# Используем plink или sshpass для передачи пароля
# Создаем временный скрипт для добавления ключа
$script = @"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '$pubKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "SSH ключ успешно добавлен"
"@

# Сохраняем скрипт во временный файл
$tempScript = "$env:TEMP\setup_ssh_key.sh"
$script | Out-File -FilePath $tempScript -Encoding UTF8 -NoNewline

# Копируем скрипт на сервер и выполняем
Write-Host "Копирование скрипта на сервер..." -ForegroundColor Cyan

# Используем expect-подобный подход через PowerShell
$expectScript = @"
spawn scp -o StrictHostKeyChecking=no "$tempScript" $SERVER:/tmp/setup_ssh_key.sh
expect "password:"
send "$PASSWORD\r"
expect eof
"@

# Альтернативный способ - используем ssh с паролем через plink или напрямую
Write-Host "Выполнение настройки на сервере..." -ForegroundColor Cyan

# Используем sshpass если доступен, иначе используем другой метод
$sshCommand = "ssh -o StrictHostKeyChecking=no $SERVER 'bash -s' < $tempScript"

# Для Windows используем plink или создаем PowerShell функцию
function Invoke-SSHWithPassword {
    param($Server, $Password, $Command)
    
    # Создаем временный файл с командой
    $cmdFile = "$env:TEMP\ssh_cmd.txt"
    $Command | Out-File -FilePath $cmdFile -Encoding UTF8 -NoNewline
    
    # Используем plink если доступен
    if (Get-Command plink -ErrorAction SilentlyContinue) {
        $cmd = "plink -ssh -pw `"$Password`" $Server `"$Command`""
        Invoke-Expression $cmd
    } else {
        Write-Host "Используйте plink или установите его для автоматической настройки" -ForegroundColor Yellow
        Write-Host "Или выполните вручную:" -ForegroundColor Yellow
        Write-Host "ssh $Server" -ForegroundColor White
        Write-Host "mkdir -p ~/.ssh && chmod 700 ~/.ssh" -ForegroundColor White
        Write-Host "echo '$pubKey' >> ~/.ssh/authorized_keys" -ForegroundColor White
        Write-Host "chmod 600 ~/.ssh/authorized_keys" -ForegroundColor White
    }
}

# Пробуем добавить ключ
Invoke-SSHWithPassword -Server $SERVER -Password $PASSWORD -Command "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'SSH ключ добавлен'"

Write-Host "Проверка подключения..." -ForegroundColor Cyan
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SERVER "echo 'SSH подключение работает!'"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ SSH настроен успешно!" -ForegroundColor Green
} else {
    Write-Host "⚠ SSH ключ может быть не настроен автоматически" -ForegroundColor Yellow
    Write-Host "Выполните вручную:" -ForegroundColor Yellow
    Write-Host "ssh $SERVER" -ForegroundColor White
    Write-Host "mkdir -p ~/.ssh && chmod 700 ~/.ssh" -ForegroundColor White
    Write-Host "echo '$pubKey' >> ~/.ssh/authorized_keys" -ForegroundColor White
    Write-Host "chmod 600 ~/.ssh/authorized_keys" -ForegroundColor White
}

