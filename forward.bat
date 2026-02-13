@echo off
REM Батник-обертка для запуска forward.ps1 с обходом политики выполнения
powershell -ExecutionPolicy Bypass -File "%~dp0forward.ps1"
pause

