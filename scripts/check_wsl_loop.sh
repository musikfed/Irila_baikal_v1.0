#!/usr/bin/env bash
# Read-only WSL/GPT build capability check except for a temporary 96 MiB regular file.
# No device under /dev/sd*, /dev/nvme* or physical Windows SSD is ever opened.
set -Eeuo pipefail
LOOP=""
TMP=""
cleanup() {
  code=$?
  trap - EXIT
  if [[ -n "$LOOP" ]]; then losetup -d "$LOOP" 2>/dev/null || true; fi
  if [[ -n "$TMP" ]]; then rm -rf -- "$TMP"; fi
  exit "$code"
}
trap cleanup EXIT
die() { echo "IRINA PREFLIGHT ERROR: $*" >&2; exit 1; }
((EUID==0)) || die "Use sudo or WSL root"
[[ "$(uname -m)" == x86_64 ]] || die "Need x86_64"
for cmd in truncate losetup parted partprobe lsblk; do
  command -v "$cmd" >/dev/null || die "Missing $cmd (install util-linux and parted)"
done
TMP="$(mktemp -d /var/tmp/irina-loop-check.XXXXXXXX)"
truncate -s 96M "$TMP/test.img"
echo "Only a temporary 96 MiB FILE will be used: $TMP/test.img"
LOOP="$(losetup --find --show --partscan "$TMP/test.img")" || die "WSL kernel has no available loop device; use GitHub Actions builder or Ubuntu Live USB"
[[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] || die "Expected /dev/loopN, got unexpected path"
parted --script "$LOOP" mklabel gpt
parted --script "$LOOP" mkpart TEST ext4 1MiB 90MiB
partprobe "$LOOP"
if command -v partx >/dev/null; then partx --update "$LOOP" 2>/dev/null || true; fi
if [[ ! -b "$LOOP"p1 ]]; then
  lsblk "$LOOP" || true
  die "WSL cannot expose GPT partitions on loop image. Build IMG with GitHub Actions/Ubuntu Live; DO NOT mount physical Windows SSD"
fi
echo "PASS: Linux loop device and GPT partition support available"
echo "This test did not access the internal Windows SSD or the external USB target."
