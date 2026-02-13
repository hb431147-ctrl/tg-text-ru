@echo off
REM Батник-обертка для запуска rollback.ps1 с обходом политики выполнения
powershell -ExecutionPolicy Bypass -File "%~dp0rollback.ps1"
pause

