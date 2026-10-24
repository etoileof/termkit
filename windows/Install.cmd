@echo off
rem Double-click to install or update termkit for this Windows user.
setlocal
if not exist "%~dp0setup.ps1" goto notextracted
if not exist "%~dp0kimi.exe" goto notextracted
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
set "CK_EXIT=%ERRORLEVEL%"
echo.
pause
exit /b %CK_EXIT%

:notextracted
echo This has to run from the extracted folder, not from inside the zip.
echo Right-click the downloaded zip, choose "Extract All...", open the extracted
echo folder and double-click "Install.cmd" there.
echo.
pause
exit /b 1
