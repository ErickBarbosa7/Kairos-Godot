@echo off
rem Abre Kairos Arcade y lo vuelve a abrir si se cierra por un fallo.
rem Si el administrador sale a propósito (código 0), no se reabre.
cd /d "%~dp0"
:loop
start "" /wait "KairosArcade.exe"
if %errorlevel%==0 exit /b 0
timeout /t 3 /nobreak >nul
goto loop
