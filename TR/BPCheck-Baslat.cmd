@echo off
setlocal
powershell.exe -NoLogo -NoProfile -File "%~dp0BPCheck-Calistir.ps1" -Language TR %*
set "Result=%ERRORLEVEL%"
echo.
echo Cikis kodu: %Result%
pause
exit /b %Result%
