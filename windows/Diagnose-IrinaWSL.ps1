# WSL2 troubleshooting for Acer Irina Baikal build — READ-ONLY diagnostics.
# No shutdown/import/export/unregister/install/dd/diskpart or disk writes.
[CmdletBinding()]
param(
  [string]$Distro = "Ubuntu-24.04",
  [switch]$CheckStart
)
$ErrorActionPreference = "Continue"
Write-Host "Irina Baikal - WSL diagnostics (read-only)" -ForegroundColor Cyan
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  Write-Host "wsl.exe not found in PATH" -ForegroundColor Red
  exit 1
}
foreach ($options in @(
  @("--list", "--verbose"),
  @("--status"),
  @("--version")
)) {
  Write-Host ""
  Write-Host ("> wsl " + ($options -join " ")) -ForegroundColor Yellow
  & wsl.exe @options
  Write-Host "Exit code: $LASTEXITCODE"
}
Write-Host ""
Write-Host "Inspecting build folder presence without reading personal files" -ForegroundColor Yellow
$root = "F:\irinabaikal"
Write-Host "F:\irinabaikal exists:" (Test-Path -LiteralPath $root -PathType Container)
Write-Host "IrinaBuilder folder exists:" (Test-Path -LiteralPath "$root\WSL-IrinaBuilder" -PathType Container)
Write-Host "Ubuntu WSL export TAR exists:" (Test-Path -LiteralPath "$root\Ubuntu-24.04-export.tar" -PathType Leaf)
$vol = Get-Volume -DriveLetter F -ErrorAction SilentlyContinue
if ($vol) {
  Write-Host "F: filesystem:" $vol.FileSystem
  Write-Host "F: free GiB:" ([math]::Round($vol.SizeRemaining / 1GB, 1))
}
if ($CheckStart) {
  Write-Host ""
  Write-Host "Testing distro startup without modifying any files" -ForegroundColor Yellow
  Write-Host ("wsl --distribution " + $Distro + " --user root --exec /bin/true")
  & wsl.exe --distribution $Distro --user root --exec /bin/true
  Write-Host "Exit code: $LASTEXITCODE"
}
Write-Host "Nothing was stopped, formatted, exported, or deleted." -ForegroundColor Green
