@echo off
setlocal
echo === bcrypt dynamic local-load probe ===
bcrypt-dynamic.exe
set DYNAMIC_RC=%ERRORLEVEL%
echo ExitCode=%DYNAMIC_RC%
echo.
echo === bcrypt normal link-time consumer ===
bcrypt-linked.exe
set LINKED_RC=%ERRORLEVEL%
echo ExitCode=%LINKED_RC%
echo.
if not "%DYNAMIC_RC%"=="0" exit /b %DYNAMIC_RC%
if not "%LINKED_RC%"=="0" exit /b %LINKED_RC%
echo ALL PASS
exit /b 0
