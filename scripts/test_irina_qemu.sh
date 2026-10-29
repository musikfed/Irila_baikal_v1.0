#!/usr/bin/env bash
# Non-destructive OVMF UEFI smoke test: base raw IMG remains unchanged.
set -Eeuo pipefail
(($#==1)) || { echo "Usage: bash scripts/test_irina_qemu.sh /path/to/image.img" >&2; exit 2; }
IMG="$1"
[[ -f "$IMG" ]] || { echo "Image missing: $IMG" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "Install qemu-system-x86" >&2; exit 1; }
CODE=""; VARS=""
for pair in \
  "/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd" \
  "/usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd"; do
  IFS=: read -r c v <<< "$pair"
  if [[ -f "$c" && -f "$v" ]]; then CODE="$c"; VARS="$v"; break; fi
done
[[ -n "$CODE" ]] || { echo "Missing OVMF: sudo apt install ovmf" >&2; exit 1; }
TEMP="$(mktemp -d /tmp/irina-qemu.XXXXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
cp "$VARS" "$TEMP/OVMF_VARS.fd"
ACCEL=tcg
if [[ -r /dev/kvm && -w /dev/kvm ]]; then ACCEL=kvm; fi
echo "UEFI QEMU ($ACCEL). Image test uses snapshot mode: source IMG unchanged."
echo "Expected GRUB -> XFCE -> Irina Shell. Check interactively."
qemu-system-x86_64 -machine "q35,accel=$ACCEL" -m 4096 -smp 2 \
  -drive "if=pflash,format=raw,readonly=on,file=$CODE" \
  -drive "if=pflash,format=raw,file=$TEMP/OVMF_VARS.fd" \
  -drive "file=$IMG,format=raw,if=virtio,snapshot=on" \
  -nic user,model=e1000 -name "Irina Baikal UEFI boot smoke test"
