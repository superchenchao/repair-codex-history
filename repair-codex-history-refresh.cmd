@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%repair-codex-history.ps1"

if not exist "%PS_SCRIPT%" (
    echo [ERROR] Missing script: "%PS_SCRIPT%"
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -RestartBackend %*
set "EXITCODE=%ERRORLEVEL%"

echo.
if "%EXITCODE%"=="0" (
    echo Done.
    echo The Codex window may briefly show an error page while the backend reconnects.
) else (
    echo Failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
