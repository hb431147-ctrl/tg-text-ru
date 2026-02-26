# Быстрое обновление только бота (без git push). Требуется Posh-SSH.
$hostname = "45.153.70.209"
$username = "root"
$password = "wc.D_-X-1qERXt"
$apiDir = "/var/www/tg-text.ru/api"
$projectRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location | Select-Object -ExpandProperty Path }

if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Install-Module -Name Posh-SSH -Force -Scope CurrentUser -SkipPublisherCheck
}
Import-Module Posh-SSH

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)

Write-Host "Deploying bot update to server..." -ForegroundColor Cyan

$session = New-SSHSession -ComputerName $hostname -Credential $credential -AcceptKey
if (-not $session) {
    Write-Host "Failed to connect" -ForegroundColor Red
    exit 1
}

$botPath = Join-Path $projectRoot "bot.js"
if (-not (Test-Path $botPath)) { Write-Host "Ошибка: bot.js не найден в $projectRoot" -ForegroundColor Red; exit 1 }
$botJsContent = Get-Content $botPath -Raw -Encoding UTF8
$botJsBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($botJsContent))
Invoke-SSHCommand -SessionId $session.SessionId -Command "echo '$botJsBase64' | base64 -d > $apiDir/bot.js" | Out-Null
Write-Host "bot.js copied" -ForegroundColor Green

Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo systemctl restart telegram-bot" | Out-Null
Start-Sleep -Seconds 2
Write-Host "Service restarted" -ForegroundColor Green

$status = Invoke-SSHCommand -SessionId $session.SessionId -Command "sudo systemctl is-active telegram-bot"
Write-Host "Status: $($status.Output)" -ForegroundColor $(if ($status.Output -eq 'active') { 'Green' } else { 'Red' })

Remove-SSHSession -SessionId $session.SessionId | Out-Null
Write-Host "Done." -ForegroundColor Green
