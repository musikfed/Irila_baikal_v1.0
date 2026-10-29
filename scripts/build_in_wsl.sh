#!/usr/bin/env bash
# Build Irina Baikal read-only IMG entirely inside WSL2 ext4, then copy verified result to F:.
# Run from the GitHub repository checkout in IrinaBuilder (WSL2 Ubuntu 24.04).
set -Eeuo pipefail
PROFILE=core
MAX_MIB=5120
DEST=/mnt/f/irinabaikal
while (($#)); do
  case "$1" in
    --core) PROFILE=core; shift;;
    --full) PROFILE=full; shift;;
    --max-image-mib) MAX_MIB="$2"; shift 2;;
    --dest) DEST="$2"; shift 2;;
    --help|-h)
      echo "Usage: sudo bash scripts/build_in_wsl.sh [--core|--full] [--max-image-mib 5120|8192] [--dest /mnt/f/irinabaikal]"
      echo "Builds isolated Ubuntu stage in /srv/irina (WSL ext4) and copies verified IMG to Windows F:."
      exit 0;;
    *) echo "Unknown parameter $1" >&2; exit 2;;
  esac
done
((EUID==0)) || { echo "Run as root (sudo) INSIDE WSL Ubuntu" >&2; exit 1; }
[[ -f /proc/sys/kernel/osrelease ]] || { echo "Linux required" >&2; exit 1; }
grep -qi microsoft /proc/sys/kernel/osrelease || {
  echo "This helper is for WSL2. For Ubuntu Live use prepare_source.sh + bake_image.sh directly" >&2
  exit 1
}
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 24.04 ]] || { echo "Need Ubuntu 24.04 WSL distro" >&2; exit 1; }
[[ "$DEST" == /mnt/f/* ]] || { echo "Destination must be on Windows F: under /mnt/f/" >&2; exit 1; }
[[ -d "$DEST" ]] || { echo "Windows destination does not exist: $DEST" >&2; exit 1; }
[[ "$MAX_MIB" =~ ^[0-9]+$ ]] || { echo "Invalid max size" >&2; exit 2; }
((MAX_MIB>=3072 && MAX_MIB<=32768)) || { echo "Max MiB outside 3072..32768" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BUILD=/srv/irina
ROOTFS="$BUILD/rootfs"
IMAGE="$BUILD/irina_baikal_1.0.img"
[[ ! -e "$ROOTFS" && ! -e "$IMAGE" ]] || {
  echo "Existing build files detected at $BUILD. No automatic overwrite or cleanup; inspect first." >&2
  exit 1
}
[[ ! -e "$DEST/irina_baikal_1.0.img" ]] || {
  echo "Refusing to overwrite F: IMG. Move previous IMG manually." >&2; exit 1
}
[[ ! -e "$DEST/irina_baikal_1.0.img.sha256" ]] || {
  echo "Refusing to overwrite existing F: SHA256" >&2; exit 1
}
mkdir -p "$BUILD"
echo "Preflight: Linux GPT loop image support..."
bash "$HERE/scripts/check_wsl_loop.sh"
echo "Building isolated rootfs ($PROFILE) on WSL ext4; Windows files not used as chroot..."
bash "$HERE/scripts/prepare_source.sh" --stage "$ROOTFS" "--$PROFILE"
echo "Baking GPT + EFI + SquashFS image, maximum $MAX_MIB MiB..."
bash "$HERE/scripts/bake_image.sh" --stage "$ROOTFS" --output "$IMAGE" --max-image-mib "$MAX_MIB"
(
  cd "$BUILD"
  sha256sum -c irina_baikal_1.0.img.sha256
)
echo "Copying to Windows F: $DEST"
cp --no-clobber -- "$IMAGE" "$DEST/irina_baikal_1.0.img"
cp --no-clobber -- "$IMAGE.sha256" "$DEST/irina_baikal_1.0.img.sha256"
(
  cd "$DEST"
  sha256sum -c irina_baikal_1.0.img.sha256
)
echo "READY ON WINDOWS: F:\irinabaikal\irina_baikal_1.0.img"
echo "The physical 256GB USB SSD has NOT been formatted or written to."
echo "Next: py -3.13 scripts\flash_irina.py --image F:\irinabaikal\irina_baikal_1.0.img"
echo "Then manually choose only the correct external SSD in Rufus. First Acer boot is still untested."
