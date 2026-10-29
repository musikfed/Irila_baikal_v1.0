#!/usr/bin/env bash
# Post-boot package provisioner; no physical partition operations.
set -Eeuo pipefail
umask 022
STATE=/var/lib/irina-firstboot
LOG=/var/log/irina-firstboot.log
mkdir -p "$STATE" /var/log /run/lock
exec >>"$LOG" 2>&1
exec 9>/run/lock/irina-firstboot.lock
flock -n 9 || exit 0
date -Is
echo 'IRINA firstboot: beginning optional app installation.'
[[ -e "$STATE/complete" ]] && exit 0
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
if ! getent ahostsv4 archive.ubuntu.com >/dev/null; then
  echo 'Network/DNS unavailable. Will retry after network is configured.'
  exit 75
fi
APT_OPTS=(-o DPkg::Lock::Timeout=180 -o APT::Get::Assume-Yes=true)
apt-get "\${APT_OPTS[@]}" update
# Essential boot, firmware, XFCE, NetworkManager and Irina Shell are in IMG.
declare -a PACKAGE_GROUPS=(
  "office|libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-draw libreoffice-l10n-ru"
  "graphics|gimp inkscape"
  "mail|thunderbird"
  "communication|linphone-desktop"
  "utilities|htop nano vim git file-roller p7zip-full"
)
fail=0
for group in "\${PACKAGE_GROUPS[@]}"; do
  name=\${group%%|*}
  packages=\${group#*|}
  [[ -e "$STATE/$name.ok" ]] && continue
  echo "IRINA [$name] installing: $packages"
  if apt-get "\${APT_OPTS[@]}" install --no-install-recommends $packages; then
    touch "$STATE/$name.ok"
    echo "IRINA [$name] complete"
  else
    echo "IRINA [$name] installation failed; retry later."
    fail=1
  fi
done
if ((fail)); then
  echo 'IRINA: some packages missing. Retrying later.'
  exit 75
fi
touch "$STATE/complete"
echo 'IRINA: READY. Optional programs installed.'
date -Is
