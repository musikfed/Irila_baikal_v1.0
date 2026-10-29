#!/usr/bin/env bash
# Standalone installed writable Ubuntu on external USB SSD, Secure Boot signed chain.
# ONLY new image FILE on Ubuntu Linux filesystem; NEVER writes any physical SSD.
set -Eeuo pipefail
umask 077
STAGE=""; OUT=""; SIGNED_ASSETS=""; MAX_MIB=8192; MIN_MIB=6144
LOOP=""; MNT=""; TMP=""; READY=0
help(){ echo "Usage: sudo bash scripts/bake_image_installed_secureboot.sh --stage /srv/irina/rootfs --output /srv/irina/irina_baikal_1.0_installed_secureboot.img --signed-assets /srv/irina/signed-assets [--max-image-mib 8192]"; }
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
[[ "$OUT" == *_installed_secureboot.img ]] || die 'Installed image requires unique *_installed_secureboot.img filename (preserve previous IMG)'
[[ ! -e "$OUT" && ! -L "$OUT" ]] || die 'Refusing to overwrite existing image file'
[[ "$SIGNED_ASSETS" == /* && -d "$SIGNED_ASSETS" && ! -L "$SIGNED_ASSETS" ]] || die 'Missing directory of official Ubuntu signed assets'
[[ ! -e "$OUT.FAILED" ]] || die 'Remove FAILED marker manually only after reviewing earlier failure'
[[ "$MAX_MIB" =~ ^[0-9]+$ ]] || die 'Bad --max-image-mib'
((MAX_MIB>=6144 && MAX_MIB<=32768)) || die 'Image size cap must be 6144..32768 MiB'
[[ "$(uname -m)" == x86_64 ]] || die 'Need x86_64 Linux builder'
for c in rsync du parted partprobe partx udevadm losetup mkfs.vfat mkfs.ext4 sbverify sha256sum stat mount umount e2fsck; do
  command -v "$c" >/dev/null || die "Install missing tool: $c"
done
[[ -d "$STAGE/etc" && -d "$STAGE/usr" && -d "$STAGE/opt/irina/ui" ]] || die 'Stage not prepared by prepare_source.sh'
[[ -f "$STAGE/etc/irina-installed-marker" ]] || die 'Use prepare_installed_source.sh, not Live Casper stage'
[[ "$(cat "$STAGE/etc/irina-installed-marker")" == IRINA_INSTALLED_USB_R1 ]] || die 'Wrong installed root marker'
[[ ! -e "$STAGE/usr/share/initramfs-tools/scripts/casper-premount" ]] || die 'Casper must not be in installed OS'
findmnt -R -n "$STAGE" | grep -q . && die 'Stage has mounted filesystems; unmount chroot bind mounts first'
# Reinstate empty Linux mountpoint directories in the isolated stage before
# packing; no host system mountpoints or partitions are touched.
for required_dir in dev proc sys run tmp mnt media; do
  mkdir -p "$STAGE/$required_dir"
done
chmod 1777 "$STAGE/tmp"
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
# Estimate uncompressed Linux ext4 data (root remains writable).
ROOT_MIB="$(du -sm "$STAGE" | awk '{print $1}')"
TOTAL_MIB=$((ROOT_MIB + 2048 + 513))
if ((TOTAL_MIB<MIN_MIB)); then TOTAL_MIB=$MIN_MIB; fi
if ((TOTAL_MIB>MAX_MIB)); then
  die "Uncompressed root needs $ROOT_MIB MiB; cap $MAX_MIB MiB too small"
fi
echo "IRINA INSTALLED: root data $ROOT_MIB MiB; writable GPT IMG $TOTAL_MIB MiB"
truncate -s "$((TOTAL_MIB*1048576))" "$OUT"
[[ -f "$OUT" && ! -b "$OUT" ]] || die 'Output must remain a regular file'
LOOP="$(losetup --find --show --partscan "$OUT")"
[[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] || die 'Loop device not available: requires Linux with loop/partition support'
parted --script "$LOOP" mklabel gpt
parted --script "$LOOP" mkpart IRINA_EFI fat32 1MiB 513MiB
parted --script "$LOOP" set 1 esp on
parted --script "$LOOP" mkpart IRINA_ROOT ext4 513MiB 100%
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
mkfs.ext4 -q -F -m0 -L IRINA_ROOT "$LIVE"
MNT="$TMP/mnt"
mkdir -p "$MNT"
mount "$LIVE" "$MNT"
# Build already prepared the rootfs; copy it into genuine writable ext4.
# --one-file-system avoids copying any host bind mounts even on regression.
rsync -aHAX --numeric-ids --one-file-system "$STAGE/" "$MNT/"
for root_dir in dev proc sys run tmp mnt media; do mkdir -p "$MNT/$root_dir"; done
chmod 1777 "$MNT/tmp"
[[ -s "$MNT/etc/fstab" && -s "$MNT/etc/irina-installed-marker" ]] || die 'Root is missing fstab or marker'
[[ -s "$MNT/usr/local/sbin/irina-auto-provision" ]] || die 'No graphical first-boot provisioning service'
[[ -s "$MNT/usr/local/sbin/irina-grow-usb-root" ]] || die 'No guarded USB root-grower'
echo "IRINA INSTALLED: writable root ext4 copied; preserving Unix UID, permissions, ACL and xattrs."
sync
umount "$MNT"
# Read-only consistency scan before creating the EFI boot partition.
e2fsck -fn "$LIVE"
mount "$EFI" "$MNT"
mkdir -p "$MNT/EFI/BOOT" "$MNT/EFI/ubuntu" "$MNT/boot/grub"
# Signed Ubuntu chain, already demonstrated on this owner's 2021 Acer:
# dual-signed Microsoft shim, Canonical-signed GRUB and Linux kernel.
install -m 0644 "$SHIM" "$MNT/EFI/BOOT/BOOTX64.EFI"
install -m 0644 "$GRUB_SIGNED" "$MNT/EFI/BOOT/grubx64.efi"
install -m 0644 "$MOK" "$MNT/EFI/BOOT/mmx64.efi"
install -m 0644 "$GRUB_SIGNED" "$MNT/EFI/ubuntu/grubx64.efi"
install -m 0644 "$STAGE/boot/vmlinuz-$VER" "$MNT/boot/vmlinuz"
install -m 0644 "$STAGE/boot/initrd.img-$VER" "$MNT/boot/initrd"
cat > "$TMP/grub.cfg" <<'GRUB'
set timeout=5
set default=0
search --no-floppy --label IRINA_EFI --set=efiroot
menuentry "Irina Baikal Installed / Secure Boot / writable SSD" {
  linux ($efiroot)/boot/vmlinuz root=LABEL=IRINA_ROOT rootwait rw quiet
  initrd ($efiroot)/boot/initrd
}
menuentry "Irina Baikal Installed / diagnostic text boot" {
  linux ($efiroot)/boot/vmlinuz root=LABEL=IRINA_ROOT rootwait rw systemd.unit=multi-user.target nomodeset
  initrd ($efiroot)/boot/initrd
}
GRUB
install -m 0644 "$TMP/grub.cfg" "$MNT/EFI/BOOT/grub.cfg"
install -m 0644 "$TMP/grub.cfg" "$MNT/EFI/ubuntu/grub.cfg"
install -m 0644 "$TMP/grub.cfg" "$MNT/boot/grub/grub.cfg"
[[ -s "$MNT/EFI/BOOT/BOOTX64.EFI" && -s "$MNT/EFI/BOOT/grubx64.efi" && -s "$MNT/boot/vmlinuz" && -s "$MNT/boot/initrd" ]] || die 'Missing signed boot chain on EFI'
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
echo 'Installed R1: signed Ubuntu shim/GRUB/kernel + writable ext4 + automatic XFCE software setup; Acer boot still untested.'
echo 'Preserve ALL older IMG files on F:. Flash only to identified external USB SSD after SHA256 validation.'
