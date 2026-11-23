@echo off
setlocal
powershell.exe -NoLogo -NoProfile -File "%~dp0BPCheck-Calistir.ps1" -Language EN %*
set "Result=%ERRORLEVEL%"
echo.
echo Exit code: %Result%
pause
exit /b %Result%
