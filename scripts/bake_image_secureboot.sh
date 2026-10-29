#!/usr/bin/env bash
# Build separate Secure Boot candidate with signed Ubuntu shim -> GRUB -> kernel.
# ONLY new image FILE on Ubuntu Linux filesystem; NEVER writes any physical SSD.
set -Eeuo pipefail
umask 077
STAGE=""; OUT=""; SIGNED_ASSETS=""; MAX_MIB=5120; MIN_MIB=3072
LOOP=""; MNT=""; TMP=""; READY=0
help(){ echo "Usage: sudo bash scripts/bake_image_secureboot.sh --stage /srv/irina/rootfs --output /srv/irina/irina_baikal_1.0_secureboot.img --signed-assets /srv/irina/signed-assets [--max-image-mib 5120]"; }
die(){ echo "IRINA BAKE ERROR: $*" >&2; exit 1; }
cleanup(){
  code=$?
  trap - EXIT
  if [[ -n "$MNT" ]] && mountpoint -q "$MNT"; then umount "$MNT" || true; fi
  if [[ -n "$LOOP" ]]; then losetup -d "$LOOP" || true; fi
  [[ -z "$TMP" ]] || rm -rf -- "$TMP"
  if [[ "$READY" == 0 && -n "$OUT" && -f "$OUT" ]]; then
    touch "$OUT.FAILED" || true
    echo "INCOMPLETE IMAGE; DO NOT FLASH: $OUT" >&2
  fi
  exit "$code"
}
trap cleanup EXIT
while (($#)); do
  case "$1" in
    --stage) STAGE="$2"; shift 2;;
    --output) OUT="$2"; shift 2;;
    --signed-assets) SIGNED_ASSETS="$2"; shift 2;;
    --max-image-mib) MAX_MIB="$2"; shift 2;;
    -h|--help) help; exit 0;;
    *) die "Unknown parameter $1";;
  esac
