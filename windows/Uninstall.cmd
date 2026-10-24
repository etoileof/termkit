@echo off
rem Double-click to uninstall termkit. Your ~/.kimi-code settings and sessions stay.
setlocal
if not exist "%~dp0setup.ps1" goto notextracted
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Uninstall %*
set "CK_EXIT=%ERRORLEVEL%"
echo.
pause
exit /b %CK_EXIT%

:notextracted
echo This has to run from the extracted folder, not from inside the zip.
echo You can also uninstall from Settings, Apps, Installed apps, "termkit".
echo.
pause
exit /b 1
