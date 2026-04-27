@echo off
setlocal

call "%~dp0build.bat" || exit /b 1

echo === Unit + Integration (DUnitX) ===
"%~dp0bin\TaskForge.Tests.exe" -exit:Continue || exit /b 1

echo === E2E (PowerShell) ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\e2e\run_e2e.ps1" -Bin "%~dp0bin" || exit /b 1

echo All tests passed.
exit /b 0
