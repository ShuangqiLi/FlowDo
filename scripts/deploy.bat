@echo off
cd /d "%~dp0.."
REM deploy.ps1 需为 UTF-8 with BOM，否则 Windows PowerShell 5.x 会把中文弄乱码并截断字符串。
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1"
if errorlevel 1 pause
