@echo off
setlocal
REM IRINA Windows GUI launcher. No administrative rights or disk formatting.
REM Windows PowerShell 5.1 may misparse a UTF-8 script without BOM.
REM Always decode explicitly as UTF-8 in memory, including old downloaded .ps1.
set "IRINA_GUI=%~dp0Irina-USB-Assistant.ps1"
if not exist "%IRINA_GUI%" (
  echo Missing Irina-USB-Assistant.ps1. Put both files in the same directory.
  pause
  exit /b 1
)
set "IRINA_TEST_MODE="
if /I "%~1"=="--self-test" set "IRINA_TEST_MODE=-SelfTest"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $p=$env:IRINA_GUI; $source=[System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8); & ([System.Management.Automation.ScriptBlock]::Create($source)) %IRINA_TEST_MODE%"
if errorlevel 1 (
  echo IRINA GUI failed to start. See error message above.
  pause
)
