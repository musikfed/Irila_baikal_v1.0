#!/usr/bin/env bash
# Run on boot INSIDE Irina installed OS. Expand only the mounted IRINA_ROOT
# partition on its OWN external USB device. Never address another block disk.
set -Eeuo pipefail
exec >>/var/log/irina-grow-root.log 2>&1
echo "IRINA grow-root: $(date -u +%FT%TZ)"
[[ -f /etc/irina-installed-marker ]] || { echo "No marker; skip"; exit 0; }
[[ "$(cat /etc/irina-installed-marker)" == "IRINA_INSTALLED_USB_R1" ]] || exit 0
ROOT="$(findmnt -n -o SOURCE / | head -1)"
ROOT="$(readlink -f "$ROOT")"
[[ "$ROOT" == /dev/* && -b "$ROOT" ]] || { echo "Root not a block device; skip"; exit 0; }
[[ "$(blkid -s LABEL -o value "$ROOT")" == IRINA_ROOT ]] || { echo "Wrong root label; skip"; exit 0; }
[[ "$(lsblk -n -o PARTN "$ROOT" | head -1 | xargs)" == 2 ]] || { echo "Root must be partition 2; skip"; exit 0; }
PARENT="$(lsblk -n -o PKNAME "$ROOT" | head -1 | xargs)"
[[ "$PARENT" =~ ^(sd[a-z]+|nvme[0-9]+n[0-9]+)$ ]] || { echo "Unexpected parent; skip"; exit 0; }
DISK="/dev/$PARENT"
[[ -b "$DISK" ]] || exit 0
[[ "$(lsblk -dn -o TRAN "$DISK" | xargs)" == usb ]] || { echo "Not an external USB disk; NEVER resize"; exit 0; }
[[ "$(lsblk -dn -o PTTYPE "$DISK" | xargs)" == gpt ]] || { echo "Not a GPT disk; skip"; exit 0; }
BYTES="$(blockdev --getsize64 "$DISK")"
# Explicitly limit automated resizing to the owner's 256 GB external SSD
# (~238.47 GiB). Do not attempt auto-resize on internal disks or arbitrary USBs.
(( BYTES >= 230000000000 && BYTES <= 275000000000 )) || { echo "Unexpected USB capacity $BYTES; skip"; exit 0; }
if [[ -f /var/lib/irina/root-expanded ]]; then
  echo "Already expanded"; exit 0
fi
echo "Verified external USB root $ROOT on $DISK ($BYTES bytes)."
echo "Relocate secondary GPT header to physical end (image is smaller than USB)."
sgdisk -e "$DISK"
echo "Grow only partition 2 of verified root disk."
growpart "$DISK" 2
echo "Online ext4 resize of mounted IRINA_ROOT."
resize2fs "$ROOT"
mkdir -p /var/lib/irina
touch /var/lib/irina/root-expanded
df -h /
echo "IRINA grow-root: successful"
