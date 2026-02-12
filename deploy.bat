@echo off
REM Батник-обертка для запуска deploy.ps1 с обходом политики выполнения
powershell -ExecutionPolicy Bypass -File "%~dp0deploy.ps1"
pause

