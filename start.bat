@echo off
REM One-click startup for CloakBrowser Manager (Windows double-click friendly)
REM Delegates to start.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] start.ps1 exited with code %ERRORLEVEL%
    pause
)
