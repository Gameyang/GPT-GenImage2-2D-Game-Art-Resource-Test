@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"

set "START_PORT=8000"
set "END_PORT=8010"
set "PYTHON_CMD="

where py >nul 2>nul
if %ERRORLEVEL% EQU 0 set "PYTHON_CMD=py -3"

if not defined PYTHON_CMD (
  where python >nul 2>nul
  if !ERRORLEVEL! EQU 0 set "PYTHON_CMD=python"
)

if not defined PYTHON_CMD (
  echo Python 3 was not found. Install Python 3, then run this file again.
  echo.
  pause
  exit /b 1
)

for /L %%P in (%START_PORT%,1,%END_PORT%) do (
  %PYTHON_CMD% -c "import socket,sys; p=int(sys.argv[1]); s=socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.settimeout(0.2); code=0 if s.connect_ex(('127.0.0.1', p)) != 0 else 1; s.close(); sys.exit(code)" %%P >nul 2>nul
  if !ERRORLEVEL! EQU 0 (
    set "PORT_TO_USE=%%P"
    goto :found_port
  )
)

echo No free port found from %START_PORT% to %END_PORT%.
echo Close another local server or edit this file to use a different range.
echo.
pause
exit /b 1

:found_port
set "URL=http://localhost:%PORT_TO_USE%"

cls
echo GPT GenImage2 2D Game Art Resource Test
echo Serving: %CD%\public
echo URL: %URL%
echo.
echo Server log will appear below.
echo Press Ctrl-C to stop the server.
echo.

if not "%OPEN_BROWSER%"=="0" start "" "%URL%"
%PYTHON_CMD% -m http.server %PORT_TO_USE% --directory public
set "STATUS=%ERRORLEVEL%"

echo.
echo Server stopped. Exit code: %STATUS%
pause
exit /b %STATUS%
