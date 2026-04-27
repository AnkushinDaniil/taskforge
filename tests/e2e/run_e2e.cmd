@echo off
setlocal
set BIN=%1
if "%BIN%"=="" set BIN=%~dp0..\..\bin
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_e2e.ps1" -Bin "%BIN%"
exit /b %ERRORLEVEL%
