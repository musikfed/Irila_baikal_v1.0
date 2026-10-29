#!/usr/bin/env bash
# Configure current X11 session only. Wayland users must use compositor settings.
set -euo pipefail
if [[ "${XDG_SESSION_TYPE:-}" != x11 ]]; then
  echo "This script needs a real X11 session (XFCE/Xorg). Wayland: configure keyboard in your compositor." >&2
  exit 1
fi
if ! command -v setxkbmap >/dev/null 2>&1; then
  echo "Missing setxkbmap (install x11-xkb-utils)." >&2
  exit 1
fi
setxkbmap -layout 'us,ru' -option 'grp:alt_shift_toggle'
echo "US / Russian XKB layouts enabled. Toggle: Alt+Shift."
