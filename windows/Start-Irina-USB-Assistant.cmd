@echo off
setlocal
REM IRINA GUI bootstrap v3; no administrative rights or disk operations.
REM Double-click: update ONLY the small .ps1 from owner's GitHub, validate and run.
REM Run --self-test to check decoding without network or opening the GUI.
set "IRINA_GUI=%~dp0Irina-USB-Assistant.ps1"
set "IRINA_RAW=https://raw.githubusercontent.com/musikfed/Irila_baikal_v1.0/main/windows/Irina-USB-Assistant.ps1"
if /I "%~1"=="--self-test" goto selftest
echo IRINA: checking latest GUI script on GitHub (never touches IMG or SSD) ...
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $p=$env:IRINA_GUI; try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $wc=New-Object Net.WebClient; $wc.Encoding=[Text.Encoding]::UTF8; $source=$wc.DownloadString($env:IRINA_RAW); $wc.Dispose(); if ($source.Length -lt 2000 -or !$source.Contains('IRINA USB GUI')) { throw 'Unexpected downloaded GUI script' }; $tokens=$null; $errors=$null; [Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors) | Out-Null; if ($errors.Count -ne 0) { throw 'Downloaded PowerShell code failed syntax validation' }; [IO.File]::WriteAllText($p,$source,(New-Object Text.UTF8Encoding($true))); Write-Host 'IRINA: PowerShell GUI updated in UTF-8 BOM.' } catch { Write-Warning ('Could not refresh GUI: '+$_.Exception.Message); Write-Host 'IRINA: trying locally saved script.' }; if (!(Test-Path -LiteralPath $p -PathType Leaf)) { throw 'No local GUI. Connect to GitHub and restart.' }; $localSource=[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8); $script=[ScriptBlock]::Create($localSource); & $script"
if errorlevel 1 (
  echo IRINA: GUI could not be started. Copy the RED ERROR and show it to ChatGPT.
  pause
  exit /b 1
)
exit /b 0
:selftest
if not exist "%IRINA_GUI%" (
  echo No PS1 beside CMD.
  exit /b 1
)
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $source=[IO.File]::ReadAllText($env:IRINA_GUI,[Text.Encoding]::UTF8); $script=[ScriptBlock]::Create($source); & $script -SelfTest"
exit /b %errorlevel%
