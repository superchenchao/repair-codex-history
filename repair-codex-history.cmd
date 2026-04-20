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

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
set "EXITCODE=%ERRORLEVEL%"

echo.
if "%EXITCODE%"=="0" (
    echo Done.
    echo If the sidebar does not refresh immediately, reopen Codex once.
) else (
    echo Failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
