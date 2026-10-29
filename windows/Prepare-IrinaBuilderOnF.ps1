# Windows 11 PowerShell 5.1+. Create a SEPARATE Ubuntu WSL2 build copy on F.
# Original Ubuntu is NEVER unregistered or modified by this script.
[CmdletBinding()]
param(
    [string]$SourceDistro = "Ubuntu-24.04",
    [string]$BuildDistro = "IrinaBuilder",
    [string]$Destination = "F:\irinabaikal"
)
$ErrorActionPreference = "Stop"
function Fail([string]$message) { throw "IRINA WSL: $message" }
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { Fail "wsl.exe is missing" }
if (-not ($Destination -match '^[Ff]:\\')) { Fail "Only F:\ paths are allowed for this script" }
$volume = Get-Volume -DriveLetter F -ErrorAction Stop
if ($volume.FileSystem -ne "NTFS") {
    Fail "F: must be NTFS to store WSL ext4.vhdx. Actual filesystem: $($volume.FileSystem)"
}
$disk = Get-Partition -DriveLetter F -ErrorAction Stop | Get-Disk
$sizeGb = [math]::Round($disk.Size / 1GB, 1)
if ($disk.Size -ge 230000000000 -and $disk.Size -le 270000000000) {
    Fail "F: resides on a 256GB disk ($sizeGb GiB), possibly the USB SSD target. Build here is unsafe."
}
if ($volume.SizeRemaining -lt 40GB) {
    Fail "Need at least 40 GiB free on F:. Remaining: $([math]::Round($volume.SizeRemaining/1GB,1)) GiB"
}
$all = @(& wsl.exe --list --quiet) | ForEach-Object { ($_ -replace [char]0, "").Trim() }
if ($LASTEXITCODE -ne 0) { Fail "Could not list WSL distros" }
if ($all -notcontains $SourceDistro) {
    Fail "Source distro '$SourceDistro' not found. Run 'wsl -l -v' and use -SourceDistro for exact name"
}
if ($all -contains $BuildDistro) {
    Fail "Distro '$BuildDistro' already exists; it will NOT be overwritten"
}
& wsl.exe --distribution $SourceDistro -- uname -m
if ($LASTEXITCODE -ne 0) { Fail "Could not start source distro" }
& wsl.exe --distribution $SourceDistro -- sh -c "grep -q '^VERSION_ID=.24.04.' /etc/os-release"
if ($LASTEXITCODE -ne 0) { Fail "Source distro is not confirmed Ubuntu 24.04" }
$install = Join-Path $Destination "WSL-IrinaBuilder"
$archive = Join-Path $Destination "Ubuntu-24.04-export.tar"
if (Test-Path $archive) { Fail "Existing export will not be overwritten: $archive" }
if (Test-Path $install) { Fail "Existing build folder will not be overwritten: $install" }
Write-Host "Source WSL: $SourceDistro. Independent build copy will be on F:" -ForegroundColor Cyan
Write-Host "F: disk: $($disk.FriendlyName), $sizeGb GiB, Bus=$($disk.BusType)"
Write-Host "Original Ubuntu remains untouched. Running WSL sessions will stop during export." -ForegroundColor Yellow
Write-Host "WARNING: This exports ALL files of the source Ubuntu, including projects and any credentials/2FA keys stored in it." -ForegroundColor Yellow
Write-Host "DO NOT upload the export TAR or the resulting WSL VHDX to GitHub; a clean builder distro is preferable when secrets exist." -ForegroundColor Yellow
Write-Host "If WSL is currently unable to start, CANCEL here and follow docs/WSL_RECOVERY.md first." -ForegroundColor Yellow
$consent = Read-Host "Type COPY-IRINA to export/import independent Ubuntu WSL2 distro"
if ($consent -cne "COPY-IRINA") { Fail "Cancelled, no changes made" }
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
& wsl.exe --shutdown
if ($LASTEXITCODE -ne 0) { Fail "WSL shutdown failed" }
Write-Host "Exporting base Ubuntu to $archive" -ForegroundColor Cyan
& wsl.exe --export $SourceDistro $archive
if ($LASTEXITCODE -ne 0) { Fail "WSL export failed; original distro remains unchanged" }
Write-Host "Importing IrinaBuilder ext4.vhdx under $install" -ForegroundColor Cyan
& wsl.exe --import $BuildDistro $install $archive --version 2
if ($LASTEXITCODE -ne 0) { Fail "Import failed; original Ubuntu unaffected. Review partial files." }
& wsl.exe --distribution $BuildDistro -- uname -m
if ($LASTEXITCODE -ne 0) { Fail "Imported WSL failed to start" }
Write-Host "IrinaBuilder on F: ready; original Ubuntu-24.04 retained." -ForegroundColor Green
Write-Host "Launch: wsl -d $BuildDistro -u root"
Write-Host "Only after verifying import, archive may be deleted manually: $archive"