done
((EUID==0)) || die 'Run as root inside Ubuntu 24.04 Linux (WSL2 with loop support or Live USB)'
[[ "$STAGE" == /* && -d "$STAGE" ]] || die 'Missing staged rootfs'
[[ ! -L "$STAGE" ]] || die 'Stage symlink not allowed'
[[ "$OUT" == /* && "$OUT" == *.img && "$OUT" != /dev/* && "$OUT" != /mnt/* ]] || die 'Absolute .img output required on Linux filesystem'
[[ "$OUT" == *_secureboot.img ]] || die 'Secure Boot output must have distinct *_secureboot.img name (preserve original IMG)'
[[ ! -e "$OUT" && ! -L "$OUT" ]] || die 'Refusing to overwrite existing image file'
[[ "$SIGNED_ASSETS" == /* && -d "$SIGNED_ASSETS" && ! -L "$SIGNED_ASSETS" ]] || die 'Missing directory of official Ubuntu signed assets'
[[ ! -e "$OUT.FAILED" ]] || die 'Remove FAILED marker manually only after reviewing earlier failure'
[[ "$MAX_MIB" =~ ^[0-9]+$ ]] || die 'Bad --max-image-mib'
((MAX_MIB>=3072 && MAX_MIB<=32768)) || die 'Image size cap must be 3072..32768 MiB'
[[ "$(uname -m)" == x86_64 ]] || die 'Need x86_64 Linux builder'
for c in mksquashfs parted partprobe partx udevadm losetup mkfs.vfat mkfs.ext4 sbverify sha256sum stat mount umount; do
  command -v "$c" >/dev/null || die "Install missing tool: $c"
done
[[ -d "$STAGE/etc" && -d "$STAGE/usr" && -d "$STAGE/opt/irina/ui" ]] || die 'Stage not prepared by prepare_source.sh'
[[ ! -d "$STAGE/casper" ]] || die 'Rootfs stage unexpectedly has casper source dir'
findmnt -R -n "$STAGE" | grep -q . && die 'Stage has mounted filesystems; unmount chroot bind mounts first'
VER="$(find "$STAGE/boot" -maxdepth 1 -name 'vmlinuz-*' -printf '%f\n' | sed 's/vmlinuz-//' | sort -V | tail -1)"
[[ -n "$VER" && -s "$STAGE/boot/vmlinuz-$VER" && -s "$STAGE/boot/initrd.img-$VER" ]] || die 'Linux kernel/casper initrd missing'
SHIM="$SIGNED_ASSETS/usr/lib/shim/shimx64.efi.dualsigned"
GRUB_SIGNED="$SIGNED_ASSETS/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed"
MOK="$SIGNED_ASSETS/usr/lib/shim/mmx64.efi"
for binary in "$SHIM" "$GRUB_SIGNED" "$MOK" "$STAGE/boot/vmlinuz-$VER"; do
  [[ -s "$binary" ]] || die "Missing Canonical/Microsoft signed boot binary: $binary"
  # Reject unsigned custom EFI binaries: sbverify --list must show a signature.
  sbverify --list "$binary" | grep -Eq 'signature [0-9]+' || die "No UEFI signature found in $binary"
done
# The Acer's 2021 UEFI may only trust Microsoft's 2011 UEFI CA.
# Require both generations of Microsoft signatures on the fallback shim,
# preventing us from shipping a 2023-only binary to older firmware.
sbverify --list "$SHIM" | grep -Eq 'signature 2' || die 'Ubuntu dualsigned shim does not expose two EFI signatures'
echo "IRINA SECURE BOOT: Ubuntu shim, GRUB, MokManager and kernel carry EFI signatures; firmware trust must still be tested."
mkdir -p "$(dirname "$OUT")"
TMP="$(mktemp -d /var/tmp/irina-bake.XXXXXXXX)"
echo "IRINA: packing rootfs into SquashFS (zstd, level 17) ..."
mksquashfs "$STAGE" "$TMP/filesystem.squashfs" -noappend -comp zstd -Xcompression-level 17 \
  -one-file-system -e dev proc sys run tmp mnt media
SQUASH_BYTES="$(stat -c %s "$TMP/filesystem.squashfs")"
KERNEL_BYTES="$(stat -c %s "$STAGE/boot/vmlinuz-$VER")"
INITRD_BYTES="$(stat -c %s "$STAGE/boot/initrd.img-$VER")"
# 512 MiB ESP, payload with >=320 MiB spare for ext4 and boot files, GPT overhead.
PAYLOAD_MIB=$(( (SQUASH_BYTES+KERNEL_BYTES+INITRD_BYTES+1048575)/1048576 + 320 ))
TOTAL_MIB=$((513 + PAYLOAD_MIB + 2))
if ((TOTAL_MIB<MIN_MIB)); then TOTAL_MIB=$MIN_MIB; fi
if ((TOTAL_MIB>MAX_MIB)); then
  echo "SquashFS $((SQUASH_BYTES/1048576)) MiB: needed image $TOTAL_MIB MiB; limit $MAX_MIB MiB" >&2
  die "Too large for budget. Use --core or explicitly --max-image-mib 8192; Qwen 8B alone exceeds 5 GiB"
fi
echo "IRINA: SquashFS $((SQUASH_BYTES/1048576)) MiB, image $TOTAL_MIB MiB"
truncate -s "$((TOTAL_MIB*1048576))" "$OUT"
[[ -f "$OUT" && ! -b "$OUT" ]] || die 'Output must remain a regular file'
LOOP="$(losetup --find --show --partscan "$OUT")"
[[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] || die 'Loop device not available: requires Linux with loop/partition support'
parted --script "$LOOP" mklabel gpt
parted --script "$LOOP" mkpart IRINA_EFI fat32 1MiB 513MiB
parted --script "$LOOP" set 1 esp on
parted --script "$LOOP" mkpart IRINA_LIVE ext4 513MiB 100%
partprobe "$LOOP"
udevadm settle
EFI="$LOOP"p1
LIVE="$LOOP"p2
# GPT was created AFTER losetup --partscan. Some WSL2 kernels need a
# second partition table update before /dev/loopNp1 and p2 are exposed.
if [[ ! -b "$EFI" || ! -b "$LIVE" ]]; then
  partx --update "$LOOP" || true
  udevadm settle
fi
[[ -b "$EFI" && -b "$LIVE" ]] || die 'Loop partitions missing; WSL2 environment may lack loop partition support'
mkfs.vfat -F32 -n IRINA_EFI "$EFI"
mkfs.ext4 -q -F -m0 -L IRINA_LIVE "$LIVE"
MNT="$TMP/mnt"
mkdir -p "$MNT"
mount "$LIVE" "$MNT"
mkdir -p "$MNT/casper"
cp "$TMP/filesystem.squashfs" "$MNT/casper/filesystem.squashfs"
cp "$STAGE/boot/vmlinuz-$VER" "$MNT/casper/vmlinuz"
cp "$STAGE/boot/initrd.img-$VER" "$MNT/casper/initrd"
sync
umount "$MNT"
mount "$EFI" "$MNT"
mkdir -p "$MNT/EFI/BOOT" "$MNT/EFI/ubuntu" "$MNT/boot/grub" "$MNT/casper"
# Microsoft-signed Ubuntu shim is the *fallback removable media* EFI entry.
# Shim loads the Canonical-signed grubx64.efi from the SAME folder.
install -m 0644 "$SHIM" "$MNT/EFI/BOOT/BOOTX64.EFI"
install -m 0644 "$GRUB_SIGNED" "$MNT/EFI/BOOT/grubx64.efi"
install -m 0644 "$MOK" "$MNT/EFI/BOOT/mmx64.efi"
# Also cover Ubuntu GRUB's usual prefix when scanning the ESP.
install -m 0644 "$GRUB_SIGNED" "$MNT/EFI/ubuntu/grubx64.efi"
# The signed GRUB can load a signed vmlinuz from the ESP's FAT filesystem;
# that avoids relying on unsigned external GRUB modules for ext4 at boot.
install -m 0644 "$STAGE/boot/vmlinuz-$VER" "$MNT/casper/vmlinuz"
install -m 0644 "$STAGE/boot/initrd.img-$VER" "$MNT/casper/initrd"
cat > "$TMP/grub.cfg" <<'GRUB'
set timeout=5
set default=0
search --no-floppy --label IRINA_EFI --set=efiroot
menuentry "Irina Baikal 1.0 - Secure Boot / RAM Overlay" {
  linux ($efiroot)/casper/vmlinuz boot=casper nopersistent username=irina hostname=irina-baikal ro quiet
  initrd ($efiroot)/casper/initrd
}
menuentry "Irina Baikal 1.0 - Secure Boot diagnostics" {
  linux ($efiroot)/casper/vmlinuz boot=casper nopersistent username=irina hostname=irina-baikal ro
  initrd ($efiroot)/casper/initrd
}
GRUB
# Signed Ubuntu GRUB implementations may look at several standard paths,
# so place the identical config in each without rewriting signed binaries.
install -m 0644 "$TMP/grub.cfg" "$MNT/EFI/BOOT/grub.cfg"
install -m 0644 "$TMP/grub.cfg" "$MNT/EFI/ubuntu/grub.cfg"
install -m 0644 "$TMP/grub.cfg" "$MNT/boot/grub/grub.cfg"
[[ -s "$MNT/EFI/BOOT/BOOTX64.EFI" && -s "$MNT/EFI/BOOT/grubx64.efi" && -s "$MNT/casper/vmlinuz" ]] || die 'Missing signed boot chain on EFI'
df -h "$MNT"
sync
umount "$MNT"
losetup -d "$LOOP"; LOOP=""
# CRITICAL: hash manifest MUST use only basename. An absolute /srv/... path
# would make "sha256sum -c" on F: silently check the original WSL image
# rather than the COPIED file and could conceal a corrupt transfer.
(
  cd "$(dirname "$OUT")"
  sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256"
  sha256sum -c "$(basename "$OUT").sha256"
)
# Let the ordinary Windows/WSL user copy the completed build artifacts.
chmod 644 "$OUT" "$OUT.sha256"
READY=1
echo "READY: $OUT"
echo "SHA256: $OUT.sha256"
echo 'Experimental Secure Boot candidate: Ubuntu signed shim + GRUB + kernel; no Acer firmware/SBAT/DBX validation yet.'
echo 'Do not overwrite original IMG on F:. Flash only to identified external USB SSD after checksum validation.'
