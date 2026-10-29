@echo off
setlocal
REM Double-click to launch IRINA GUI. No admin rights or disk writing.
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Irina-USB-Assistant.ps1"
if errorlevel 1 pause
