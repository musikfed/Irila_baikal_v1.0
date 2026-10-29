# One-command WSL2 IMG build from Windows 11. No physical SSD writes.
[CmdletBinding()]
param(
  [ValidateSet("core","full")][string]$Profile="core",
  [ValidateSet(5120,8192)][int]$MaxImageMiB=5120,
  [ValidatePattern("^[A-Za-z0-9_.-]+$")][string]$Distro="IrinaBuilder",
  [switch]$CheckOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
Write-Host "IRINA WSL BUILDER v2.3 (file-based Bash runner, 2026-10-29)" -ForegroundColor Cyan
function Fail([string]$message) { throw "IRINA WSL: $message" }

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { Fail "WSL2 is not installed" }
$folder = "F:\irinabaikal"
$vol=Get-Volume -DriveLetter F
if ($null -eq $vol -or $vol.FileSystem -ne "NTFS") { Fail "F: must be NTFS" }
$disk=Get-Partition -DriveLetter F | Get-Disk
if ($null -eq $disk) { Fail "Cannot identify physical disk hosting F:" }
if ([double]$disk.Size -ge 230GB -and [double]$disk.Size -le 270GB) {
  Fail "F: may be the 256GB USB SSD target. Refusing to place build data there."
}
if ($vol.SizeRemaining -lt 20GB) { Fail "At least 20 GiB free on F: is required" }
if (-not (Test-Path -LiteralPath $folder -PathType Container)) { Fail "Create F:\irinabaikal first" }
$img=Join-Path $folder "irina_baikal_1.0.img"
$checksum="$img.sha256"
if ((Test-Path -LiteralPath $img) -or (Test-Path -LiteralPath $checksum)) {
  Fail "IMG or checksum already exists, will not overwrite. Move the earlier build first."
}
$distros=@(& wsl.exe --list --quiet | ForEach-Object { ($_ -replace [char]0,"").Trim() })
if ($LASTEXITCODE -ne 0 -or $distros -notcontains $Distro) {
  Fail "WSL distro '$Distro' missing. Run wsl -l -v. For all files on F: first run Prepare-IrinaBuilderOnF.ps1"
}
# Windows PowerShell 5.1 -> wsl.exe -> bash -lc can strip Bash quotes and corrupt
# multi-line conditionals. Instead write a short, LF-only, UTF-8 (no BOM) script
# in the dedicated F: project folder and pass only its path to /bin/bash.
# Temporary scripts contain no secrets and are always removed.
function Invoke-IrinaWSLScript([string]$ScriptText, [string]$Phase) {
  $name = ".irina-wsl-$([Guid]::NewGuid().ToString('N')).sh"
  $winFile = Join-Path $folder $name
  $linuxFile = "/mnt/f/irinabaikal/$name"
  try {
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $textLF = ($ScriptText -replace "`r`n", "`n") + "`n"
    [System.IO.File]::WriteAllText($winFile, $textLF, $utf8)
    Write-Host "IRINA WSL: $Phase" -ForegroundColor Cyan
    # Forward Linux stdout to the terminal instead of returning its text from this
    # PowerShell function. Otherwise a WSL error line can become part of
    # $preflightStatus, corrupting the numeric exit code (and error message).
    & wsl.exe --distribution $Distro --user root --exec /bin/bash $linuxFile | Out-Host
    $exitCode = [int]$LASTEXITCODE
    return $exitCode
  }
  finally {
    if (Test-Path -LiteralPath $winFile) {
      Remove-Item -LiteralPath $winFile -Force
    }
  }
}
$preflight=@'
set -Eeuo pipefail
. /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 24.04 ]] || { echo "Need Ubuntu 24.04" >&2; exit 2; }
grep -qi microsoft /proc/sys/kernel/osrelease || { echo "Need WSL2" >&2; exit 2; }
[[ "$(findmnt -n -o FSTYPE -T /srv)" == ext4 ]] || { echo "/srv is not ext4: cannot prepare Linux rootfs on drvfs" >&2; exit 2; }
[[ -d /mnt/f/irinabaikal ]] || { echo "Windows F: folder unavailable in WSL" >&2; exit 2; }
echo "PASS: Ubuntu 24.04 + WSL2 + Linux ext4 staging + F: output"
'@
$preflightStatus = Invoke-IrinaWSLScript -ScriptText $preflight -Phase "Checking Ubuntu 24.04, WSL2 and F: mount"
if ($preflightStatus -ne 0) {
  Fail "WSL preflight failed (exit code $preflightStatus); no build started. If you saw MountDisk/HCS/E_ACCESSDENIED for ext4.vhdx, first check Windows access/ownership of the WSL virtual disk (see docs/WSL_RECOVERY.md). Never unregister the distro."
}
if ($CheckOnly) {
  Write-Host "CHECK-ONLY PASS. No packages were installed and no IMG was created." -ForegroundColor Green
  Write-Host "NOTE: This does NOT verify loop/GPT capability, installed packages, full image build or Acer boot." -ForegroundColor Yellow
  return
}
Write-Host "Distro: $Distro; profile: $Profile; max IMG: $MaxImageMiB MiB" -ForegroundColor Cyan
Write-Host "F: disk: $($disk.FriendlyName); Windows and physical SSDs will NOT be partitioned" -ForegroundColor Yellow
$answer=Read-Host "Type BUILD-IRINA to install Linux build packages and create the IMG file"
if ($answer -cne "BUILD-IRINA") { Write-Host "Cancelled"; return }
$commands=@'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git debootstrap ubuntu-keyring rsync squashfs-tools parted gdisk dosfstools e2fsprogs util-linux udev mount grub-efi-amd64-bin grub-common python3
cd /root
if [[ ! -e Irila_baikal_v1.0 ]]; then
  git clone https://github.com/musikfed/Irila_baikal_v1.0.git
elif [[ -d Irila_baikal_v1.0/.git ]]; then
  git -C Irila_baikal_v1.0 pull --ff-only
else
  echo "Irila_baikal_v1.0 exists but is not a Git repo; refusing overwrite" >&2; exit 3
fi
cd Irila_baikal_v1.0
bash scripts/build_in_wsl.sh --__PROFILE__ --max-image-mib __MAX__
'@
$commands=$commands.Replace("__PROFILE__",$Profile).Replace("__MAX__",[string]$MaxImageMiB)
$buildStatus = Invoke-IrinaWSLScript -ScriptText $commands -Phase "Building IMG inside Linux WSL2 ext4"
if ($buildStatus -ne 0) { Fail "Build failed (code $buildStatus): do not flash SSD. Review WSL logs." }
if (-not (Test-Path -LiteralPath $img -PathType Leaf) -or -not (Test-Path -LiteralPath $checksum -PathType Leaf)) {
  Fail "IMG and SHA256 not found on F: despite successful build command"
}
Write-Host "READY: $img" -ForegroundColor Green
Write-Host "HASH:  $checksum" -ForegroundColor Green
Write-Host ("Check with: py -3.13 F:\irinabaikal\flash_irina.py --image " + $img)
Write-Host "Physical SSD was not modified. Rufus and Acer F12 boot testing are separate steps."
