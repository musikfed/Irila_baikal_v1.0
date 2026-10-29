#!/usr/bin/env bash
# Irina Baikal 1.0 — optional desktop package profile for Ubuntu 24.04 LTS.
# DRY RUN by default. Never run inside Windows or on the user's host without reviewing.
set -euo pipefail
usage() {
  echo "Usage: $0 [--core|--full] [--dry-run|--install]"
  echo "No packages are installed unless --install is given."
}
MODE=core
ACTION=dry-run
for arg in "$@"; do
  case "$arg" in
    --core) MODE=core ;;
    --full) MODE=full ;;
    --install) ACTION=install ;;
    --dry-run) ACTION=dry-run ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 2 ;;
  esac
done
if [[ "$(uname -s)" != Linux ]] || ! command -v apt-get >/dev/null 2>&1; then
  echo "This script requires Ubuntu/Debian with apt-get." >&2
  exit 1
fi
# Base: bilingual locale, XFCE keyboard toggle, common office apps, mail.
BASE=(language-pack-ru language-pack-en locales x11-xkb-utils xfce4-xkb-plugin
  libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-draw
  libreoffice-l10n-ru libreoffice-help-ru thunderbird mpg123)
# Full: entire LibreOffice suite, bitmap/vector tools, SIP phone and light mini games.
FULL=(libreoffice-base libreoffice-math libreoffice-gnome
  gimp inkscape linphone-desktop aisleriot gnome-mines gnome-mahjongg)
PKGS=("${BASE[@]}")
if [[ "$MODE" == full ]]; then PKGS+=("${FULL[@]}"); fi
echo "Package profile: $MODE, action: $ACTION"
printf '  %s\n' "${PKGS[@]}"
if [[ "$ACTION" == dry-run ]]; then
  echo "DRY RUN — nothing installed. Add --install after reviewing this list."
  exit 0
fi
if [[ "${EUID}" -eq 0 ]]; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS[@]}"
else
  sudo apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS[@]}"
fi
echo "Installed. In a graphical X11 session, configure RU/EN layouts (docs/LOCALIZATION_AND_APPS.md)."
